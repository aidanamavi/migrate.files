#!/bin/bash

# ==============================================================================
# Simple File Migrator
#
# A bash script to find and move audio files from a source to a destination folder.
# It is designed to be interactive, safe, and configurable via a `.env` file.
# ==============================================================================

# --- 1. SCRIPT SETUP & CONFIGURATION ---
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "\e[1;33m[WARN] Configuration file '.env' not found.\e[0m"
    echo -e "\e[0;36mPlease create a '.env' file by copying '.env.example' and customizing it.\e[0m"
    exit 1
fi

# Load configuration from .env file.
# 'set -a' exports all variables defined in the sourced file to the environment,
# making them accessible to sub-processes. 'set +a' disables this behavior.
set -a
source "$ENV_FILE"
set +a

# --- 2. GLOBAL VARIABLES & UI SETUP ---

# LOG_FILE will be set to a file path if logging is enabled by the user or config.
LOG_FILE=""

# IS_TERMINAL is true if the script is running in an interactive terminal.
# This is used to determine if we can safely prompt the user or resize the window.
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

# --- 3. LOGGING & UI HELPER FUNCTIONS ---

# log_message(message)
# Prints a message to the console and, if logging is enabled, writes a
# clean, timestamped version of it to the log file.
# @param {string} message - The message to log, which may include color codes.
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

# draw_progress_bar(current, total, filename)
# Renders a progress bar in the terminal during interactive file moves.
# It overwrites the current line to show real-time progress.
# @param {number} current_file_num - The number of the file currently being processed.
# @param {number} total_files - The total number of files to move.
# @param {string} file_name - The name of the file being moved.
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

# --- 4. MAIN EXECUTION ---

# Determine whether to enable logging based on configuration and user input.
# In automated mode (SkipPrompts=true), logging can be forced with LogOnSkipPrompts.
# In interactive mode, the user is prompted.
if [ "$SkipPrompts" == "true" ] && [ "$LogOnSkipPrompts" == "true" ]; then
    # Automation mode with logging enabled: no prompts, create log file.
    LOG_FILE="$SCRIPT_DIR/file_migrator_log_$(date +%Y%m%d-%H%M%S).log"
    INTERACTIVE=false
elif $IS_TERMINAL && [ "$SkipPrompts" != "true" ]; then
    # Interactive mode: ask the user if they want to log.
    printf '\e[8;30;100t' # Resize terminal
    read -p "Do you want to save a log of this session? (y/n) " save_log_response
    if [[ "$save_log_response" =~ ^[Yy]$ ]]; then
        LOG_FILE="$SCRIPT_DIR/file_migrator_log_$(date +%Y%m%d-%H%M%S).log"
        INTERACTIVE=false
    fi
    echo
fi

# --- Initial Setup and Validation ---
log_message "${CYAN}Starting Simple File Migrator...${NC}"
if [ -n "$LOG_FILE" ]; then
    log_message "[INFO] Logging this session to: '$LOG_FILE'"
fi
log_message "[INFO] Source folder:      '$SourceFolder'"
log_message "[INFO] Destination folder: '$DestinationFolder'"
echo "" # Add a blank line for readability

# Validate that the source folder exists.
if [ ! -d "$SourceFolder" ]; then
    log_message "${RED}[ERROR] Source folder not found. Please check the path.${NC}"
    exit 1
fi

# Validate that the destination folder exists. If not, offer to create it.
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

# If DryRun is enabled, print a prominent warning.
if [ "$DryRun" == "true" ]; then
    log_message "${YELLOW}[WARN] DRY RUN MODE IS ENABLED. No files will be moved.${NC}"
    echo ""
fi

log_message "[INFO] Searching for files with extensions: $FileTypesToMove..."
# --- File Discovery ---
# Build find command arguments for specified file types
find_args=()
for ext in $FileTypesToMove; do
    if [ ${#find_args[@]} -gt 0 ]; then
        find_args+=(-o)
    fi
    find_args+=(-iname "*.$ext")
done

# Adjust find command for recursive or non-recursive search based on .env config.
find_command_base=(find "$SourceFolder")
if [ "$RecursiveSearch" != "true" ]; then
    log_message "[INFO] Recursive search is disabled. Searching top-level directory only."
    find_command_base+=(-maxdepth 1)
else
    log_message "[INFO] Recursive search is enabled. Searching all subdirectories."
fi

# Execute the find command and store the results in an array.
# -print0 and readarray -d '' are used to handle filenames with spaces or special characters.
readarray -d '' filesToMove < <( "${find_command_base[@]}" -type f \( "${find_args[@]}" \) -print0)

# --- File Processing ---
if [ ${#filesToMove[@]} -gt 0 ]; then
    # Files were found, so proceed with the move operation.
    failedMoves=0
    fileCount=${#filesToMove[@]} # This is a count of files found
    log_message "${GREEN}[INFO] Found $fileCount file(s) to move:${NC}"
    for file in "${filesToMove[@]}"; do
        echo -e "  - $(basename "$file")"
    done
    echo "" # Add a blank line for readability

    # Confirm with the user before moving files (unless in automation mode).
    confirm="n"
    if [ "$SkipPrompts" != "true" ]; then
        read -p "Do you want to move these files? (y/n) " confirm
    else
        confirm="y" # Automatically agree to move files in non-interactive mode
    fi
    echo

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_message "[INFO] Starting file move operation..."

        if [ "$DryRun" == "true" ]; then
            # In dry run, check if we can write to the destination folder.
            if ! [ -w "$DestinationFolder" ]; then
                log_message "${RED}[DRY RUN] [ERROR] Destination folder '$DestinationFolder' is not writable. Please check permissions.${NC}"
                exit 1
            fi
        fi

        # Loop through each file and move it.
        processed_count=0
        for file in "${filesToMove[@]}"; do
            ((processed_count++))
            fileName=$(basename "$file")

            if [ "$DryRun" == "true" ]; then
                log_message "[DRY RUN] Would move '$fileName' to '$DestinationFolder'"
            else
                if $INTERACTIVE; then
                    draw_progress_bar $processed_count $fileCount "$fileName"
                fi
                
                # Execute the move command and capture any error output.
                error_message=$(mv "$file" "$DestinationFolder" 2>&1)
                if [ $? -ne 0 ]; then
                    # On failure, log the error
                    if $INTERACTIVE; then echo ""; fi # Move off the progress bar line
                    log_message "${RED}[ERROR] Failed to move '$fileName'. Reason: $error_message${NC}"
                    ((failedMoves++))
                elif [ -z "$LOG_FILE" ]; then
                    # If not logging to a file, don't print success for every single file to keep the console clean.
                    : # Don't log success for every file unless we are writing to a log
                else
                    log_message "[INFO] Moved ($processed_count/$fileCount): $fileName"
                fi
            fi
        done
        if $INTERACTIVE; then echo ""; fi # Final newline after progress bar
        echo "" # Blank line for separation

        # --- Final Summary ---
        log_message "[INFO] Migration process complete."
        if [ "$DryRun" == "true" ]; then
            log_message "${GREEN}[DRY RUN] Successfully simulated moving $fileCount file(s).${NC}"
        elif [ $failedMoves -eq 0 ]; then
            log_message "${GREEN}[SUCCESS] All $fileCount file(s) have been successfully moved.${NC}"
        else
            successMoves=$((fileCount - failedMoves))
            log_message "${YELLOW}$successMoves of $fileCount files were moved successfully.${NC}"
            log_message "${RED}$failedMoves file(s) failed to move. Please check for errors above.${NC}"
        fi
    else
        log_message "${YELLOW}Operation cancelled by the user. No files were moved.${NC}"
    fi
else
    # No files matching the criteria were found.
    log_message "${YELLOW}[INFO] No files with the specified extensions were found.${NC}"

    # --- Smart Suggestion Feature ---
    # Check for other common audio files to provide a better hint.
    if [ "$SkipPrompts" != "true" ]; then
        echo "" # Formatting
        log_message "[INFO] Checking for other audio file types you might want to move..."
        # Find other common audio file extensions present in the source folder.
        # The result is a unique, sorted, lowercase list of extensions.
        other_audio_types=()
        while IFS= read -r line; do
            other_audio_types+=("$line")
        done < <( "${find_command_base[@]}" -type f \( -iname "*.m4a" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.aac" \) -printf "%f\n" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]' | sort -u )

        if [ ${#other_audio_types[@]} -gt 0 ]; then
            log_message "${CYAN}I found files with these extensions: ${other_audio_types[*]}.${NC}"
            read -p "Would you like to search again using these file types? (y/n) " response
            # If the user agrees, re-run the script with the new file types.
            if [[ "$response" =~ ^[Yy]$ ]]; then
                export FileTypesToMove="${other_audio_types[*]}" # Temporarily override for this run
                log_message "${GREEN}Great! Restarting the search for the new file types...${NC}"
                echo ""
                # Re-execute the script with the new context
                # 'exec' replaces the current shell process with the new one.
                exec bash "$0" "$@"
            fi
        fi
    fi
fi

echo ""
# In interactive mode, wait for a key press before exiting to allow the user to read the output.
if $IS_TERMINAL && [ "$SkipPrompts" != "true" ]; then
    read -n 1 -s -r -p "Press any key to exit..."
    echo
fi
