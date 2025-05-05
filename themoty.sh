#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THEMOTY - Terminal Theme Manager
# A comprehensive CLI/TUI tool for managing terminal themes using iTerm2-Color-Schemes
# Author: eraxe
# GitHub: https://github.com/eraxe/themoty
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Enhanced shell options for safer execution
set -o pipefail
set -o errexit   # Exit on error
set -o nounset   # Treat unset variables as errors
set -o errtrace  # Trap ERR in functions

# Make sure to trap errors
trap 'echo "Error on line $LINENO"; exit 1' ERR

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GLOBAL VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERSION="0.3.0"
SCRIPT_NAME="themoty"
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$SCRIPT_NAME"
THEMES_REPO="https://github.com/mbadolato/iTerm2-Color-Schemes.git"
THEMES_DIR="$SCRIPT_DIR/iTerm2-Color-Schemes"
LOG_FILE="$CONFIG_DIR/themoty.log"
INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="$HOME/.local/bin"
GUM_REPO="https://github.com/charmbracelet/gum.git"
GLOW_REPO="https://github.com/charmbracelet/glow.git"

# Color definitions for synthwave theme
C_PURPLE="\033[38;5;141m"
C_PINK="\033[38;5;219m"
C_BLUE="\033[38;5;39m"
C_CYAN="\033[38;5;86m"
C_GREEN="\033[38;5;120m"
C_YELLOW="\033[38;5;229m"
C_ORANGE="\033[38;5;214m"
C_RED="\033[38;5;196m"
C_RESET="\033[0m"
C_BOLD="\033[1m"

# Terminal configuration paths - add more as needed
declare -A TERMINAL_CONFIGS=(
    ["alacritty"]="$HOME/.config/alacritty/alacritty.yml:$HOME/.config/alacritty.yml"
    ["kitty"]="$HOME/.config/kitty/kitty.conf"
    ["konsole"]="$HOME/.local/share/konsole"
    ["xfce4-terminal"]="$HOME/.config/xfce4/terminal/terminalrc"
    ["terminator"]="$HOME/.config/terminator/config"
    ["tilix"]="$HOME/.config/tilix/schemes"
    ["gnome-terminal"]="$(dconf dump /org/gnome/terminal/)"
    ["foot"]="$HOME/.config/foot/foot.ini"
    ["termite"]="$HOME/.config/termite/config"
    ["wezterm"]="$HOME/.config/wezterm/wezterm.lua:$HOME/.wezterm.lua"
    ["rio"]="$HOME/.config/rio/config.toml"
    ["termux"]="$HOME/.termux/colors.properties"
    ["ghostty"]="$HOME/.config/ghostty/config"
    ["lxterminal"]="$HOME/.config/lxterminal/lxterminal.conf"
    ["xresources"]="$HOME/.Xresources"
    ["vscode"]="$HOME/.config/Code/User/settings.json:$HOME/.vscode/settings.json"
)

# Supported terminals
SUPPORTED_TERMINALS=(
    "alacritty"
    "foot"
    "ghostty"
    "gnome-terminal"
    "kitty"
    "konsole"
    "lxterminal"
    "rio"
    "terminator"
    "termite"
    "termux"
    "tilix"
    "vscode"
    "wezterm"
    "xfce4-terminal"
    "xresources"
)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "INFO") echo -e "${C_BLUE}[INFO]${C_RESET} $message" ;;
        "WARN") echo -e "${C_YELLOW}[WARN]${C_RESET} $message" ;;
        "ERROR") echo -e "${C_RED}[ERROR]${C_RESET} $message" ;;
        "SUCCESS") echo -e "${C_GREEN}[SUCCESS]${C_RESET} $message" ;;
        *) echo -e "${C_BLUE}[$level]${C_RESET} $message" ;;
    esac
}

# Send desktop notifications
notify_user() {
    local message="$1"
    local title="Themoty"
    
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message"
    elif command -v kdialog &> /dev/null; then
        kdialog --passivepopup "$message" 5 --title "$title"
    elif command -v zenity &> /dev/null; then
        zenity --notification --text="$message" --title="$title"
    fi
}

# Load configuration
load_config() {
    local config_file="$CONFIG_DIR/config"
    
    if [[ -f "$config_file" ]]; then
        log "INFO" "Loading configuration from $config_file"
        source "$config_file"
    fi
}

# Save user preferences
save_preferences() {
    local pref_file="$CONFIG_DIR/preferences"
    
    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Save last used terminal and theme
    echo "LAST_TERMINAL=\"$1\"" > "$pref_file"
    echo "LAST_THEME=\"$2\"" >> "$pref_file"
    
    log "INFO" "Preferences saved"
}

# Load user preferences
load_preferences() {
    local pref_file="$CONFIG_DIR/preferences"
    
    if [[ -f "$pref_file" ]]; then
        source "$pref_file"
        log "INFO" "Preferences loaded"
    fi
}

# Export theme settings
export_theme_settings() {
    local export_file="$CONFIG_DIR/theme_export.json"
    local terminal="$1"
    local theme="$2"
    
    mkdir -p "$CONFIG_DIR"
    echo "{\"terminal\":\"$terminal\",\"theme\":\"$theme\",\"exported_at\":\"$(date)\"}" > "$export_file"
    
    log "SUCCESS" "Theme settings exported to $export_file"
    notify_user "Theme settings exported to $export_file"
    return 0
}

# Import theme settings
import_theme_settings() {
    local import_file="$1"
    
    if [[ -z "$import_file" ]]; then
        import_file="$CONFIG_DIR/theme_export.json"
    fi
    
    if [[ ! -f "$import_file" ]]; then
        log "ERROR" "No exported theme settings found: $import_file"
        return 1
    fi
    
    # Check if jq is available for proper JSON parsing
    if command -v jq &> /dev/null; then
        local terminal=$(jq -r '.terminal' "$import_file")
        local theme=$(jq -r '.theme' "$import_file")
    else
        # Fallback to basic grep if jq is not available
        local terminal=$(grep -o '"terminal":"[^"]*"' "$import_file" | cut -d'"' -f4)
        local theme=$(grep -o '"theme":"[^"]*"' "$import_file" | cut -d'"' -f4)
    fi
    
    if [[ -n "$terminal" && -n "$theme" ]]; then
        log "INFO" "Importing theme settings: $theme for $terminal"
        apply_theme "$terminal" "$theme"
        return $?
    else
        log "ERROR" "Invalid exported theme settings."
        return 1
    fi
}

# Check if required dependencies are installed
check_dependencies() {
    local dependencies=("git" "curl" "gum" "glow")
    local missing_deps=()
    
    log "INFO" "Checking dependencies..."
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "WARN" "Missing dependencies: ${missing_deps[*]}"
        
        if [[ " ${missing_deps[*]} " =~ " gum " || " ${missing_deps[*]} " =~ " glow " ]]; then
            echo -e "\n${C_YELLOW}Themoty requires${C_RESET} ${C_BOLD}gum${C_RESET} ${C_YELLOW}and${C_RESET} ${C_BOLD}glow${C_RESET} ${C_YELLOW}for the TUI.${C_RESET}"
            
            if confirm "Would you like to install the missing TUI dependencies?"; then
                install_tui_dependencies
            else
                log "ERROR" "Required dependencies are missing. Please install them manually."
                exit 1
            fi
        else
            log "ERROR" "Required dependencies are missing: ${missing_deps[*]}"
            log "INFO" "Please install them using your package manager."
            exit 1
        fi
    else
        log "SUCCESS" "All dependencies are installed."
    fi
}

# Install TUI dependencies (gum and glow)
install_tui_dependencies() {
    log "INFO" "Installing TUI dependencies..."
    
    # Try to detect the package manager
    if command -v apt &> /dev/null; then
        log "INFO" "Detected apt package manager"
        sudo apt update
        sudo apt install -y golang
        go install github.com/charmbracelet/gum@latest
        go install github.com/charmbracelet/glow@latest
    elif command -v dnf &> /dev/null; then
        log "INFO" "Detected dnf package manager"
        sudo dnf install -y golang
        go install github.com/charmbracelet/gum@latest
        go install github.com/charmbracelet/glow@latest
    elif command -v pacman &> /dev/null; then
        log "INFO" "Detected pacman package manager"
        sudo pacman -S --noconfirm go
        go install github.com/charmbracelet/gum@latest
        go install github.com/charmbracelet/glow@latest
    elif command -v yum &> /dev/null; then
        log "INFO" "Detected yum package manager"
        sudo yum install -y golang
        go install github.com/charmbracelet/gum@latest
        go install github.com/charmbracelet/glow@latest
    else
        # Direct download as fallback
        log "INFO" "No supported package manager found, using direct download"
        
        # Determine architecture
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64) ARCH="amd64" ;;
            aarch64|arm64) ARCH="arm64" ;;
            *) log "ERROR" "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        
        # Download and install gum
        GUM_VERSION=$(curl -s "https://api.github.com/repos/charmbracelet/gum/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
        curl -L "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_${ARCH}.tar.gz" -o /tmp/gum.tar.gz
        mkdir -p /tmp/gum
        tar -xzf /tmp/gum.tar.gz -C /tmp/gum
        
        # Install to user's bin if not running as root, otherwise to system bin
        if [[ $EUID -ne 0 ]]; then
            mkdir -p "$USER_INSTALL_DIR"
            mv /tmp/gum/gum "$USER_INSTALL_DIR/"
            export PATH="$USER_INSTALL_DIR:$PATH"
        else
            mv /tmp/gum/gum "$INSTALL_DIR/"
        fi
        
        # Download and install glow
        GLOW_VERSION=$(curl -s "https://api.github.com/repos/charmbracelet/glow/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
        curl -L "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_Linux_${ARCH}.tar.gz" -o /tmp/glow.tar.gz
        mkdir -p /tmp/glow
        tar -xzf /tmp/glow.tar.gz -C /tmp/glow
        
        if [[ $EUID -ne 0 ]]; then
            mkdir -p "$USER_INSTALL_DIR"
            mv /tmp/glow/glow "$USER_INSTALL_DIR/"
            export PATH="$USER_INSTALL_DIR:$PATH"
        else
            mv /tmp/glow/glow "$INSTALL_DIR/"
        fi
    fi
    
    # Verify installation
    if command -v gum &> /dev/null && command -v glow &> /dev/null; then
        log "SUCCESS" "Successfully installed TUI dependencies."
    else
        log "ERROR" "Failed to install TUI dependencies."
        exit 1
    fi
}

# Check if running with sudo/root privileges
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log "WARN" "Not running with root privileges. System-wide installation may not work."
        return 1
    fi
    return 0
}

# Simple confirmation dialog
confirm() {
    local message="$1"
    local response
    
    if command -v gum &> /dev/null; then
        gum confirm --prompt.foreground="#ff88ff" "$message"
        return $?
    else
        echo -e "${C_PINK}$message ${C_RESET}(y/n)"
        read -r response
        [[ "$response" =~ ^[Yy]$ ]]
        return $?
    fi
}

# Print a styled header
print_header() {
    local text="$1"
    local width=$(tput cols)
    local padding=$(( (width - ${#text}) / 2 ))
    
    echo
    echo -e "${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    printf "${C_PINK}%*s${C_BOLD}%s${C_RESET}${C_PINK}%*s${C_RESET}\n" $padding "" "$text" $padding ""
    echo -e "${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

# Find a terminal config file - enhanced version
find_terminal_config() {
    local terminal=$1
    local config_paths=${TERMINAL_CONFIGS[$terminal]}
    local found_config=""
    
    # If config paths contain colons, try each one
    if [[ $config_paths == *":"* ]]; then
        IFS=':' read -ra paths <<< "$config_paths"
        for path in "${paths[@]}"; do
            # Expand ~ to $HOME
            path="${path/#\~/$HOME}"
            
            # Expand any variables in the path
            eval "path=$path"
            
            if [[ -f "$path" || -d "$path" ]]; then
                found_config="$path"
                break
            fi
        done
    else
        # Expand ~ to $HOME
        config_paths="${config_paths/#\~/$HOME}"
        
        # Expand any variables in the path
        eval "config_paths=$config_paths"
        
        if [[ -f "$config_paths" || -d "$config_paths" ]]; then
            found_config="$config_paths"
        fi
    fi
    
    # If still not found, try some common locations based on terminal
    if [[ -z "$found_config" ]]; then
        case "$terminal" in
            "alacritty")
                local alt_paths=(
                    "$HOME/.config/alacritty/alacritty.yml"
                    "$HOME/.config/alacritty/alacritty.yaml"
                    "$HOME/.config/alacritty.yml"
                    "$HOME/.alacritty.yml"
                )
                ;;
            "kitty")
                local alt_paths=(
                    "$HOME/.config/kitty/kitty.conf"
                    "$HOME/.kitty.conf"
                )
                ;;
            "wezterm")
                local alt_paths=(
                    "$HOME/.config/wezterm/wezterm.lua"
                    "$HOME/.wezterm.lua"
                )
                ;;
            *)
                local alt_paths=()
                ;;
        esac
        
        for path in "${alt_paths[@]}"; do
            if [[ -f "$path" ]]; then
                found_config="$path"
                break
            fi
        done
    fi
    
    # Still not found? Ask the user
    if [[ -z "$found_config" && -t 0 ]]; then
        log "WARN" "Could not automatically find configuration for $terminal"
        echo -e "${C_YELLOW}Please enter the path to your $terminal configuration file:${C_RESET}"
        read -r user_path
        
        if [[ -n "$user_path" ]]; then
            # Expand ~ to $HOME
            user_path="${user_path/#\~/$HOME}"
            
            if [[ -f "$user_path" || -d "$user_path" ]]; then
                found_config="$user_path"
                
                # Update the TERMINAL_CONFIGS array for future use
                TERMINAL_CONFIGS["$terminal"]="$user_path"
                
                # Save to config file
                mkdir -p "$CONFIG_DIR"
                echo "TERMINAL_CONFIGS[$terminal]=\"$user_path\"" >> "$CONFIG_DIR/config"
            else
                log "ERROR" "The specified path does not exist: $user_path"
            fi
        fi
    fi
    
    echo "$found_config"
}

# Detect installed terminals
detect_terminals() {
    local installed_terminals=()
    
    for terminal in "${SUPPORTED_TERMINALS[@]}"; do
        # Check if terminal executable exists in PATH
        if command -v "$terminal" &> /dev/null; then
            installed_terminals+=("$terminal")
            continue
        fi
        
        # Check if config exists
        local config=$(find_terminal_config "$terminal")
        if [[ -n "$config" ]]; then
            installed_terminals+=("$terminal")
        fi
    done
    
    # Special case for Xresources (might not have a command)
    if [[ -f "$HOME/.Xresources" ]] && [[ ! " ${installed_terminals[*]} " =~ " xresources " ]]; then
        installed_terminals+=("xresources")
    fi
    
    echo "${installed_terminals[*]}"
}

# Backup a configuration file
backup_config() {
    local config_file="$1"
    local backup_file="${config_file}.themoty.bak"
    
    # Skip backup for non-file configs (like dconf)
    if [[ ! -f "$config_file" ]]; then
        return 0
    fi
    
    log "INFO" "Backing up $config_file to $backup_file"
    cp "$config_file" "$backup_file"
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Backup created successfully."
        return 0
    else
        log "ERROR" "Failed to create backup."
        return 1
    fi
}

# Restore a configuration from backup
restore_config() {
    local config_file="$1"
    local backup_file="${config_file}.themoty.bak"
    
    if [[ -f "$backup_file" ]]; then
        log "INFO" "Restoring $config_file from backup"
        mv "$backup_file" "$config_file"
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "Config restored successfully."
            return 0
        else
            log "ERROR" "Failed to restore config."
            return 1
        fi
    else
        log "WARN" "No backup found for $config_file"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check for updates
check_for_updates() {
    if [[ ! -d "$THEMES_DIR/.git" ]]; then
        log "WARN" "iTerm2-Color-Schemes repository is not a git repository, cannot check for updates"
        return 1
    fi
    
    log "INFO" "Checking for updates to iTerm2-Color-Schemes repository"
    
    # Store current branch and commit
    local current_branch=$(cd "$THEMES_DIR" && git rev-parse --abbrev-ref HEAD)
    local current_commit=$(cd "$THEMES_DIR" && git rev-parse HEAD)
    
    # Fetch updates
    (cd "$THEMES_DIR" && git fetch)
    
    # Check if there are updates
    local updates=$(cd "$THEMES_DIR" && git log --oneline HEAD..origin/$current_branch)
    
    if [[ -n "$updates" ]]; then
        log "INFO" "Updates available for iTerm2-Color-Schemes repository"
        echo -e "${C_CYAN}The following updates are available:${C_RESET}"
        echo "$updates"
        
        if confirm "Would you like to update now?"; then
            (cd "$THEMES_DIR" && git pull)
            if [[ $? -eq 0 ]]; then
                log "SUCCESS" "iTerm2-Color-Schemes repository updated successfully"
            else
                log "ERROR" "Failed to update iTerm2-Color-Schemes repository"
            fi
        else
            log "INFO" "Update postponed"
        fi
    else
        log "INFO" "iTerm2-Color-Schemes repository is up to date"
    fi
}

# Install the script
install_script() {
    print_header "Installing Themoty"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    if check_sudo; then
        # System-wide installation
        log "INFO" "Installing Themoty system-wide to $INSTALL_DIR/$SCRIPT_NAME"
        cp "$SCRIPT_PATH" "$INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    else
        # User-only installation
        log "INFO" "Installing Themoty to user bin at $USER_INSTALL_DIR/$SCRIPT_NAME"
        mkdir -p "$USER_INSTALL_DIR"
        cp "$SCRIPT_PATH" "$USER_INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$USER_INSTALL_DIR/$SCRIPT_NAME"
        
        # Check if USER_INSTALL_DIR is in PATH
        if [[ ":$PATH:" != *":$USER_INSTALL_DIR:"* ]]; then
            log "WARN" "$USER_INSTALL_DIR is not in your PATH."
            log "INFO" "Add the following line to your shell profile:"
            echo -e "${C_CYAN}export PATH=\"\$PATH:$USER_INSTALL_DIR\"${C_RESET}"
        fi
    fi
    
    # Clone iTerm2-Color-Schemes repository if it doesn't exist
    if [[ ! -d "$THEMES_DIR" ]]; then
        log "INFO" "Cloning iTerm2-Color-Schemes repository"
        git clone "$THEMES_REPO" "$THEMES_DIR"
    fi
    
    log "SUCCESS" "Themoty installed successfully!"
    log "INFO" "Run 'themoty' to start the TUI"
}

# Update the script
update_script() {
    print_header "Updating Themoty"
    
    log "INFO" "Checking for updates..."
    
    # Update the iTerm2-Color-Schemes repository
    if [[ -d "$THEMES_DIR" && -d "$THEMES_DIR/.git" ]]; then
        log "INFO" "Updating iTerm2-Color-Schemes repository"
        (cd "$THEMES_DIR" && git pull)
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "iTerm2-Color-Schemes repository updated successfully."
        else
            log "ERROR" "Failed to update iTerm2-Color-Schemes repository."
        fi
    else
        log "INFO" "Cloning iTerm2-Color-Schemes repository"
        git clone "$THEMES_REPO" "$THEMES_DIR"
    fi
    
    # Update Themoty from GitHub
    log "INFO" "Updating Themoty from GitHub"
    local temp_dir=$(mktemp -d)
    git clone https://github.com/eraxe/themoty.git "$temp_dir"
    
    if [[ $? -eq 0 ]]; then
        local new_version=$(grep -m 1 "VERSION=" "$temp_dir/themoty.sh" | cut -d'"' -f2)
        
        if [[ "$new_version" != "$VERSION" ]]; then
            log "INFO" "New version found: $new_version (current: $VERSION)"
            
            # Find the installed script location
            local installed_script=""
            if [[ -x "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
                installed_script="$INSTALL_DIR/$SCRIPT_NAME"
            elif [[ -x "$USER_INSTALL_DIR/$SCRIPT_NAME" ]]; then
                installed_script="$USER_INSTALL_DIR/$SCRIPT_NAME"
            fi
            
            if [[ -n "$installed_script" ]]; then
                log "INFO" "Updating Themoty at $installed_script"
                cp "$temp_dir/themoty.sh" "$installed_script"
                chmod +x "$installed_script"
                log "SUCCESS" "Themoty updated successfully to version $new_version!"
            else
                log "ERROR" "Could not find the installed Themoty script."
            fi
        else
            log "INFO" "Already running the latest version ($VERSION)."
        fi
        
        # Clean up
        rm -rf "$temp_dir"
    else
        log "ERROR" "Failed to fetch updates from GitHub."
    fi
}

# Remove the script
remove_script() {
    print_header "Uninstalling Themoty"
    
    if confirm "Are you sure you want to uninstall Themoty?"; then
        local removed=0
        
        # Remove from system bin
        if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
            log "INFO" "Removing from $INSTALL_DIR/$SCRIPT_NAME"
            sudo rm "$INSTALL_DIR/$SCRIPT_NAME"
            removed=1
        fi
        
        # Remove from user bin
        if [[ -f "$USER_INSTALL_DIR/$SCRIPT_NAME" ]]; then
            log "INFO" "Removing from $USER_INSTALL_DIR/$SCRIPT_NAME"
            rm "$USER_INSTALL_DIR/$SCRIPT_NAME"
            removed=1
        fi
        
        # Ask about removing config and themes
        if confirm "Do you want to remove configuration and themes too?"; then
            log "INFO" "Removing configuration directory"
            rm -rf "$CONFIG_DIR"
            
            if [[ -d "$THEMES_DIR" ]]; then
                log "INFO" "Removing iTerm2-Color-Schemes directory"
                rm -rf "$THEMES_DIR"
            fi
        fi
        
        if [[ $removed -eq 1 ]]; then
            log "SUCCESS" "Themoty has been uninstalled successfully."
        else
            log "ERROR" "Could not find Themoty installation to remove."
        fi
    else
        log "INFO" "Uninstallation cancelled."
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THEME APPLICATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Search and filter themes by name
search_themes() {
    local terminal="$1"
    local search_term="$2"
    local available_themes=($(get_available_themes "$terminal"))
    local matching_themes=()
    
    for theme in "${available_themes[@]}"; do
        if [[ "$theme" == *"$search_term"* ]]; then
            matching_themes+=("$theme")
        fi
    done
    
    echo "${matching_themes[*]}"
}

# Apply a random theme to terminal
apply_random_theme() {
    local terminal="$1"
    local available_themes=($(get_available_themes "$terminal"))
    local theme_count=${#available_themes[@]}
    
    if [[ $theme_count -eq 0 ]]; then
        log "ERROR" "No themes found for $terminal."
        return 1
    fi
    
    local random_index=$((RANDOM % theme_count))
    local random_theme="${available_themes[$random_index]}"
    
    log "INFO" "Applying random theme: $random_theme"
    apply_theme "$terminal" "$random_theme"
    
    # Notify user
    notify_user "Applied random theme: $random_theme to $terminal"
    
    return $?
}

# Preview a theme
preview_theme() {
    local terminal="$1"
    local theme="$2"
    local theme_dir=""
    
    # Map terminal name to directory in iTerm2-Color-Schemes
    case "$terminal" in
        "alacritty") theme_dir="$THEMES_DIR/alacritty" ;;
        "foot") theme_dir="$THEMES_DIR/foot" ;;
        "ghostty") theme_dir="$THEMES_DIR/ghostty" ;;
        "gnome-terminal") theme_dir="$THEMES_DIR/dynamic-colors" ;;
        "kitty") theme_dir="$THEMES_DIR/kitty" ;;
        "konsole") theme_dir="$THEMES_DIR/konsole" ;;
        "lxterminal") theme_dir="$THEMES_DIR/lxterminal" ;;
        "rio") theme_dir="$THEMES_DIR/rio" ;;
        "terminator") theme_dir="$THEMES_DIR/terminator" ;;
        "termite") theme_dir="$THEMES_DIR/termite" ;;
        "termux") theme_dir="$THEMES_DIR/termux" ;;
        "tilix") theme_dir="$THEMES_DIR/tilix" ;;
        "wezterm") theme_dir="$THEMES_DIR/wezterm" ;;
        "xfce4-terminal") theme_dir="$THEMES_DIR/xfce4terminal" ;;
        "xresources") theme_dir="$THEMES_DIR/Xresources" ;;
        *) theme_dir="$THEMES_DIR/schemes" ;;
    esac
    
    # Find the theme file
    local theme_file=""
    local theme_files=()
    
    case "$terminal" in
        "alacritty") theme_files=($(find "$theme_dir" -name "$theme.yml" -type f)) ;;
        "kitty") theme_files=($(find "$theme_dir" -name "$theme.conf" -type f)) ;;
        "konsole") theme_files=($(find "$theme_dir" -name "$theme.colorscheme" -type f)) ;;
        "wezterm") theme_files=($(find "$theme_dir" -name "$theme.toml" -type f)) ;;
        "tilix") theme_files=($(find "$theme_dir" -name "$theme.json" -type f)) ;;
        *) 
            theme_files=($(find "$theme_dir" -type f -name "$theme" -o -name "$theme.*"))
            if [[ ${#theme_files[@]} -eq 0 ]]; then
                # Try fallback to schemes directory
                theme_files=($(find "$THEMES_DIR/schemes" -type f -name "$theme.itermcolors"))
            fi
            ;;
    esac
    
    if [[ ${#theme_files[@]} -gt 0 ]]; then
        theme_file="${theme_files[0]}"
    else
        log "ERROR" "Theme file not found for $theme"
        return 1
    fi
    
    # Display a preview
    print_header "Theme Preview: $theme"
    
    # Create a temporary script to display color blocks
    local tmp_script=$(mktemp)
    cat > "$tmp_script" << 'EOF'
#!/usr/bin/env bash

# ANSI color codes
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BRIGHT_BLACK="\033[90m"
BRIGHT_RED="\033[91m"
BRIGHT_GREEN="\033[92m"
BRIGHT_YELLOW="\033[93m"
BRIGHT_BLUE="\033[94m"
BRIGHT_MAGENTA="\033[95m"
BRIGHT_CYAN="\033[96m"
BRIGHT_WHITE="\033[97m"
RESET="\033[0m"
BOLD="\033[1m"
BG_BLACK="\033[40m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_YELLOW="\033[43m"
BG_BLUE="\033[44m"
BG_MAGENTA="\033[45m"
BG_CYAN="\033[46m"
BG_WHITE="\033[47m"
BG_BRIGHT_BLACK="\033[100m"
BG_BRIGHT_RED="\033[101m"
BG_BRIGHT_GREEN="\033[102m"
BG_BRIGHT_YELLOW="\033[103m"
BG_BRIGHT_BLUE="\033[104m"
BG_BRIGHT_MAGENTA="\033[105m"
BG_BRIGHT_CYAN="\033[106m"
BG_BRIGHT_WHITE="\033[107m"

# Display function
display_colors() {
    echo -e "${BOLD}Standard Colors${RESET}"
    echo -e "${BLACK}${BG_WHITE} Black ${RESET} ${RED} Red ${RESET} ${GREEN} Green ${RESET} ${YELLOW} Yellow ${RESET} ${BLUE} Blue ${RESET} ${MAGENTA} Magenta ${RESET} ${CYAN} Cyan ${RESET} ${WHITE}${BG_BLACK} White ${RESET}"
    echo
    echo -e "${BOLD}Bright Colors${RESET}"
    echo -e "${BRIGHT_BLACK}${BG_WHITE} Bright Black ${RESET} ${BRIGHT_RED} Bright Red ${RESET} ${BRIGHT_GREEN} Bright Green ${RESET} ${BRIGHT_YELLOW} Bright Yellow ${RESET} ${BRIGHT_BLUE} Bright Blue ${RESET} ${BRIGHT_MAGENTA} Bright Magenta ${RESET} ${BRIGHT_CYAN} Bright Cyan ${RESET} ${BRIGHT_WHITE}${BG_BLACK} Bright White ${RESET}"
    echo
    echo -e "${BOLD}Example Text${RESET}"
    echo -e "The ${RED}quick ${YELLOW}brown ${GREEN}fox ${CYAN}jumps ${BLUE}over ${MAGENTA}the ${RED}lazy ${GREEN}dog${RESET}"
    echo -e "${BG_BLACK}${WHITE}Black BG${RESET} ${BG_RED}Red BG${RESET} ${BG_GREEN}Green BG${RESET} ${BG_YELLOW}Yellow BG${RESET} ${BG_BLUE}${WHITE}Blue BG${RESET} ${BG_MAGENTA}Magenta BG${RESET} ${BG_CYAN}Cyan BG${RESET} ${BG_WHITE}${BLACK}White BG${RESET}"
}

display_colors
EOF
    
    chmod +x "$tmp_script"
    "$tmp_script"
    rm "$tmp_script"
    
    echo
    echo -e "${C_CYAN}Note:${C_RESET} This is an approximation using ANSI colors. The actual appearance may vary."
    echo -e "${C_CYAN}Theme file:${C_RESET} $theme_file"
    
    # If the theme file is readable text, show the first few lines
    if [[ "$theme_file" == *".yml" || "$theme_file" == *".conf" || "$theme_file" == *".ini" || "$theme_file" == *".toml" ]]; then
        echo
        echo -e "${C_CYAN}Theme file preview (first 10 lines):${C_RESET}"
        head -n 10 "$theme_file"
        echo "..."
    fi
    
    echo
    return 0
}

# Get available themes for a specific terminal
get_available_themes() {
    local terminal="$1"
    local themes_dir="$THEMES_DIR"
    
    # Map terminal name to directory in iTerm2-Color-Schemes
    case "$terminal" in
        "alacritty") themes_dir="$THEMES_DIR/alacritty" ;;
        "foot") themes_dir="$THEMES_DIR/foot" ;;
        "ghostty") themes_dir="$THEMES_DIR/ghostty" ;;
        "gnome-terminal") themes_dir="$THEMES_DIR/dynamic-colors" ;; # Special case
        "kitty") themes_dir="$THEMES_DIR/kitty" ;;
        "konsole") themes_dir="$THEMES_DIR/konsole" ;;
        "lxterminal") themes_dir="$THEMES_DIR/lxterminal" ;;
        "rio") themes_dir="$THEMES_DIR/rio" ;;
        "terminator") themes_dir="$THEMES_DIR/terminator" ;;
        "termite") themes_dir="$THEMES_DIR/termite" ;;
        "termux") themes_dir="$THEMES_DIR/termux" ;;
        "tilix") themes_dir="$THEMES_DIR/tilix" ;;
        "wezterm") themes_dir="$THEMES_DIR/wezterm" ;;
        "xfce4-terminal") themes_dir="$THEMES_DIR/xfce4terminal" ;;
        "xresources") themes_dir="$THEMES_DIR/Xresources" ;;
        *) themes_dir="$THEMES_DIR/schemes" ;; # Fallback to base scheme files
    esac
    
    # Check if directory exists
    if [[ ! -d "$themes_dir" ]]; then
        log "ERROR" "Theme directory not found: $themes_dir"
        return 1
    fi
    
    # Get theme files based on terminal type
    local theme_files=()
    case "$terminal" in
        "alacritty") theme_files=($(find "$themes_dir" -name "*.yml" -type f | sort)) ;;
        "foot") theme_files=($(find "$themes_dir" -name "*.ini" -type f | sort)) ;;
        "kitty") theme_files=($(find "$themes_dir" -name "*.conf" -type f | sort)) ;;
        "konsole") theme_files=($(find "$themes_dir" -name "*.colorscheme" -type f | sort)) ;;
        "wezterm") theme_files=($(find "$themes_dir" -name "*.toml" -type f | sort)) ;;
        *) theme_files=($(find "$themes_dir" -type f | sort)) ;;
    esac
    
    # Extract theme names
    local themes=()
    for file in "${theme_files[@]}"; do
        local theme_name=$(basename "$file" | sed 's/\.[^.]*$//')
        themes+=("$theme_name")
    done
    
    echo "${themes[*]}"
}

# Apply theme to Alacritty
apply_theme_alacritty() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/alacritty/$theme.yml"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Check if config already has colors section
    if grep -q "^colors:" "$config"; then
        # Replace existing colors section
        local temp_file=$(mktemp)
        awk -v theme_file="$theme_file" '
            BEGIN { in_colors = 0; printed = 0; }
            /^colors:/ { in_colors = 1; print; printed = 1; system("cat " theme_file); next; }
            in_colors && /^[a-z]/ && !/^colors:/ { in_colors = 0; }
            !in_colors { print; }
        ' "$config" > "$temp_file"
        mv "$temp_file" "$config"
    else
        # Append theme to config
        echo -e "\n# Colors (Themoty: $theme)" >> "$config"
        cat "$theme_file" >> "$config"
    fi
    
    log "SUCCESS" "Applied $theme to Alacritty."
    return 0
}

# Apply theme to Kitty
apply_theme_kitty() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/kitty/$theme.conf"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Remove existing color settings
    local temp_file=$(mktemp)
    grep -v "^color[0-9]\\|^foreground\\|^background\\|^cursor\\|^selection_\\|^active_\\|^inactive_" "$config" > "$temp_file"
    
    # Add new theme
    echo -e "\n# Theme: $theme (Applied by Themoty)" >> "$temp_file"
    cat "$theme_file" >> "$temp_file"
    
    mv "$temp_file" "$config"
    
    log "SUCCESS" "Applied $theme to Kitty."
    return 0
}

# Apply theme to Konsole
apply_theme_konsole() {
    local config_dir="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/konsole/$theme.colorscheme"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    # Ensure the directory exists
    mkdir -p "$config_dir"
    
    # Copy the theme file
    cp "$theme_file" "$config_dir/"
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Installed $theme for Konsole in $config_dir"
        
        # Find and modify profile files to use the new color scheme
        local profiles=("$config_dir"/*rc)
        if [[ ${#profiles[@]} -gt 0 && -f "${profiles[0]}" ]]; then
            for profile in "${profiles[@]}"; do
                if [[ -f "$profile" ]]; then
                    backup_config "$profile"
                    
                    # Update ColorScheme in profile
                    if grep -q "^ColorScheme=" "$profile"; then
                        sed -i "s/^ColorScheme=.*/ColorScheme=$theme/" "$profile"
                    else
                        echo "ColorScheme=$theme" >> "$profile"
                    fi
                    
                    log "INFO" "Updated profile $profile to use $theme"
                fi
            done
        else
            log "WARN" "No profile files found in $config_dir. You may need to set the theme manually."
        fi
        
        return 0
    else
        log "ERROR" "Failed to install theme for Konsole."
        return 1
    fi
}

# Apply theme to XFCE4 Terminal
apply_theme_xfce4_terminal() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/xfce4terminal/colorschemes/$theme.theme"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract color settings from theme file
    local colors=$(grep "^Color" "$theme_file" | sed 's/\[.*\]//')
    
    # Update config file
    local temp_file=$(mktemp)
    
    # Remove existing color settings and add new ones
    grep -v "^Color" "$config" > "$temp_file"
    echo -e "\n# Theme: $theme (Applied by Themoty)" >> "$temp_file"
    echo "$colors" >> "$temp_file"
    
    mv "$temp_file" "$config"
    
    log "SUCCESS" "Applied $theme to XFCE4 Terminal."
    return 0
}

# Apply theme to Terminator
apply_theme_terminator() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/terminator/themes/$theme.config"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract color settings from theme file
    local colors=$(grep -A 20 "\\[profiles\\]" "$theme_file" | grep -v "\\[profiles\\]")
    
    # Update config file
    if grep -q "\\[profiles\\]" "$config"; then
        # Config already has profiles section
        local temp_file=$(mktemp)
        awk -v colors="$colors" '
            BEGIN { in_profiles = 0; in_profile = 0; printed = 0; }
            /\[profiles\]/ { in_profiles = 1; print; next; }
            in_profiles && /\[\[.*\]\]/ { 
                in_profile = 1; 
                print; 
                if (!printed) {
                    print "    # Theme: '"$theme"' (Applied by Themoty)";
                    print colors;
                    printed = 1;
                }
                next;
            }
            in_profiles && in_profile && /palette|background_color|foreground_color|cursor_color/ { next; }
            { print; }
        ' "$config" > "$temp_file"
        mv "$temp_file" "$config"
    else
        # No profiles section, add one
        echo -e "\n[profiles]" >> "$config"
        echo "  [[default]]" >> "$config"
        echo "    # Theme: $theme (Applied by Themoty)" >> "$config"
        echo "$colors" >> "$config"
    fi
    
    log "SUCCESS" "Applied $theme to Terminator."
    return 0
}

# Apply theme to Foot
apply_theme_foot() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/foot/$theme.ini"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract colors section from theme file
    local colors=$(grep -A 20 "^\\[colors\\]" "$theme_file")
    
    # Update config file
    if grep -q "^\\[colors\\]" "$config"; then
        # Replace existing colors section
        local temp_file=$(mktemp)
        awk -v colors="$colors" '
            BEGIN { in_colors = 0; printed = 0; }
            /^\[colors\]/ { in_colors = 1; print "# Theme: '"$theme"' (Applied by Themoty)"; print colors; printed = 1; next; }
            in_colors && /^\[/ && !/^\[colors\]/ { in_colors = 0; print; next; }
            in_colors { next; }
            { print; }
        ' "$config" > "$temp_file"
        mv "$temp_file" "$config"
    else
        # No colors section, add one
        echo -e "\n# Theme: $theme (Applied by Themoty)" >> "$config"
        echo "$colors" >> "$config"
    fi
    
    log "SUCCESS" "Applied $theme to Foot."
    return 0
}

# Apply theme to Wezterm
apply_theme_wezterm() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/wezterm/$theme.toml"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Check if config already has a theme setting
    if grep -q "color_scheme" "$config"; then
        # Replace existing theme setting
        sed -i "s/color_scheme = .*/color_scheme = \"$theme\",/" "$config"
    else
        # Add theme setting
        echo -e "\n-- Theme applied by Themoty" >> "$config"
        echo "config.color_scheme = \"$theme\"" >> "$config"
    fi
    
    # Create the themes directory if it doesn't exist
    local wezterm_dir=$(dirname "$config")
    mkdir -p "$wezterm_dir/colors"
    
    # Copy the theme file to the wezterm colors directory
    cp "$theme_file" "$wezterm_dir/colors/$theme.toml"
    
    log "SUCCESS" "Applied $theme to Wezterm."
    return 0
}

# Apply theme to Rio
apply_theme_rio() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/rio/$theme.toml"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract colors section from theme file
    local colors=$(cat "$theme_file")
    
    # Check if config already has a theme section
    if grep -q "\\[theme\\]" "$config"; then
        # Replace existing theme section
        local temp_file=$(mktemp)
        awk -v colors="$colors" '
            BEGIN { in_theme = 0; printed = 0; }
            /^\[theme\]/ { in_theme = 1; print; print "# Theme: '"$theme"' (Applied by Themoty)"; print colors; printed = 1; next; }
            in_theme && /^\[/ && !/^\[theme\]/ { in_theme = 0; print; next; }
            in_theme { next; }
            { print; }
        ' "$config" > "$temp_file"
        mv "$temp_file" "$config"
    else
        # No theme section, add one
        echo -e "\n[theme]" >> "$config"
        echo "# Theme: $theme (Applied by Themoty)" >> "$config"
        echo "$colors" >> "$config"
    fi
    
    log "SUCCESS" "Applied $theme to Rio."
    return 0
}

# Apply theme to Xresources
apply_theme_xresources() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/Xresources/$theme"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract colors from theme file
    local colors=$(cat "$theme_file")
    
    # Remove existing color definitions
    local temp_file=$(mktemp)
    grep -v "^\*color\\|^URxvt\\.color\\|^XTerm\\.color\\|^\\*foreground\\|^\\*background\\|^URxvt\\.foreground\\|^URxvt\\.background" "$config" > "$temp_file"
    
    # Add new theme
    echo -e "\n! Theme: $theme (Applied by Themoty)" >> "$temp_file"
    echo "$colors" >> "$temp_file"
    
    mv "$temp_file" "$config"
    
    # Reload Xresources
    if command -v xrdb &> /dev/null; then
        xrdb -merge "$config"
        log "INFO" "Reloaded Xresources with xrdb."
    else
        log "WARN" "xrdb not found. You may need to reload Xresources manually."
    fi
    
    log "SUCCESS" "Applied $theme to Xresources."
    return 0
}

# Apply theme to GhostTy
apply_theme_ghostty() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/ghostty/$theme"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract colors from theme file
    local colors=$(cat "$theme_file")
    
    # Remove existing color definitions
    local temp_file=$(mktemp)
    grep -v "^background-color\\|^foreground-color\\|^palette-\\|^cursor-color" "$config" > "$temp_file"
    
    # Add new theme
    echo -e "\n# Theme: $theme (Applied by Themoty)" >> "$temp_file"
    echo "$colors" >> "$temp_file"
    
    mv "$temp_file" "$config"
    
    log "SUCCESS" "Applied $theme to GhostTy."
    return 0
}

# Apply theme to LXTerminal
apply_theme_lxterminal() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/lxterminal/$theme.conf"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Extract color settings from theme file
    local colors=$(grep "^color_" "$theme_file")
    
    # Update config file
    if grep -q "\\[general\\]" "$config"; then
        # Config already has general section
        local temp_file=$(mktemp)
        awk -v colors="$colors" '
            BEGIN { in_general = 0; }
            /^\[general\]/ { in_general = 1; print; next; }
            in_general && /^color_/ { next; }
            in_general && /^\[/ { 
                print "# Theme: '"$theme"' (Applied by Themoty)";
                print colors;
                in_general = 0;
                print;
                next;
            }
            in_general && /^$/ && !printed {
                print "# Theme: '"$theme"' (Applied by Themoty)";
                print colors;
                printed = 1;
                print;
                next;
            }
            { print; }
            END {
                if (in_general && !printed) {
                    print "# Theme: '"$theme"' (Applied by Themoty)";
                    print colors;
                }
            }
        ' "$config" > "$temp_file"
        mv "$temp_file" "$config"
    else
        # No general section, add one
        echo -e "\n[general]" >> "$config"
        echo "# Theme: $theme (Applied by Themoty)" >> "$config"
        echo "$colors" >> "$config"
    fi
    
    log "SUCCESS" "Applied $theme to LXTerminal."
    return 0
}

# Apply theme to Termux
apply_theme_termux() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/termux/$theme.properties"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Copy the theme file directly
    cp "$theme_file" "$config"
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Applied $theme to Termux."
        return 0
    else
        log "ERROR" "Failed to apply theme to Termux."
        return 1
    fi
}

# Apply theme to GNOME Terminal
apply_theme_gnome_terminal() {
    local theme="$1"
    local theme_file="$THEMES_DIR/dynamic-colors/$theme"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    log "INFO" "Applying $theme to GNOME Terminal"
    
    # GNOME Terminal uses dconf, so we need a different approach
    local profile_ids=($(dconf list /org/gnome/terminal/legacy/profiles:/ | grep ^: | sed 's/\///g' | sed 's/://g'))
    
    if [[ ${#profile_ids[@]} -eq 0 ]]; then
        log "ERROR" "No GNOME Terminal profiles found"
        return 1
    fi
    
    # Ask user which profile to modify if multiple exist
    local profile_id=""
    if [[ ${#profile_ids[@]} -gt 1 ]]; then
        local profile_names=()
        for id in "${profile_ids[@]}"; do
            local name=$(dconf read "/org/gnome/terminal/legacy/profiles:/:$id/visible-name")
            name=${name//\'/}  # Remove single quotes
            profile_names+=("$name ($id)")
        done
        
        echo -e "${C_CYAN}Multiple GNOME Terminal profiles found. Select one:${C_RESET}"
        
        if command -v gum &> /dev/null; then
            local choice=$(gum choose --height=10 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${profile_names[@]}")
            profile_id=$(echo "$choice" | sed 's/.*(\(.*\))/\1/')
        else
            select choice in "${profile_names[@]}"; do
                [[ -n "$choice" ]] && profile_id=$(echo "$choice" | sed 's/.*(\(.*\))/\1/')
                break
            done
        fi
    else
        profile_id="${profile_ids[0]}"
    fi
    
    # Parse the colors from the theme file
    local foreground=$(grep -m 1 "^foreground" "$theme_file" | cut -d' ' -f2)
    local background=$(grep -m 1 "^background" "$theme_file" | cut -d' ' -f2)
    local cursor=$(grep -m 1 "^cursor" "$theme_file" | cut -d' ' -f2)
    
    # Create a palette string from the colors
    local palette="["
    for i in {0..15}; do
        local color=$(grep -m 1 "^color$i" "$theme_file" | cut -d' ' -f2)
        if [[ -n "$color" ]]; then
            palette+="'$color', "
        fi
    done
    palette="${palette%, }]"
    
    # Backup current settings
    local profile_path="/org/gnome/terminal/legacy/profiles:/:$profile_id"
    local backup_dir="$CONFIG_DIR/gnome-terminal-backup"
    mkdir -p "$backup_dir"
    dconf dump "$profile_path/" > "$backup_dir/profile-$profile_id.dconf"
    
    # Apply the theme
    if [[ -n "$foreground" ]]; then
        dconf write "$profile_path/foreground-color" "'$foreground'"
    fi
    if [[ -n "$background" ]]; then
        dconf write "$profile_path/background-color" "'$background'"
    fi
    if [[ -n "$cursor" ]]; then
        dconf write "$profile_path/cursor-color" "'$cursor'"
    fi
    if [[ "$palette" != "[]" ]]; then
        dconf write "$profile_path/palette" "$palette"
    fi
    
    # Set use-theme-colors to false to use our custom colors
    dconf write "$profile_path/use-theme-colors" "false"
    
    log "SUCCESS" "Applied $theme to GNOME Terminal profile"
    return 0
}

# Apply theme to Tilix
apply_theme_tilix() {
    local config_dir="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/tilix/$theme.json"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    # Ensure the directory exists
    mkdir -p "$config_dir"
    
    # Copy the theme file to the tilix schemes directory
    cp "$theme_file" "$config_dir/"
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Installed $theme for Tilix in $config_dir"
        
        # If dconf is available, try to set it as the default
        if command -v dconf &> /dev/null; then
            # Get the list of profiles
            local profile_ids=($(dconf list /com/gexperts/Tilix/profiles/ | grep ^: | sed 's/\///g' | sed 's/://g'))
            
            if [[ ${#profile_ids[@]} -gt 0 ]]; then
                local profile_id=""
                
                # Ask user which profile to modify if multiple exist
                if [[ ${#profile_ids[@]} -gt 1 ]]; then
                    local profile_names=()
                    for id in "${profile_ids[@]}"; do
                        local name=$(dconf read "/com/gexperts/Tilix/profiles/$id/visible-name")
                        name=${name//\'/}  # Remove single quotes
                        profile_names+=("$name ($id)")
                    done
                    
                    echo -e "${C_CYAN}Multiple Tilix profiles found. Select one:${C_RESET}"
                    
                    if command -v gum &> /dev/null; then
                        local choice=$(gum choose --height=10 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${profile_names[@]}")
                        profile_id=$(echo "$choice" | sed 's/.*(\(.*\))/\1/')
                    else
                        select choice in "${profile_names[@]}"; do
                            [[ -n "$choice" ]] && profile_id=$(echo "$choice" | sed 's/.*(\(.*\))/\1/')
                            break
                        done
                    fi
                else
                    profile_id="${profile_ids[0]}"
                fi
                
                # Set the color scheme for the selected profile
                dconf write "/com/gexperts/Tilix/profiles/$profile_id/color-scheme" "'$theme'"
                
                log "INFO" "Set $theme as the default color scheme for Tilix profile"
            else
                log "WARN" "No Tilix profiles found in dconf. You may need to set the theme manually."
            fi
        else
            log "WARN" "dconf not found. You may need to set the theme manually in Tilix preferences."
        fi
        
        return 0
    else
        log "ERROR" "Failed to install theme for Tilix."
        return 1
    fi
}

# Apply theme to VSCode integrated terminal
apply_theme_vscode() {
    local config="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/schemes/$theme.itermcolors"
    
    if [[ ! -f "$theme_file" ]]; then
        log "ERROR" "Theme file not found: $theme_file"
        return 1
    fi
    
    backup_config "$config"
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq is required for modifying VSCode settings. Please install jq."
        return 1
    fi
    
    # Extract colors from iTerm theme
    local foreground=$(grep -A1 "<key>Foreground Color</key>" "$theme_file" | grep -o "<real>[0-9.]*</real>" | sed -n '1p' | grep -o "[0-9.]*")
    local background=$(grep -A1 "<key>Background Color</key>" "$theme_file" | grep -o "<real>[0-9.]*</real>" | sed -n '1p' | grep -o "[0-9.]*")
    
    # Simple RGB extraction from iTerm2 color scheme
    local fg_r=$(grep -A2 "<key>Foreground Color</key>" "$theme_file" | grep -A1 "<key>Red Component</key>" | grep -o "<real>[0-9.]*</real>" | grep -o "[0-9.]*")
    local fg_g=$(grep -A2 "<key>Foreground Color</key>" "$theme_file" | grep -A1 "<key>Green Component</key>" | grep -o "<real>[0-9.]*</real>" | grep -o "[0-9.]*")
    local fg_b=$(grep -A2 "<key>Foreground Color</key>" "$theme_file" | grep -A1 "<key>Blue Component</key>" | grep -o "<real>[0-9.]*</real>" | grep -o "[0-9.]*")
    
    local bg_r=$(grep -A2 "<key>Background Color</key>" "$theme_file" | grep -A1 "<key>Red Component</key>" | grep -o "<real>[0-9.]*</real>" | grep -o "[0-9.]*")
    local bg_g=$(grep -A2 "<key>Background Color</key>" "$theme_file" | grep -A1 "<key>Green Component</key>" | grep -o "<real>[0-9.]*</real>" | grep -o "[0-9.]*")
    local bg_b=$(grep -A2 "<key>Background Color</key>" "$theme_file" | grep -A1 "<key>Blue Component</key>" | grep -o "<real>[0-9.]*</real>" | grep -o "[0-9.]*")
    
    # Convert to hex format for VSCode
    local fg_hex=$(printf "#%02X%02X%02X" $(echo "$fg_r * 255" | bc | cut -d. -f1) $(echo "$fg_g * 255" | bc | cut -d. -f1) $(echo "$fg_b * 255" | bc | cut -d. -f1))
    local bg_hex=$(printf "#%02X%02X%02X" $(echo "$bg_r * 255" | bc | cut -d. -f1) $(echo "$bg_g * 255" | bc | cut -d. -f1) $(echo "$bg_b * 255" | bc | cut -d. -f1))
    
    # Check if settings.json exists and is valid JSON
    if [[ ! -f "$config" ]]; then
        # Create a new settings file
        mkdir -p "$(dirname "$config")"
        echo "{}" > "$config"
    fi
    
    # Use jq to modify the settings file
    local temp_file=$(mktemp)
    jq --arg fg "$fg_hex" --arg bg "$bg_hex" '.["terminal.integrated.foreground"] = $fg | .["terminal.integrated.background"] = $bg' "$config" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$config"
        log "SUCCESS" "Applied $theme colors to VSCode integrated terminal"
        log "INFO" "You may need to restart VSCode for changes to take effect"
        return 0
    else
        log "ERROR" "Failed to update VSCode settings"
        rm "$temp_file"
        return 1
    fi
}

# Apply a theme to a specific terminal
apply_theme() {
    local terminal="$1"
    local theme="$2"
    
    log "INFO" "Applying $theme to $terminal"
    
    # Save preferences for future use
    save_preferences "$terminal" "$theme"
    
    # Find the config file
    local config=$(find_terminal_config "$terminal")
    
    if [[ -z "$config" ]]; then
        log "ERROR" "Could not find configuration for $terminal"
        return 1
    fi
    
    # Apply theme based on terminal type
    case "$terminal" in
        "alacritty") apply_theme_alacritty "$config" "$theme" ;;
        "kitty") apply_theme_kitty "$config" "$theme" ;;
        "konsole") apply_theme_konsole "$config" "$theme" ;;
        "xfce4-terminal") apply_theme_xfce4_terminal "$config" "$theme" ;;
        "terminator") apply_theme_terminator "$config" "$theme" ;;
        "foot") apply_theme_foot "$config" "$theme" ;;
        "wezterm") apply_theme_wezterm "$config" "$theme" ;;
        "rio") apply_theme_rio "$config" "$theme" ;;
        "xresources") apply_theme_xresources "$config" "$theme" ;;
        "ghostty") apply_theme_ghostty "$config" "$theme" ;;
        "lxterminal") apply_theme_lxterminal "$config" "$theme" ;;
        "termux") apply_theme_termux "$config" "$theme" ;;
        "gnome-terminal") apply_theme_gnome_terminal "$theme" ;;
        "tilix") apply_theme_tilix "$config" "$theme" ;;
        "vscode") apply_theme_vscode "$config" "$theme" ;;
        *) 
            log "ERROR" "Applying themes to $terminal is not yet implemented"
            return 1
            ;;
    esac
    
    return $?
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUI FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Display splash screen
show_splash() {
    clear
    
    echo -e "${C_PURPLE}"
    cat << "EOF"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    echo -e "${C_PINK}"
    cat << "EOF"
  _______   _                                  _          
 |__   __| | |                                | |         
    | |    | |__     ___   _ __ ___     ___   | |_   _    
    | |    | '_ \   / _ \ | '_ ` _ \   / _ \  | __| | |   
    | |    | | | | |  __/ | | | | | | | (_) | | |_  | |   
    |_|    |_| |_|  \___| |_| |_| |_|  \___/   \__| |_|   
EOF
    
    echo -e "${C_BLUE}"
    cat << "EOF"
         Terminal Theme Manager (iTerm2-Color-Schemes for Linux)
EOF
    
    echo -e "${C_CYAN}"
    cat << "EOF"
                      ⚡ Synthwave Edition ⚡
EOF
    
    echo -e "${C_PURPLE}"
    cat << "EOF"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    echo -e "${C_RESET}"
    echo -e "${C_CYAN}Version:${C_RESET} $VERSION"
    echo -e "${C_CYAN}iTerm2-Color-Schemes:${C_RESET} ${THEMES_DIR}"
    echo
    
    # Sleep for a moment to show the splash
    sleep 1
}

# Display main menu
show_main_menu() {
    local options=(
        "Apply Theme"
        "Import Theme Settings"
        "Manage Installation"
        "Help"
        "Exit"
    )
    
    if command -v gum &> /dev/null; then
        local choice=$(gum choose --height=10 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${options[@]}")
    else
        echo "Select an option:"
        select choice in "${options[@]}"; do
            [[ -n "$choice" ]] && break
        done
    fi
    
    case "$choice" in
        "Apply Theme") show_terminal_selection ;;
        "Import Theme Settings") show_import_menu ;;
        "Manage Installation") show_manage_menu ;;
        "Help") show_help ;;
        "Exit") exit 0 ;;
        *) show_main_menu ;;
    esac
}

# Show import menu
show_import_menu() {
    echo -e "${C_CYAN}Import theme settings:${C_RESET}"
    echo -e "1. Import from default location ($CONFIG_DIR/theme_export.json)"
    echo -e "2. Specify import file"
    echo -e "3. Back to main menu"
    
    local choice
    read -r choice
    
    case "$choice" in
        1)
            import_theme_settings
            ;;
        2)
            echo -e "${C_CYAN}Enter path to import file:${C_RESET}"
            local import_file
            read -r import_file
            import_theme_settings "$import_file"
            ;;
        3)
            show_main_menu
            return
            ;;
        *)
            show_import_menu
            ;;
    esac
    
    read -p "Press Enter to return to the main menu..."
    show_main_menu
}

# Display terminal selection menu
show_terminal_selection() {
    local installed_terminals=($(detect_terminals))
    
    if [[ ${#installed_terminals[@]} -eq 0 ]]; then
        log "ERROR" "No supported terminals detected on your system."
        read -p "Press Enter to return to the main menu..."
        show_main_menu
        return
    fi
    
    echo -e "${C_CYAN}Select a terminal to apply a theme:${C_RESET}"
    
    if command -v gum &> /dev/null; then
        local choice=$(gum choose --height=15 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${installed_terminals[@]}" "Back")
    else
        select choice in "${installed_terminals[@]}" "Back"; do
            [[ -n "$choice" ]] && break
        done
    fi
    
    if [[ "$choice" == "Back" ]]; then
        show_main_menu
    else
        show_theme_selection "$choice"
    fi
}

# Display theme selection menu - enhanced version with preview and search
show_theme_selection() {
    local terminal="$1"
    local available_themes=($(get_available_themes "$terminal"))
    
    if [[ ${#available_themes[@]} -eq 0 ]]; then
        log "ERROR" "No themes found for $terminal."
        read -p "Press Enter to return to the terminal selection..."
        show_terminal_selection
        return
    fi
    
    local options=(
        "Search Themes"
        "Apply Random Theme" 
        "List All Themes"
        "Back"
    )
    
    echo -e "${C_CYAN}$terminal theme options:${C_RESET}"
    
    if command -v gum &> /dev/null; then
        local choice=$(gum choose --height=10 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${options[@]}")
    else
        select choice in "${options[@]}"; do
            [[ -n "$choice" ]] && break
        done
    fi
    
    case "$choice" in
        "Search Themes")
            if command -v gum &> /dev/null; then
                echo -e "${C_CYAN}Enter search term:${C_RESET}"
                local search_term=$(gum input --placeholder "e.g. dark, light, blue, etc.")
                
                if [[ -n "$search_term" ]]; then
                    local matching_themes=($(search_themes "$terminal" "$search_term"))
                    
                    if [[ ${#matching_themes[@]} -eq 0 ]]; then
                        log "INFO" "No themes found matching '$search_term'"
                        show_theme_selection "$terminal"
                        return
                    fi
                    
                    echo -e "${C_CYAN}Select a theme to apply:${C_RESET}"
                    local theme=$(gum choose --height=20 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${matching_themes[@]}" "Back")
                    
                    if [[ "$theme" == "Back" ]]; then
                        show_theme_selection "$terminal"
                        return
                    fi
                else
                    show_theme_selection "$terminal"
                    return
                fi
            else
                echo -e "${C_CYAN}Enter search term:${C_RESET}"
                local search_term
                read -r search_term
                
                if [[ -n "$search_term" ]]; then
                    local matching_themes=($(search_themes "$terminal" "$search_term"))
                    
                    if [[ ${#matching_themes[@]} -eq 0 ]]; then
                        log "INFO" "No themes found matching '$search_term'"
                        show_theme_selection "$terminal"
                        return
                    fi
                    
                    echo -e "${C_CYAN}Select a theme to apply:${C_RESET}"
                    select theme in "${matching_themes[@]}" "Back"; do
                        [[ -n "$theme" ]] && break
                    done
                    
                    if [[ "$theme" == "Back" ]]; then
                        show_theme_selection "$terminal"
                        return
                    fi
                else
                    show_theme_selection "$terminal"
                    return
                fi
            fi
            ;;
        "Apply Random Theme")
            apply_random_theme "$terminal"
            if confirm "Would you like to apply another theme?"; then
                show_theme_selection "$terminal"
            else
                show_main_menu
            fi
            return
            ;;
        "List All Themes")
            if command -v gum &> /dev/null; then
                local theme=$(gum filter --height=20 --prompt.foreground="#ff88ff" --match.foreground="#ff88ff" --cursor.foreground="#ff88ff" --indicator.foreground="#ff88ff" --selected.foreground="#ff88ff" < <(printf "%s\n" "${available_themes[@]}" "Back"))
            else
                echo -e "${C_CYAN}Select a theme to apply:${C_RESET}"
                select theme in "${available_themes[@]}" "Back"; do
                    [[ -n "$theme" ]] && break
                done
            fi
            
            if [[ "$theme" == "Back" ]]; then
                show_theme_selection "$terminal"
                return
            fi
            ;;
        "Back")
            show_terminal_selection
            return
            ;;
        *)
            show_theme_selection "$terminal"
            return
            ;;
    esac
    
    # Show theme preview before applying
    if confirm "Would you like to preview the theme before applying?"; then
        preview_theme "$terminal" "$theme"
        
        # Confirm after preview
        if ! confirm "Do you want to apply this theme?"; then
            show_theme_selection "$terminal"
            return
        fi
    fi
    
    apply_theme "$terminal" "$theme"
    
    # Ask if the user wants to export the theme settings
    if confirm "Would you like to export these theme settings for later use?"; then
        export_theme_settings "$terminal" "$theme"
    fi
    
    if confirm "Would you like to apply another theme?"; then
        show_theme_selection "$terminal"
    else
        show_main_menu
    fi
}

# Display management menu
show_manage_menu() {
    local options=(
        "Install Themoty"
        "Update Themoty"
        "Uninstall Themoty"
        "Update iTerm2-Color-Schemes"
        "Back"
    )
    
    echo -e "${C_CYAN}Select a management option:${C_RESET}"
    
    if command -v gum &> /dev/null; then
        local choice=$(gum choose --height=10 --cursor.foreground="#ff88ff" --selected.foreground="#ff88ff" "${options[@]}")
    else
        select choice in "${options[@]}"; do
            [[ -n "$choice" ]] && break
        done
    fi
    
    case "$choice" in
        "Install Themoty") install_script ;;
        "Update Themoty") update_script ;;
        "Uninstall Themoty") remove_script ;;
        "Update iTerm2-Color-Schemes") 
            if [[ -d "$THEMES_DIR" && -d "$THEMES_DIR/.git" ]]; then
                log "INFO" "Updating iTerm2-Color-Schemes repository"
                (cd "$THEMES_DIR" && git pull)
                if [[ $? -eq 0 ]]; then
                    log "SUCCESS" "iTerm2-Color-Schemes repository updated successfully."
                else
                    log "ERROR" "Failed to update iTerm2-Color-Schemes repository."
                fi
            else
                log "INFO" "Cloning iTerm2-Color-Schemes repository"
                git clone "$THEMES_REPO" "$THEMES_DIR"
            fi
            ;;
        "Back") show_main_menu; return ;;
    esac
    
    read -p "Press Enter to return to the management menu..."
    show_manage_menu
}

# Display help information
show_help() {
    if command -v glow &> /dev/null; then
        # Create a temporary markdown file
        local temp_md=$(mktemp)
        
        cat > "$temp_md" << EOF
# Themoty Help

## Overview
Themoty is a terminal theme manager that allows you to apply iTerm2 color schemes to various terminal emulators on Linux.

## Usage
- \`themoty\`: Launch the TUI
- \`themoty install\`: Install Themoty to your system
- \`themoty update\`: Update Themoty and the color schemes
- \`themoty remove\`: Uninstall Themoty

## Features
- Apply themes to various terminal emulators
- Search and filter themes by name
- Preview themes before applying
- Export and import theme settings
- Apply random themes for discovery
- Backup and restore terminal configs

## Supported Terminals
$(printf "- %s\n" "${SUPPORTED_TERMINALS[@]}")

## Credits
- iTerm2-Color-Schemes: [https://github.com/mbadolato/iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)
- Themoty: [https://github.com/eraxe/themoty](https://github.com/eraxe/themoty)
EOF
        
        glow "$temp_md"
        rm "$temp_md"
    else
        print_header "Themoty Help"
        echo -e "${C_CYAN}Usage:${C_RESET}"
        echo "  themoty             Launch the TUI"
        echo "  themoty install     Install Themoty to your system"
        echo "  themoty update      Update Themoty and the color schemes"
        echo "  themoty remove      Uninstall Themoty"
        echo
        echo -e "${C_CYAN}Features:${C_RESET}"
        echo "  - Apply themes to various terminal emulators"
        echo "  - Search and filter themes by name"
        echo "  - Preview themes before applying"
        echo "  - Export and import theme settings"
        echo "  - Apply random themes for discovery"
        echo "  - Backup and restore terminal configs"
        echo
        echo -e "${C_CYAN}Supported Terminals:${C_RESET}"
        for terminal in "${SUPPORTED_TERMINALS[@]}"; do
            echo "  - $terminal"
        done
        echo
        echo -e "${C_CYAN}Credits:${C_RESET}"
        echo "  iTerm2-Color-Schemes: https://github.com/mbadolato/iTerm2-Color-Schemes"
        echo "  Themoty: https://github.com/eraxe/themoty"
    fi
    
    read -p "Press Enter to return to the main menu..."
    show_main_menu
}

# Start the TUI
start_tui() {
    # Load configuration and preferences
    load_config
    load_preferences
    
    # Check dependencies
    check_dependencies
    
    # Show splash screen
    show_splash
    
    # Show main menu
    show_main_menu
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Process command-line arguments
if [[ $# -eq 0 ]]; then
    # No arguments, start TUI
    start_tui
else
    # Parse arguments
    case "$1" in
        "install")
            install_script
            ;;
        "update")
            update_script
            ;;
        "remove"|"uninstall")
            remove_script
            ;;
        "help")
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            echo "Usage: $SCRIPT_NAME [install|update|remove|help]"
            exit 1
            ;;
    esac
fi

exit 0
