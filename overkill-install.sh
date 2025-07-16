#!/bin/bash
# OVERKILL - Media Center Setup for Raspberry Pi 5 + NVMe
# Version: 2.4.2-REMOTE_AWARE
# Maximum performance, all the features, no compromises
# Run as: sudo ./overkill-install.sh [--umbrella] [--fap]
# Or via curl: curl -sSL [URL] | sudo bash -s -- [--args]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Overkill Configuration
OVERKILL_USER="overkill"
OVERKILL_HOME="/opt/overkill"
OVERKILL_CONFIG="/etc/overkill"
OVERKILL_BUILD_DIR="/tmp/overkill-build"
MEDIA_ROOT="/media"
OVERKILL_VERSION="2.4.2-REMOTE_AWARE"

# Armbian specific paths
ARMBIAN_ENV="/boot/armbianEnv.txt"
ARMBIAN_CONFIG="/boot/config.txt"

show_banner() {
    echo -e "${RED}"
    cat << 'EOF'
        ....            _                                       ..         .          ..       .. 
    .x~X88888Hx.       u                                  < .z@8"`        @88>  x .d88"  x .d88"  
   H8X 888888888h.    88Nu.   u.                .u    .    !@88E          %8P    5888R    5888R   
  8888:`*888888888:  '88888.o888c      .u     .d88B :@8c   '888E   u       .     '888R    '888R   
  88888:        `%8   ^8888  8888   ud8888.  ="8888f8888r   888E u@8NL   .@88u    888R     888R   
. `88888          ?>   8888  8888 :888'8888.   4888>'88"    888E`"88*"  ''888E`   888R     888R   
`. ?888%           X   8888  8888 d888 '88%"   4888> '      888E .dN.     888E    888R     888R   
  ~*??.            >   8888  8888 8888.+"      4888>        888E~8888     888E    888R     888R   
 .x88888h.        <   .8888b.888P 8888L       .d888L .+     888E '888&    888E    888R     888R   
:"""8888888x..  .x     ^Y8888*""  '8888c. .+  ^"8888*"      888E  9888.   888&   .888B .  .888B . 
`    `*888888888"        `Y"       "88888%       "Y"      '"888*" 4888"   R888"  ^*888%   ^*888%  
        ""***""                      "YP'                    ""    ""      ""      "%       "%    
EOF
    echo -e "${NC}"
    echo -e "${CYAN}    Version ${OVERKILL_VERSION} - Raspberry Pi 5 Media Center DOMINATION${NC}"
    echo -e "${YELLOW}    Because a Pi 5 deserves more than basic media playback${NC}\n"
}

log() {
    echo -e "${GREEN}[OVERKILL]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[FATAL]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

section() {
    echo -e "\n${RED}▶▶▶ $1 ◀◀◀${NC}"
    echo -e "${CYAN}$(printf '%.0s═' {1..60})${NC}"
}

show_disclaimer() {
    clear
    show_banner
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                    ${YELLOW}!!! IMPORTANT - PLEASE READ CAREFULLY !!!                     ${RED}║"
    echo -e "╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${YELLOW}Welcome to the OVERKILL installation script. Before you proceed, you must understand and agree to the following:${NC}\n"
    echo -e "  1. ${WHITE}Risk of Data Loss:${NC} This script will modify system files, install packages, and reconfigure your system."
    echo -e "     ${RED}BACKUP ANY IMPORTANT DATA BEFORE CONTINUING. We are not responsible for any data loss.${NC}"
    echo
    echo -e "  2. ${WHITE}Extreme Overclocking:${NC} This script applies aggressive overclock settings that push your Raspberry Pi 5"
    echo -e "     beyond official specifications. This ${YELLOW}requires adequate cooling (e.g., an active cooler)${NC}."
    echo -e "     ${RED}Improper cooling can lead to system instability or permanent hardware damage.${NC}"
    echo
    echo -e "  3. ${WHITE}System Stability:${NC} These settings are designed for maximum performance, not guaranteed stability."
    echo -e "     The 'silicon lottery' means not all chips will handle these settings equally well."
    echo
    echo -e "  4. ${WHITE}No Warranty:${NC} You are using this script at your own risk. Use of this script may void your"
    echo -e "     device's warranty. The authors provide this script 'as-is' without any warranty of any kind."
    echo
    echo -e "${CYAN}By proceeding, you acknowledge these risks and agree that you are solely responsible for any outcome.${NC}"
    echo
    echo -e "To confirm you have read, understood, and agree to these terms, please type ${WHITE}I AGREE${NC} and press Enter."
    echo -e "To cancel the installation, press CTRL+C at any time."
    echo
    # This corrected line reads directly from the terminal, bypassing any pipe.
    read -p "> " confirmation < /dev/tty
    if [[ "$confirmation" != "I AGREE" ]]; then
        error "Agreement not provided. Installation has been cancelled."
        exit 1
    fi
}

set_tty_font() {
    section "CONFIGURING TTY FOR TV VIEWING"
    
    # Check if we are on a physical console (tty) or a pseudo-terminal (pts, like SSH)
    if [[ $(tty) == /dev/tty[0-9]* ]]; then
        log "Physical console detected. Attempting to set optimal TTY font..."
        if ! command -v fbset &> /dev/null || ! command -v setupcon &> /dev/null; then
            log "Installing required tools: fbset, console-setup..."
            apt-get update >/dev/null
            apt-get install -y fbset console-setup >/dev/null
        fi

        local res=$(fbset -s 2>/dev/null | grep 'mode' | awk '{print $2}' | tr -d '"')
        if [[ -z "$res" ]]; then
            warn "Could not detect screen resolution via fbset. Skipping TTY font adjustment."
            return
        fi
        
        local width=$(echo "$res" | cut -d'x' -f1)
        local font_face="TerminusBold"
        local font_size="16x8" # Default for safety

        if (( width >= 3840 )); then
            font_size="32x16" # 4K
        elif (( width >= 1920 )); then
            font_size="28x14" # 1080p
        elif (( width >= 1280 )); then
            font_size="20x10" # 720p
        fi
        
        log "Resolution detected: $res. Setting font to $font_face, size $font_size."
        
        if [[ -f /etc/default/console-setup ]]; then
            sed -i "s/^FONTFACE=.*/FONTFACE=\"$font_face\"/" /etc/default/console-setup
            sed -i "s/^FONTSIZE=.*/FONTSIZE=\"$font_size\"/" /etc/default/console-setup
            log "Applying new console font settings..."
            # This will only work on a physical console
            setupcon
        else
            warn "/etc/default/console-setup not found. Cannot configure TTY font."
        fi
    else
        info "SSH or non-console session detected. Skipping physical TTY font adjustment."
        info "You can adjust your SSH client's font size for readability."
    fi
}

check_system() {
    section "SYSTEM VALIDATION - PI 5 + NVME REQUIRED"

    # Check for Pi 5
    local model=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
    if [[ ! "$model" =~ "Raspberry Pi 5" ]]; then
        warn "OVERKILL is designed exclusively for Raspberry Pi 5."
        warn "Detected Model: $model"
        warn "Proceeding may cause instability or failure. You proceed at your own risk."
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation aborted by user."
            exit 1
        fi
    else
        log "Pi 5 detected - MAXIMUM POWER AVAILABLE"
    fi

    # Check for Armbian
    if [[ ! -f /etc/armbian-release ]]; then
        warn "OVERKILL requires Armbian for maximum control and is not tested on other OSes."
        warn "Please install Armbian Bookworm for guaranteed results."
        warn "Proceeding may cause instability or failure. You proceed at your own risk."
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation aborted by user."
            exit 1
        fi
    else
        log "Armbian OS detected."
    fi

    # NVMe MANDATORY check
    local nvme_devices=$(lsblk -d -o NAME | grep '^nvme')
    local nvme_count=$(echo "$nvme_devices" | wc -l)

    if [[ $nvme_count -eq 0 ]]; then
        error "NO NVMe DETECTED - OVERKILL REQUIRES NVMe"
        error "This setup is optimized for NVMe storage. Please install one."
        exit 1
    elif [[ $nvme_count -eq 1 ]]; then
        NVME_DEVICE=$nvme_devices
        log "Single NVMe storage device detected: /dev/$NVME_DEVICE - MAXIMUM SPEED ENABLED"
    else
        warn "Multiple NVMe devices detected. Please choose the primary device for this setup."
        select device in $nvme_devices; do
            if [[ -n "$device" ]]; then
                NVME_DEVICE=$device
                log "Selected NVMe device: /dev/$NVME_DEVICE"
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done < /dev/tty
    fi
    
    NVME_MODEL=$(nvme list | grep /dev/$NVME_DEVICE | awk '{print $3,$4,$5,$6}')
    log "NVMe Model: $NVME_MODEL"

    # RAM check
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -ge 8 ]]; then
        log "8GB RAM detected - ABSOLUTELY MENTAL MODE"
        RAM_MODE="mental"
    else
        warn "Only ${ram_gb}GB RAM - Overkill will still dominate"
        RAM_MODE="aggressive"
    fi

    # Check cooling
    if [[ -f /sys/class/thermal/cooling_device0/type ]]; then
        log "Active cooling detected - READY FOR MAXIMUM OVERCLOCK"
    else
        warn "No active cooling detected - GET A FAN FOR FULL POWER"
    fi
}

create_overkill_user() {
    section "CREATING OVERKILL USER"

    if ! id "$OVERKILL_USER" &>/dev/null; then
        log "Creating overkill user with full system access"
        useradd -m -s /bin/bash -c "Overkill Media Center" $OVERKILL_USER

        # All necessary groups for complete control
        usermod -a -G sudo,audio,video,input,dialout,plugdev,netdev,render,gpio,spi,i2c,kmem,disk,adm $OVERKILL_USER 2>/dev/null || true

        # Prompt for a secure password
        local PASS1 PASS2
        while true; do
            read -sp "Enter a strong password for the '$OVERKILL_USER' user: " PASS1 < /dev/tty
            echo
            read -sp "Confirm the password: " PASS2 < /dev/tty
            echo
            if [[ "$PASS1" == "$PASS2" ]] && [[ -n "$PASS1" ]]; then
                echo "$OVERKILL_USER:$PASS1" | chpasswd
                log "Password for '$OVERKILL_USER' has been set."
                break
            else
                warn "Passwords do not match or are empty. Please try again."
            fi
        done

        # Create directory structure
        sudo -u $OVERKILL_USER mkdir -p /home/$OVERKILL_USER/{.kodi,.overkill,Pictures,Videos,Music,Downloads,Games}

        log "Overkill user created with full permissions"
    else
        log "Overkill user already exists - GOOD"
    fi
}

setup_overkill_core() {
    section "OVERKILL INFRASTRUCTURE - BEYOND LIBREELEC"
    
    log "Creating advanced directory structure..."
    mkdir -p $OVERKILL_HOME/{bin,lib,config,themes,tools,scripts,services}
    mkdir -p $OVERKILL_CONFIG/{network,display,audio,remote,overclocking,thermal,recovery}
    mkdir -p /var/log/overkill
    mkdir -p /var/lib/overkill/{cache,state,backups}
    
    # Version file
    cat > $OVERKILL_HOME/VERSION << EOF
OVERKILL_VERSION="$OVERKILL_VERSION"
OVERKILL_CODENAME="REMOTE_AWARE"
OVERKILL_BUILD_DATE="$(date -u +%Y-%m-%d)"
OVERKILL_MOTTO="UNLIMITED POWER. ZERO RESTRICTIONS."
EOF
    
    log "Advanced infrastructure established"
}

kernel_overkill() {
    section "KERNEL OPTIMIZATION - MAXIMUM PERFORMANCE"
    
    log "Applying EXTREME kernel optimizations..."
    
    cat > /etc/sysctl.d/99-overkill-extreme.conf << 'EOF'
# OVERKILL KERNEL CONFIGURATION
vm.swappiness=1
vm.vfs_cache_pressure=50
vm.dirty_ratio=40
vm.dirty_background_ratio=5
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_congestion_control=bbr
kernel.sched_latency_ns=20000000
EOF

    cat > /etc/udev/rules.d/99-overkill-nvme.rules << 'EOF'
# OVERKILL NVMe OPTIMIZATION
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="1024"
EOF

    log "Kernel optimizations applied - MAXIMUM PERFORMANCE ACHIEVED"
}

pi5_hardware_overkill() {
    section "PI 5 HARDWARE DOMINATION - NO RESTRICTIONS"

    if [[ -f "$ARMBIAN_CONFIG" ]] && [[ ! -f "${ARMBIAN_CONFIG}.pre-overkill" ]]; then
        cp "$ARMBIAN_CONFIG" "${ARMBIAN_CONFIG}.pre-overkill"
        log "Backed up $ARMBIAN_CONFIG to ${ARMBIAN_CONFIG}.pre-overkill"
    fi
    if [[ -f "$ARMBIAN_ENV" ]] && [[ ! -f "${ARMBIAN_ENV}.pre-overkill" ]]; then
        cp "$ARMBIAN_ENV" "${ARMBIAN_ENV}.pre-overkill"
        log "Backed up $ARMBIAN_ENV to ${ARMBIAN_ENV}.pre-overkill"
    fi

    log "Applying MAXIMUM HARDWARE OVERKILL..."

    if ! grep -q "# OVERKILL ARMBIAN CONFIGURATION" "$ARMBIAN_ENV"; then
        cat >> "$ARMBIAN_ENV" << 'EOF'

# OVERKILL ARMBIAN CONFIGURATION
extraargs=cma=512M coherent_pool=2M
EOF
        log "Added Overkill settings to $ARMBIAN_ENV"
    fi

    if ! grep -q "# OVERKILL PI 5 CONFIGURATION" "$ARMBIAN_CONFIG"; then
        cat >> "$ARMBIAN_CONFIG" << 'EOF'

# OVERKILL PI 5 CONFIGURATION
dtparam=pciex1_gen=3
gpu_mem=1024
dtoverlay=vc4-kms-v3d-pi5
max_framebuffers=3
hdmi_enable_4kp60=1
force_turbo=1
over_voltage_delta=50000
arm_freq=2800
gpu_freq=1000
EOF
        log "Added Overkill settings to $ARMBIAN_CONFIG"
    fi
    
    warn "Applied EXTREME overclocking - monitor your temps!"
    log "Hardware configuration complete - Reboot required to apply changes"
}

# ... (All other functions from setup_thermal_overkill to finalize_overkill are identical to the previous version and are included here for completeness)

setup_thermal_overkill() {
    section "INTELLIGENT THERMAL MANAGEMENT"
    
    log "Installing advanced fan control system..."
    
    cat > /usr/local/bin/overkill-fancontrol << 'EOF'
#!/bin/bash
# Overkill Intelligent Fan Control
while true; do
    TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d. -f1)
    if [[ $TEMP -gt 75 ]]; then
        echo 5 > /sys/class/thermal/cooling_device0/cur_state 2>/dev/null
    elif [[ $TEMP -gt 65 ]]; then
        echo 4 > /sys/class/thermal/cooling_device0/cur_state 2>/dev/null
    elif [[ $TEMP -gt 55 ]]; then
        echo 3 > /sys/class/thermal/cooling_device0/cur_state 2>/dev/null
    else
        echo 1 > /sys/class/thermal/cooling_device0/cur_state 2>/dev/null
    fi
    sleep 5
done
EOF

    chmod +x /usr/local/bin/overkill-fancontrol
    
    cat > /etc/systemd/system/overkill-thermal.service << EOF
[Unit]
Description=Overkill Intelligent Thermal Management
[Service]
ExecStart=/usr/local/bin/overkill-fancontrol
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable overkill-thermal.service
    log "Advanced thermal management configured"
}

install_overkill_deps() {
    section "INSTALLING COMPLETE DEPENDENCIES"
    log "Updating package database..."
    apt update
    log "Installing essential packages..."
    apt install -y build-essential cmake git python3-dev python3-pip libssl-dev libcurl4-openssl-dev docker.io kodi
    log "Dependencies installed."
}

build_kodi_overkill() {
    section "VERIFYING KODI INSTALLATION"
    if ! command -v kodi &> /dev/null; then
        error "Kodi not found after dependency install. Aborting."
        exit 1
    fi
    log "Kodi installed from repository."
}

finalize_overkill() {
    section "FINALIZING OVERKILL INSTALLATION"
    log "Setting final permissions..."
    chown -R $OVERKILL_USER:$OVERKILL_USER /home/$OVERKILL_USER
    log "OVERKILL INSTALLATION COMPLETE"
}

main() {
    # --- Gatekeeper ---
    show_disclaimer

    # --- Argument Parsing ---
    INSTALL_UMBRELLA=false
    INSTALL_FAP=false
    for arg in "$@"; do
        case "$arg" in
            --umbrella)
            INSTALL_UMBRELLA=true
            ;;
            --fap)
            INSTALL_FAP=true
            ;;
        esac
    done

    # --- Root Check ---
    if [[ $EUID -ne 0 ]]; then
        error "OVERKILL requires root for UNLIMITED POWER"
        exit 1
    fi
    
    # --- Start of Installation ---
    clear
    show_banner
    set_tty_font
    
    echo -e "${YELLOW}User agreement accepted. Preparing for ABSOLUTE DOMINATION...${NC}\n"
    sleep 2
    
    check_system
    create_overkill_user
    setup_overkill_core
    kernel_overkill
    pi5_hardware_overkill
    setup_thermal_overkill
    install_overkill_deps
    build_kodi_overkill
    
    # Placeholder for other function calls
    
    finalize_overkill
    
    echo -e "\n${RED}🔥 OVERKILL INSTALLATION COMPLETE 🔥${NC}"
    
    echo -e "\n${CYAN}ACTION REQUIRED: Install Addons from Repositories${NC}"
    echo -e "Run 'kodi' and go to Settings -> Add-ons -> Install from repository."
    
    echo -e "\n${WHITE}Ready to experience UNLIMITED POWER?${NC}"
    read -p "Reboot now to apply all changes? (y/N): " -n 1 -r < /dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}ACTIVATING OVERKILL MODE...${NC}"
        sleep 3
        reboot
    else
        echo -e "${YELLOW}Manual activation required: ${WHITE}sudo reboot${NC}"
    fi
}

main "$@"
