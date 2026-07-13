# Simple File Migrator

A user-friendly bash script to find and move files from a source folder to a destination, designed to be interactive, safe, and configurable.

## Features

*   **Interactive & Safe**: Lists all matching files it finds and asks for your confirmation before moving anything. You always have the final say.
*   **Flexible Configuration**: Easily set source/destination paths, file types, and automation settings in a standard `.env` file.
*   **Dry Run Mode**: A `DryRun` setting in the `.env` file allows you to run a simulation to see which files would be moved without making any actual changes.
*   **Live Log Output**: Displays a clean, color-coded log of its actions in the terminal, including `[INFO]`, `[SUCCESS]`, `[WARN]`, and `[ERROR]` prefixes.
*   **Detailed Progress Bar**: Shows a detailed, real-time progress bar during file transfers when running interactively.
*   **Optional File Logging**: At startup, it prompts you to save a detailed, timestamped log file (e.g., `file_migrator_log_20260711-160000.log`) of the entire operation. The log file is cleanly formatted without any color codes.
*   **Automation-Friendly**: A `SkipPrompts` option in the `.env` file allows the script to run non-interactively, making it perfect for scheduled tasks.
*   **Automatic Folder Creation**: If the destination folder doesn't exist, the script will offer to create it for you, preventing errors.
*   **Smart Error Handling**:
    *   Provides detailed error messages if a file fails to move (e.g., "Permission denied").
    *   Checks if source and destination folders exist, and offers to create the destination if it's missing.
*   **Helpful Suggestions**: If no files are found, it intelligently checks for other common audio formats (like M4A, FLAC, etc.) and guides you on how to update the `.env` file to include them.
*   **User-Friendly Terminal**: In interactive mode, it automatically resizes the terminal window for a consistent experience and waits for a key press before exiting.

## Getting Started

Follow these three steps to get the script running.

### 1. Configure the Script
First, create a configuration file by copying the example:
```bash
cp .env.example .env
```
Next, open the `.env` file and edit the variables to match your setup.

| Variable            | Description                                                                                             | Default Value                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `SourceFolder`      | The folder where your audio files are currently located.                                                | `"$HOME/Music/"`                                              |
| `DestinationFolder` | The folder where you want to move the files.                                                            | `"$HOME/Music/Apple Music/Media/Automatically Add to Apple Music"` |
| `FileTypesToMove`   | A space-separated list of file extensions to move (e.g., "mp3 m4a flac").                               | `"mp3"`                                                       |
| `SkipPrompts`       | Set to `true` to run without interactive prompts. Ideal for automation.                                 | `false`                                                       |
| `LogOnSkipPrompts`  | Set to `true` to automatically create a log file when `SkipPrompts` is also `true`.                       | `false`                                                       |
| `DryRun`            | Set to `true` to simulate the move and see what would happen without changing any files. **Recommended for first use.** | `false`                                                       |

### 2. Make the Script Executable
You only need to do this once. This command gives your system permission to run the file as a script.
```bash
chmod +x migrate.files.sh
```

### 3. Run the Script
Execute the script from your terminal.
```bash
./migrate.files.sh
```
The script will guide you the rest of the way!

> **Tip:** For your first run, it's a great idea to set `DryRun=true` in your `.env` file. This lets you safely preview all the actions the script will take.

## License

This project is licensed under the MIT License. See the LICENSE file for details.