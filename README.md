# MP3 File Migrator

A user-friendly bash script to find and move MP3 files from a source folder to a destination, designed to be interactive and safe.

## Features

*   **Interactive & Safe**: Lists all MP3 files it finds and asks for your confirmation before moving anything. You always have the final say.
*   **Flexible Configuration**: Easily configure source/destination paths, file types to move, and automation settings in a standard `.env` file.
*   **Live Log Output**: Displays a clean, color-coded log of its actions in the terminal, including `[INFO]`, `[SUCCESS]`, `[WARN]`, and `[ERROR]` prefixes.
*   **Detailed Progress Bar**: Shows a detailed, real-time progress bar during file transfers when running interactively.
*   **Optional File Logging**: At startup, it prompts you to save a detailed, timestamped log file (e.g., `mp3_move_log_20260711-160000.log`) of the entire operation. The log file is cleanly formatted without any color codes.
*   **Automation-Friendly**: A `SkipPrompts` option in the `.env` file allows the script to run non-interactively, making it perfect for scheduled tasks.
*   **Smart Error Handling**:
    *   Provides detailed error messages if a file fails to move (e.g., "Permission denied").
    *   Checks if source and destination folders exist, and offers to create the destination if it's missing.
*   **Helpful Suggestions**: If no MP3s are found, it intelligently checks for other common audio formats (like M4A, FLAC, etc.) and guides you on how to modify the script to include them.
*   **User-Friendly Terminal**: Automatically resizes the terminal window for a consistent experience and waits for a key press before exiting in interactive mode.

## How to Use

1.  **Prerequisites**: You need a bash-compatible terminal on your system. On Windows, Git Bash is a great option.

2.  **Configure Paths**:
    *   Copy the `.env.example` file to a new file named `.env`.
    *   Open the `.env` file in a text editor.
    *   Modify the variables like `SourceFolder`, `FileTypesToMove`, and `SkipPrompts` to match your needs.

3.  **Run the Script**:
    *   Navigate to the directory containing the script in your terminal.
    *   Make the script executable (you only need to do this once):
        ```bash
        chmod +x move_mp3s.sh
        ```
    *   Run the script:
        ```bash
        ./move_mp3s.sh
        ```

4.  **Follow the Prompts**: The script will guide you through the process of logging, confirming file moves, and exiting.

## License

This project is licensed under the MIT License. See the LICENSE file for details.