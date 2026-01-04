#!/usr/bin/env bash

# Claude Code Development Kit Setup Script
# 
# This script installs the Claude Code Development Kit into a target project,
# providing automated context management and multi-agent workflows for Claude Code.

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
    print_color "$BLUE" "   Claude Code Development Kit Setup"
    print_color "$BLUE" "==========================================="
    echo
}

# Safe read function that works in piped contexts
# Usage: safe_read <variable_name> <prompt_string>
safe_read() {
    local var_name="$1"
    local prompt="$2"
    local temp_input  # Renamed to avoid scope collision

    # Check if a TTY is available for interactive input
    if [ ! -t 0 ] && [ ! -c /dev/tty ]; then
        print_color "$RED" "❌ Cannot prompt for input: No TTY available."
        return 1
    fi

    # Determine the input source
    local input_source
    if [ -t 0 ]; then
        input_source="/dev/stdin" # Standard input is the terminal
    else
        input_source="/dev/tty"   # Standard input is piped, use the terminal
    fi

    # Use read -p for the prompt. The prompt is sent to stderr by default
    # when reading from a source other than the terminal, so it's visible.
    read -r -p "$prompt" temp_input < "$input_source"

    # Assign the value to the variable name passed as the first argument
    # using `printf -v`. This is a safer way to do indirect assignment.
    printf -v "$var_name" '%s' "$temp_input"
}

# Safe read function for yes/no questions with validation
# Usage: safe_read_yn <variable_name> <prompt_string>
safe_read_yn() {
    local var_name="$1"
    local prompt="$2"
    local user_input
    local sanitized_input
    local valid_input=false
    local first_attempt=true

    # Determine the input source
    local input_source
    if [ -t 0 ]; then
        input_source="/dev/stdin"
    else
        input_source="/dev/tty"
    fi

    while [ "$valid_input" = false ]; do
        if [ "$first_attempt" = true ]; then
            if ! safe_read user_input "$prompt"; then
                return 1
            fi
            first_attempt=false
        else
            # On retry, read directly (prompt already printed)
            read -r user_input < "$input_source"
        fi

        # Sanitize input: remove carriage returns and whitespace
        sanitized_input="${user_input//$'\r'/}"  # Remove \r
        sanitized_input="$(echo "$sanitized_input" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

        case "$sanitized_input" in
            y|n)
                valid_input=true
                printf -v "$var_name" '%s' "$sanitized_input"
                ;;
            *)
                printf "${YELLOW}Please enter 'y' for yes or 'n' for no.${NC} (y/n): "
                ;;
        esac
    done
}

# Safe read function for file conflict choices with validation
# Usage: safe_read_conflict <variable_name>
safe_read_conflict() {
    local var_name="$1"
    local user_input
    local sanitized_input
    local valid_input=false
    local first_attempt=true

    # Determine the input source
    local input_source
    if [ -t 0 ]; then
        input_source="/dev/stdin"
    else
        input_source="/dev/tty"
    fi

    while [ "$valid_input" = false ]; do
        if [ "$first_attempt" = true ]; then
            if ! safe_read user_input "   Your choice: "; then
                return 1
            fi
            first_attempt=false
        else
            # On retry, read directly (prompt already printed)
            read -r user_input < "$input_source"
        fi

        # Sanitize input: remove carriage returns and whitespace
        sanitized_input="${user_input//$'\r'/}"  # Remove \r
        sanitized_input="$(echo "$sanitized_input" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

        case "$sanitized_input" in
            o|s|a|n)
                valid_input=true
                printf -v "$var_name" '%s' "$sanitized_input"
                ;;
            *)
                printf "${YELLOW}   Invalid choice. Please enter o, s, a, or n.${NC} Your choice: "
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
        echo "After installation, make sure 'claude' command is available in your terminal"
        exit 1
    fi
    
    print_color "$GREEN" "✓ Claude Code is installed"
}

# Check for required tools
check_required_tools() {
    local missing_tools=()
    
    for tool in jq grep cat mkdir cp chmod; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_color "$RED" "❌ Missing required tools: ${missing_tools[*]}"
        echo
        echo "These tools are needed for:"
        echo "  • jq     - Parse and generate JSON configuration files"
        echo "  • grep   - Search and filter file contents"
        echo "  • cat    - Read and display files"
        echo "  • mkdir  - Create directory structure"
        echo "  • cp     - Copy framework files"
        echo "  • chmod  - Set executable permissions on scripts"
        echo
        echo "On macOS: Most are pre-installed, install jq with: brew install jq"
        echo "On Ubuntu/Debian: sudo apt-get install ${missing_tools[*]}"
        echo "On other systems: Use your package manager to install these tools"
        exit 1
    fi
    
    print_color "$GREEN" "✓ All required tools are available"
}

# Install uv package manager
install_uv_package() {
    print_color "$YELLOW" "Installing uv..."

    case "$(uname -s)" in
        Darwin*|Linux*)
            # macOS and Linux use the shell installer
            if command -v curl &> /dev/null; then
                curl -LsSf https://astral.sh/uv/install.sh | sh
            elif command -v wget &> /dev/null; then
                wget -qO- https://astral.sh/uv/install.sh | sh
            else
                print_color "$RED" "❌ Neither curl nor wget found. Cannot install uv."
                return 1
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows uses PowerShell installer
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS for automatic uv installation"
            return 1
            ;;
    esac
}

# Get target directory
get_target_directory() {
    echo
    print_color "$YELLOW" "Where would you like to install the Claude Code Development Kit?"
    local prompt="Enter target project directory (or . for current directory): "
    if ! safe_read input_dir "$prompt"; then
        exit 1
    fi
    
    if [ "$input_dir" = "." ]; then
        # If run from installer, use the original directory
        if [ -n "${INSTALLER_ORIGINAL_PWD:-}" ]; then
            TARGET_DIR="$INSTALLER_ORIGINAL_PWD"
        else
            # Otherwise use current directory (for manual runs)
            TARGET_DIR="$(pwd)"
        fi
    else
        TARGET_DIR="$(cd "$input_dir" 2>/dev/null && pwd)" || {
            print_color "$RED" "❌ Directory '$input_dir' does not exist"
            exit 1
        }
    fi
    
    # Check if target is the framework source directory
    if [ "$TARGET_DIR" = "$SCRIPT_DIR" ]; then
        print_color "$RED" "❌ Cannot install framework into its own source directory"
        echo "Please choose a different target directory"
        exit 1
    fi
    
    print_color "$GREEN" "✓ Target directory: $TARGET_DIR"
}

# Prompt for optional components
prompt_optional_components() {
    echo
    print_color "$YELLOW" "Optional Components:"
    echo

    # Notifications
    print_color "$CYAN" "Notification System (Convenience Feature)"
    echo "  Plays audio alerts when tasks complete or input is needed"
    if ! safe_read_yn INSTALL_NOTIFICATIONS "  Set up notification hooks? (y/n): "; then
        exit 1
    fi

    # Check for uv if notifications are enabled (required for running Python scripts with dependencies)
    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        if ! command -v uv &> /dev/null; then
            print_color "$YELLOW" "⚠️  uv is required for notification hooks but not found"
            echo "  The notification script uses uv for automatic dependency management."
            echo
            if ! safe_read_yn install_uv "  Would you like to install uv now? (y/n): "; then
                exit 1
            fi

            if [ "$install_uv" = "y" ]; then
                install_uv_package
                # Verify installation
                if command -v uv &> /dev/null; then
                    print_color "$GREEN" "✓ uv installed successfully"
                else
                    # Try to source shell profile to get uv in PATH
                    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
                    if command -v uv &> /dev/null; then
                        print_color "$GREEN" "✓ uv installed successfully"
                    else
                        print_color "$RED" "❌ uv installation failed or not in PATH"
                        print_color "$YELLOW" "  Please restart your terminal and run setup again."
                        print_color "$YELLOW" "Disabling notification hooks..."
                        INSTALL_NOTIFICATIONS="n"
                    fi
                fi
            else
                echo "  Install manually from: https://docs.astral.sh/uv/getting-started/installation/"
                print_color "$YELLOW" "Disabling notification hooks..."
                INSTALL_NOTIFICATIONS="n"
            fi
        else
            print_color "$GREEN" "✓ uv is available for running notification hooks"
        fi
    fi
}

# Create directory structure
create_directories() {
    print_color "$YELLOW" "Creating directory structure..."
    
    
    # Only create sounds directory if notifications are enabled
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
    
    # If policies are already set, apply them
    if [ "$OVERWRITE_ALL" = "y" ]; then
        cp "$source_file" "$dest_file"
        return 0
    elif [ "$SKIP_ALL" = "y" ]; then
        return 1
    fi
    
    # Show conflict and ask user
    print_color "$YELLOW" "⚠️  File already exists: $(basename "$dest_file")"
    echo "   Type: $file_type"
    echo "   Location: $dest_file"
    echo
    echo "   What would you like to do?"
    echo "   [o] Overwrite - Replace the existing file with the new one"
    echo "   [s] Skip - Keep the existing file, don't copy the new one"
    echo "   [a] Always overwrite - Replace this and all future existing files"
    echo "   [n] Never overwrite - Skip this and all future existing files"
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
            print_color "$GREEN" "   ✓ Overwritten (will automatically overwrite all future conflicts)"
            return 0
            ;;
        n)
            SKIP_ALL="y"
            print_color "$YELLOW" "   → Skipped (will automatically skip all future conflicts)"
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

# Copy framework files
copy_framework_files() {
    print_color "$YELLOW" "Copying framework files..."
    echo
    
    # Copy hooks based on user selections
    if [ -d "$SCRIPT_DIR/hooks" ]; then
        # Copy notification hook and sounds if notifications are selected
        if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
            if [ -f "$SCRIPT_DIR/hooks/notify.py" ]; then
                copy_with_check "$SCRIPT_DIR/hooks/notify.py" \
                              "$TARGET_DIR/.claude/hooks/notify.py" \
                              "Notification hook"
                # Make the script executable (uses uv shebang for dependency management)
                chmod +x "$TARGET_DIR/.claude/hooks/notify.py"
            fi
            
            # Copy sounds with conflict handling
            if [ -d "$SCRIPT_DIR/hooks/sounds" ]; then
                for sound in "$SCRIPT_DIR/hooks/sounds/"*; do
                    if [ -f "$sound" ]; then
                        dest="$TARGET_DIR/.claude/hooks/sounds/$(basename "$sound")"
                        copy_with_check "$sound" "$dest" "Notification sound"
                    fi
                done
            fi
        fi
        
        # Copy README for reference
        if [ -f "$SCRIPT_DIR/hooks/README.md" ]; then
            copy_with_check "$SCRIPT_DIR/hooks/README.md" \
                          "$TARGET_DIR/.claude/hooks/README.md" \
                          "Hooks documentation"
        fi
        
        # Copy setup files
        if [ -d "$SCRIPT_DIR/hooks/setup" ]; then
            mkdir -p "$TARGET_DIR/.claude/hooks/setup"
            for setup_file in "$SCRIPT_DIR/hooks/setup/"*; do
                if [ -f "$setup_file" ]; then
                    dest="$TARGET_DIR/.claude/hooks/setup/$(basename "$setup_file")"
                    copy_with_check "$setup_file" "$dest" "Setup file"
                fi
            done
        fi
    fi
		
    print_color "$GREEN" "✓ Framework files copied"
}

# Generate configuration file
generate_config() {
    print_color "$YELLOW" "Generating configuration..."

    local config_file="$TARGET_DIR/.claude/settings.local.json"

    # Start building the configuration with new hooks format
    cat > "$config_file" << EOF
{
  "hooks": {
EOF
    # Add notification hooks if enabled
    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        cat >> "$config_file" << EOF
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$TARGET_DIR/.claude/hooks/notify.py input"
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
            "command": "$TARGET_DIR/.claude/hooks/notify.py complete"
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
    local step_num=1
    
    echo "${step_num}. Customize your project context:"
    echo "   - Edit: $TARGET_DIR/CLAUDE.md"
    echo "   - Update project structure in: $TARGET_DIR/docs/ai-context/project-structure.md"
    echo
    ((step_num++))

    if [ "$INSTALL_NOTIFICATIONS" = "y" ]; then
        echo "${step_num}. Test notifications:"
        echo "   - Run: $TARGET_DIR/.claude/hooks/notify.py input"
        echo
        ((step_num++))
    fi
}

# Main execution
main() {
    print_header
    
    # Run checks
    check_claude_code
    check_required_tools
    
    # Get user input
    get_target_directory
    prompt_optional_components
    
    # Confirm installation
    echo
    print_color "$YELLOW" "Ready to install Claude Code Development Kit to:"
    echo "  $TARGET_DIR"
    echo
    if ! safe_read_yn confirm "Continue? (y/n): "; then
        exit 1
    fi
    
    if [ "$confirm" != "y" ]; then
        print_color "$RED" "Installation cancelled"
        exit 0
    fi
    
    # Perform installation
    create_directories
    copy_framework_files
    generate_config

    # Show completion information
    show_next_steps
}

# Run the script
main "$@"