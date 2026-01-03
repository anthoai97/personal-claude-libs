#!/usr/bin/env bash

# Claude Hooks Setup Script
#
# This script installs Claude Code hooks into a target project.

set -euo pipefail

# Script directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
TARGET_DIR=""
INSTALL_NOTIFICATIONS="n"
OS=""
AUDIO_PLAYER=""
OVERWRITE_ALL="n"
SKIP_ALL="n"

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print header
print_header() {
    echo
    print_color "$BLUE" "==========================================="
    print_color "$BLUE" "       Claude Hooks Setup"
    print_color "$BLUE" "==========================================="
    echo
}

# Safe read function that works in piped contexts
safe_read() {
    local var_name="$1"
    local prompt="$2"
    local temp_input

    if [ ! -t 0 ] && [ ! -c /dev/tty ]; then
        print_color "$RED" "❌ Cannot prompt for input: No TTY available."
        return 1
    fi

    local input_source
    if [ -t 0 ]; then
        input_source="/dev/stdin"
    else
        input_source="/dev/tty"
    fi

    read -r -p "$prompt" temp_input < "$input_source"
    printf -v "$var_name" '%s' "$temp_input"
}

# Safe read function for yes/no questions with validation
safe_read_yn() {
    local var_name="$1"
    local prompt="$2"
    local user_input
    local sanitized_input
    local valid_input=false

    while [ "$valid_input" = false ]; do
        if ! safe_read user_input "$prompt"; then
            return 1
        fi

        sanitized_input="${user_input//$'\r'/}"
        sanitized_input="$(echo "$sanitized_input" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

        case "$sanitized_input" in
            y|n)
                valid_input=true
                printf -v "$var_name" '%s' "$sanitized_input"
                ;;
            *)
                print_color "$YELLOW" "Please enter 'y' for yes or 'n' for no."
                ;;
        esac
    done
}

# Safe read function for file conflict choices with validation
safe_read_conflict() {
    local var_name="$1"
    local user_input
    local sanitized_input
    local valid_input=false

    while [ "$valid_input" = false ]; do
        if ! safe_read user_input "   Your choice: "; then
            return 1
        fi

        sanitized_input="${user_input//$'\r'/}"
        sanitized_input="$(echo "$sanitized_input" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

        case "$sanitized_input" in
            o|s|a|n)
                valid_input=true
                printf -v "$var_name" '%s' "$sanitized_input"
                ;;
            *)
                print_color "$YELLOW" "   Invalid choice. Please enter o, s, a, or n."
                ;;
        esac
    done
}

# Check if Claude Code is installed
check_claude_code() {
    print_color "$YELLOW" "Checking prerequisites..."

    if ! command -v claude &> /dev/null; then
        print_color "$RED" "❌ Claude Code is not installed or not in PATH"
        echo "Please install Claude Code from: https://github.com/anthropics/claude-code"
        exit 1
    fi

    print_color "$GREEN" "✓ Claude Code is installed"
}

# Check for required tools
check_required_tools() {
    local missing_tools=()

    for tool in jq mkdir cp chmod python3; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_color "$RED" "❌ Missing required tools: ${missing_tools[*]}"
        echo
        echo "On macOS: brew install ${missing_tools[*]}"
        echo "On Ubuntu/Debian: sudo apt-get install ${missing_tools[*]}"
        exit 1
    fi

    print_color "$GREEN" "✓ All required tools are available"
}

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macOS"
            AUDIO_PLAYER="afplay"
            ;;
        Linux*)
            OS="Linux"
            for player in paplay aplay pw-play play ffplay; do
                if command -v "$player" &> /dev/null; then
                    AUDIO_PLAYER="$player"
                    break
                fi
            done
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="Windows"
            AUDIO_PLAYER="powershell"
            ;;
        *)
            OS="Unknown"
            AUDIO_PLAYER=""
            ;;
    esac

    print_color "$GREEN" "✓ Detected OS: $OS"
}

# Get target directory
get_target_directory() {
    echo
    print_color "$YELLOW" "Where would you like to install the Claude Hooks?"
    local prompt="Enter target project directory (or . for current directory): "
    if ! safe_read input_dir "$prompt"; then
        exit 1
    fi

    if [ "$input_dir" = "." ]; then
        if [ -n "${INSTALLER_ORIGINAL_PWD:-}" ]; then
            TARGET_DIR="$INSTALLER_ORIGINAL_PWD"
        else
            TARGET_DIR="$(pwd)"
        fi
    else
        TARGET_DIR="$(cd "$input_dir" 2>/dev/null && pwd)" || {
            print_color "$RED" "❌ Directory '$input_dir' does not exist"
            exit 1
        }
    fi

    if [ "$TARGET_DIR" = "$SCRIPT_DIR" ]; then
        print_color "$RED" "❌ Cannot install into the source directory"
        exit 1
    fi

    print_color "$GREEN" "✓ Target directory: $TARGET_DIR"
}

# Prompt for optional components
prompt_optional_components() {
    echo
    print_color "$YELLOW" "Available Hooks:"
    echo

    # Notifications
    print_color "$CYAN" "Notification Hook"
    echo "  Plays audio alerts when tasks complete or input is needed"
    if ! safe_read_yn INSTALL_NOTIFICATIONS "  Install notification hook? (y/n): "; then
        exit 1
    fi

    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        detect_os
        if [ -z "$AUDIO_PLAYER" ] && [ "$OS" = "Linux" ]; then
            print_color "$YELLOW" "⚠️  No audio player found. Install one of: paplay, aplay, pw-play, play, ffplay"
        fi
    fi
}

# Create directory structure
create_directories() {
    print_color "$YELLOW" "Creating directory structure..."

    mkdir -p "$TARGET_DIR/.claude/hooks"

    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        mkdir -p "$TARGET_DIR/.claude/hooks/sounds"
    fi

    print_color "$GREEN" "✓ Directory structure created"
}

# Helper function to handle file conflicts
handle_file_conflict() {
    local source_file="$1"
    local dest_file="$2"
    local file_type="$3"

    if [ "$OVERWRITE_ALL" = "y" ]; then
        cp "$source_file" "$dest_file"
        return 0
    elif [ "$SKIP_ALL" = "y" ]; then
        return 1
    fi

    print_color "$YELLOW" "⚠️  File already exists: $(basename "$dest_file")"
    echo "   Type: $file_type"
    echo "   Location: $dest_file"
    echo
    echo "   What would you like to do?"
    echo "   [o] Overwrite - Replace the existing file"
    echo "   [s] Skip - Keep the existing file"
    echo "   [a] Always overwrite - Replace all future existing files"
    echo "   [n] Never overwrite - Skip all future existing files"
    echo
    if ! safe_read_conflict choice; then
        return 1
    fi

    case "$choice" in
        o)
            cp "$source_file" "$dest_file"
            print_color "$GREEN" "   ✓ Overwritten"
            return 0
            ;;
        s)
            print_color "$YELLOW" "   → Skipped"
            return 1
            ;;
        a)
            OVERWRITE_ALL="y"
            cp "$source_file" "$dest_file"
            print_color "$GREEN" "   ✓ Overwritten (will overwrite all future conflicts)"
            return 0
            ;;
        n)
            SKIP_ALL="y"
            print_color "$YELLOW" "   → Skipped (will skip all future conflicts)"
            return 1
            ;;
        *)
            print_color "$RED" "   Invalid choice, skipping file"
            return 1
            ;;
    esac
}

# Copy a file with conflict handling
copy_with_check() {
    local source="$1"
    local dest="$2"
    local file_type="$3"

    if [ -f "$dest" ]; then
        handle_file_conflict "$source" "$dest" "$file_type"
    else
        cp "$source" "$dest"
    fi
}

# Copy hook files
copy_hook_files() {
    print_color "$YELLOW" "Copying hook files..."
    echo

    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        # Copy notification hook
        if [ -f "$SCRIPT_DIR/hooks/notify.py" ]; then
            copy_with_check "$SCRIPT_DIR/hooks/notify.py" \
                          "$TARGET_DIR/.claude/hooks/notify.py" \
                          "Notification hook"
        fi

        # Copy sounds
        if [ -d "$SCRIPT_DIR/hooks/sounds" ]; then
            for sound in "$SCRIPT_DIR/hooks/sounds/"*; do
                if [ -f "$sound" ]; then
                    dest="$TARGET_DIR/.claude/hooks/sounds/$(basename "$sound")"
                    copy_with_check "$sound" "$dest" "Notification sound"
                fi
            done
        fi

        # Copy README
        if [ -f "$SCRIPT_DIR/hooks/Readme.md" ]; then
            copy_with_check "$SCRIPT_DIR/hooks/Readme.md" \
                          "$TARGET_DIR/.claude/hooks/Readme.md" \
                          "Hooks documentation"
        fi
    fi

    print_color "$GREEN" "✓ Hook files copied"
}

# Generate configuration file
generate_config() {
    print_color "$YELLOW" "Generating configuration..."

    local config_file="$TARGET_DIR/.claude/settings.local.json"

    # Check if config already exists
    if [ -f "$config_file" ]; then
        print_color "$YELLOW" "⚠️  Configuration file already exists: $config_file"
        echo "   You may need to manually merge the hook configuration."
        echo
        echo "   Add this to your hooks configuration:"
        echo
        if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
            cat << EOF
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 $TARGET_DIR/.claude/hooks/notify.py input"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 $TARGET_DIR/.claude/hooks/notify.py complete"
          }
        ]
      }
    ]
EOF
        fi
        return
    fi

    # Create new config
    cat > "$config_file" << EOF
{
  "hooks": {
EOF

    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        cat >> "$config_file" << EOF
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 $TARGET_DIR/.claude/hooks/notify.py input"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 $TARGET_DIR/.claude/hooks/notify.py complete"
          }
        ]
      }
    ]
EOF
    fi

    cat >> "$config_file" << EOF
  }
}
EOF

    print_color "$GREEN" "✓ Configuration generated: $config_file"
}

# Show next steps
show_next_steps() {
    echo
    print_color "$GREEN" "=== Installation Complete! ==="
    echo
    print_color "$YELLOW" "Next Steps:"
    echo

    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        echo "1. Test notifications:"
        echo "   python3 $TARGET_DIR/.claude/hooks/notify.py complete"
        echo
    fi

    echo "2. Start Claude Code in your project:"
    echo "   cd $TARGET_DIR && claude"
    echo
}

# Main execution
main() {
    print_header

    check_claude_code
    check_required_tools

    get_target_directory
    prompt_optional_components

    echo
    print_color "$YELLOW" "Ready to install Claude Hooks to:"
    echo "  $TARGET_DIR"
    echo
    if ! safe_read_yn confirm "Continue? (y/n): "; then
        exit 1
    fi

    if [ "$confirm" != "y" ]; then
        print_color "$RED" "Installation cancelled"
        exit 0
    fi

    create_directories
    copy_hook_files
    generate_config

    show_next_steps
}

main "$@"
