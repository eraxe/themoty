#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THEMOTY - Terminal Theme Manager
# A comprehensive CLI/TUI tool for managing terminal themes using iTerm2-Color-Schemes
# Author: eraxe
# GitHub: https://github.com/eraxe/themoty
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -o pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GLOBAL VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERSION="0.1.0"
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

# Find a terminal config file
find_terminal_config() {
    local terminal=$1
    local config_paths=${TERMINAL_CONFIGS[$terminal]}
    local found_config=""
    
    # If config paths contain colons, try each one
    if [[ $config_paths == *":"* ]]; then
        IFS=':' read -ra paths <<< "$config_paths"
        for path in "${paths[@]}"; do
            if [[ -f "$path" || -d "$path" ]]; then
                found_config="$path"
                break
            fi
        done
    else
        if [[ -f "$config_paths" || -d "$config_paths" ]]; then
            found_config="$config_paths"
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

# Apply a theme to a specific terminal
apply_theme() {
    local terminal="$1"
    local theme="$2"
    
    log "INFO" "Applying $theme to $terminal"
    
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
        "Manage Installation") show_manage_menu ;;
        "Help") show_help ;;
        "Exit") exit 0 ;;
        *) show_main_menu ;;
    esac
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

# Display theme selection menu
show_theme_selection() {
    local terminal="$1"
    local available_themes=($(get_available_themes "$terminal"))
    
    if [[ ${#available_themes[@]} -eq 0 ]]; then
        log "ERROR" "No themes found for $terminal."
        read -p "Press Enter to return to the terminal selection..."
        show_terminal_selection
        return
    fi
    
    echo -e "${C_CYAN}Select a theme to apply to $terminal:${C_RESET}"
    
    if command -v gum &> /dev/null; then
        local choice=$(gum filter --height=20 --prompt.foreground="#ff88ff" --match.foreground="#ff88ff" --cursor.foreground="#ff88ff" --indicator.foreground="#ff88ff" --selected.foreground="#ff88ff" < <(printf "%s\n" "${available_themes[@]}" "Back"))
    else
        select choice in "${available_themes[@]}" "Back"; do
            [[ -n "$choice" ]] && break
        done
    fi
    
    if [[ "$choice" == "Back" ]]; then
        show_terminal_selection
    else
        apply_theme "$terminal" "$choice"
        
        if confirm "Would you like to apply another theme?"; then
            show_terminal_selection
        else
            show_main_menu
        fi
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
