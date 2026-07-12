#!/bin/bash

# --- Script Setup ---
# --- Configuration ---
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "\e[1;33m[WARN] Configuration file '.env' not found.\e[0m"
    echo -e "\e[0;36mPlease create a '.env' file by copying '.env.example' and customizing it.\e[0m"
    exit 1
fi

# Load configuration
# Use 'set -a' to export all variables as environment variables
set -a
source "$ENV_FILE"
set +a

LOG_FILE="" # Will be set if logging is enabled
# --- Color Codes ---
# IS_TERMINAL is true if the script is running in an interactive terminal.
# It determines if we can prompt the user or resize the window.
IS_TERMINAL=false
if [ -t 1 ]; then
    IS_TERMINAL=true
fi

INTERACTIVE=$IS_TERMINAL # Controls UI elements like progress bars. Can be disabled for logging.
if $INTERACTIVE; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    DARK_GRAY='\033[1;30m'
    NC='\033[0m' # No Color
else
    CYAN=""
    GREEN=""
    YELLOW=""
    RED=""
    DARK_GRAY=""
    NC=""
fi

# --- Logging and UI Functions ---
log_message() {
    local message="$1"
    if [ -n "$LOG_FILE" ]; then
        # Remove ANSI color codes for the log file
        local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
        local timestamped_message="[$(date '+%Y-%m-%d %H:%M:%S')] $clean_message"
        # Append clean message to log file
        echo "$timestamped_message" >> "$LOG_FILE"
    fi
    # Echo styled message to the console
    echo -e "$message"
}

draw_progress_bar() { # Only called when interactive
    local current_file_num=$1
    local total_files=$2
    local file_name=$3
    local bar_width=40

    # Calculate percentage
    local percentage=$((current_file_num * 100 / total_files))

    # Calculate number of filled and empty characters for the bar
    local filled_chars=$((percentage * bar_width / 100))
    local empty_chars=$((bar_width - filled_chars))

    # Build the bar string
    local filled_bar=""
    for ((i=0; i<filled_chars; i++)); do
        filled_bar+="="
    done

    local empty_bar=""
    for ((i=0; i<empty_chars; i++)); do
        empty_bar+=" "
    done

    # Use a carriage return `\r` to stay on the same line.
    # The trailing spaces clear the rest of the line in case the new line is shorter.
    printf "\r[INFO] Progress: [%s%s] %3d%% (%d/%d) | Moving: %s      " "$filled_bar" "$empty_bar" "$percentage" "$current_file_num" "$total_files" "$file_name"
}

# --- Main Execution ---
if [ "$SkipPrompts" == "true" ] && [ "$LogOnSkipPrompts" == "true" ]; then
    # Automation mode with logging enabled: no prompts, create log file.
    LOG_FILE="$SCRIPT_DIR/mp3_move_log_$(date +%Y%m%d-%H%M%S).log"
    INTERACTIVE=false
elif $IS_TERMINAL && [ "$SkipPrompts" != "true" ]; then
    # Interactive mode: ask the user if they want to log.
    printf '\e[8;30;100t' # Resize terminal
    read -p "Do you want to save a log of this session? (y/n) " save_log_response
    if [[ "$save_log_response" =~ ^[Yy]$ ]]; then
        LOG_FILE="$SCRIPT_DIR/mp3_move_log_$(date +%Y%m%d-%H%M%S).log"
        INTERACTIVE=false
    fi
    echo
fi

log_message "${CYAN}Starting MP3 file migration process...${NC}"
if [ -n "$LOG_FILE" ]; then
    log_message "[INFO] Logging this session to: '$LOG_FILE'"
fi
log_message "[INFO] Source folder:      '$SourceFolder'"
log_message "[INFO] Destination folder: '$DestinationFolder'"
echo "" # Add a blank line for readability

# Check if the source folder exists
if [ ! -d "$SourceFolder" ]; then
    log_message "${RED}[ERROR] Source folder not found. Please check the path.${NC}"
    exit 1
fi

# Check if the destination folder exists and prompt to create it if not
if [ ! -d "$DestinationFolder" ]; then
    log_message "${YELLOW}[WARN] Destination folder not found.${NC}"
    response="n"
    if [ "$SkipPrompts" != "true" ]; then
        read -p "Would you like to create it now? (y/n) " response
    else
        response="y" # Automatically agree to create the folder in non-interactive mode
    fi
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_message "[INFO] Creating destination folder..."
        if mkdir -p "$DestinationFolder"; then
            log_message "${GREEN}[SUCCESS] Folder created successfully.${NC}"
        else
            log_message "${RED}[ERROR] Could not create destination folder. Please check permissions.${NC}"
            exit 1
        fi
    else
        log_message "${RED}Operation cancelled by the user. Exiting.${NC}"
        exit 1
    fi
fi

log_message "[INFO] Searching for files with extensions: $FileTypesToMove..."
# Build find command arguments for specified file types
find_args=()
for ext in $FileTypesToMove; do
    if [ ${#find_args[@]} -gt 0 ]; then
        find_args+=(-o)
    fi
    find_args+=(-iname "*.$ext")
done

# Find all specified files in the source directory (non-recursively)
readarray -d '' filesToMove < <(find "$SourceFolder" -maxdepth 1 -type f \( "${find_args[@]}" \) -print0)

if [ ${#filesToMove[@]} -gt 0 ]; then
    failedMoves=0
    fileCount=${#filesToMove[@]}
    log_message "${GREEN}[INFO] Found $fileCount file(s) to move:${NC}"
    for file in "${filesToMove[@]}"; do
        echo -e "  - $(basename "$file")"
    done
    echo "" # Add a blank line for readability

    confirm="n"
    if [ "$SkipPrompts" != "true" ]; then
        read -p "Do you want to move these files? (y/n) " confirm
    else
        confirm="y" # Automatically agree to move files in non-interactive mode
    fi
    echo
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_message "[INFO] Starting file move operation..."
        processed_count=0
        for file in "${filesToMove[@]}"; do
            ((processed_count++))
            fileName=$(basename "$file")
            if $INTERACTIVE; then
                draw_progress_bar $processed_count $fileCount "$fileName"
            fi
            
            # Capture error message from mv
            error_message=$(mv "$file" "$DestinationFolder" 2>&1)
            if [ $? -ne 0 ]; then
                # On failure, log the error
                if $INTERACTIVE; then echo ""; fi # Move off the progress bar line
                log_message "${RED}[ERROR] Failed to move '$fileName'. Reason: $error_message${NC}"
                ((failedMoves++))
            elif [ -z "$LOG_FILE" ]; then
                : # Don't log success for every file unless we are writing to a log
            else
                log_message "[INFO] Moved ($processed_count/$fileCount): $fileName"
            fi
        done
        if $INTERACTIVE; then echo ""; fi # Final newline after progress bar
        echo "" # Blank line for separation
        log_message "[INFO] Migration process complete."
        if [ $failedMoves -eq 0 ]; then
            log_message "${GREEN}[SUCCESS] All $fileCount MP3 file(s) have been successfully moved.${NC}"
        else
            successMoves=$((fileCount - failedMoves))
            log_message "${YELLOW}$successMoves of $fileCount files were moved successfully.${NC}"
            log_message "${RED}$failedMoves file(s) failed to move. Please check for errors above.${NC}"
        fi
    else
        log_message "${YELLOW}Operation cancelled by the user. No files were moved.${NC}"
    fi
else
    # If no MP3s are found, check for other common audio files to provide a better hint.
    otherAudioFiles=$(find "$SourceFolder" -maxdepth 1 -type f \( -iname "*.m4a" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.aac" \))
    
    log_message "${YELLOW}[INFO] No files with the specified extensions were found.${NC}"
    
    if [ -n "$otherAudioFiles" ]; then
        log_message "${CYAN}However, I did find other audio file types (like M4A, FLAC, WAV, etc.).${NC}"
        log_message "${CYAN}You can change the 'FileTypesToMove' variable in your .env file to include them.${NC}"
        read -p "Would you like to modify the script to include other file types? (y/n) " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_message "${GREEN}Great! You can edit the script to look for other extensions. For example, to find both .mp3 and .m4a files, you could change the 'find' command.${NC}"
        else
            log_message "${YELLOW}No action taken. The script will now exit.${NC}"
        fi
    fi
fi

echo ""
if $IS_TERMINAL && [ "$SkipPrompts" != "true" ]; then
    read -n 1 -s -r -p "Press any key to exit..."
    echo
fi
