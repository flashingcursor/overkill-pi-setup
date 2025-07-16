#!/bin/bash
# OVERKILL - Media Center Setup for Raspberry Pi 5 + NVMe
# Version: 2.4.0-FINAL_AGREEMENT
# Maximum performance, all the features, no compromises
# Run as: sudo ./overkill-install.sh [--umbrella] [--fap]

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
OVERKILL_VERSION="2.4.0-FINAL_AGREEMENT"

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
    read -p "> " confirmation
    if [[ "$confirmation" != "I AGREE" ]]; then
        error "Agreement not provided. Installation has been cancelled."
        exit 1
    fi
}

set_tty_font() {
    section "CONFIGURING TTY FOR TV VIEWING"
    log "Attempting to set optimal TTY font..."
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
    # Adjusted font size for better readability based on common TV resolutions
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
        setupcon
    else
        warn "/etc/default/console-setup not found. Cannot configure TTY font."
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
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
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
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
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
        done
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
            read -sp "Enter a strong password for the '$OVERKILL_USER' user: " PASS1
            echo
            read -sp "Confirm the password: " PASS2
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
    
    # Version file with more info than LibreELEC
    cat > $OVERKILL_HOME/VERSION << EOF
OVERKILL_VERSION="$OVERKILL_VERSION"
OVERKILL_CODENAME="FINAL_AGREEMENT"
OVERKILL_BUILD_DATE="$(date -u +%Y-%m-%d)"
OVERKILL_MOTTO="UNLIMITED POWER. ZERO RESTRICTIONS."
OVERKILL_ADVANTAGES="
- Full Armbian Linux system
- Complete package management freedom
- NVMe-optimized from the ground up
- Advanced thermal management
- Intelligent fan control
- Expandable beyond media center
- Popular addon repos pre-installed
- Docker, Jellyfin, and more
- Complete monitoring suite
"
EOF
    
    log "Advanced infrastructure established"
}

kernel_overkill() {
    section "KERNEL OPTIMIZATION - MAXIMUM PERFORMANCE"
    
    log "Applying EXTREME kernel optimizations..."
    
    cat > /etc/sysctl.d/99-overkill-extreme.conf << 'EOF'
# OVERKILL KERNEL CONFIGURATION - MAXIMUM PERFORMANCE
# Optimized for media streaming and responsiveness

# Memory Management - MAXIMUM AGGRESSION
vm.swappiness=1
vm.vfs_cache_pressure=1
vm.dirty_ratio=50
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=300
vm.dirty_writeback_centisecs=50
vm.zone_reclaim_mode=0
vm.min_free_kbytes=131072
vm.page-cluster=0
vm.extfrag_threshold=100

# Network Stack - ENTERPRISE GRADE
net.core.rmem_max=536870912
net.core.wmem_max=536870912
net.core.netdev_max_backlog=50000
net.core.rmem_default=524288
net.core.wmem_default=524288
net.core.optmem_max=524288
net.ipv4.tcp_rmem=4096 87380 536870912
net.ipv4.tcp_wmem=4096 65536 536870912
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_window_scaling=1

# CPU Scheduler - MAXIMUM RESPONSIVENESS
kernel.sched_migration_cost_ns=500000
kernel.sched_autogroup_enabled=0
kernel.sched_cfs_bandwidth_slice_us=1000
kernel.timer_migration=0
kernel.sched_rt_runtime_us=980000
kernel.sched_latency_ns=1000000
kernel.sched_min_granularity_ns=100000

# I/O Performance - NVMe OPTIMIZED
vm.dirty_bytes=268435456
vm.dirty_background_bytes=134217728
kernel.io_delay_type=0
vm.ioprio_enable=1

# Security vs Performance - PERFORMANCE WINS
kernel.yama.ptrace_scope=0
kernel.unprivileged_userns_clone=1
kernel.kptr_restrict=0
kernel.dmesg_restrict=0

# Pi 5 Specific
vm.stat_interval=10
kernel.watchdog_thresh=20
EOF

    # NVMe-specific I/O scheduling
    cat > /etc/udev/rules.d/99-overkill-nvme.rules << 'EOF'
# OVERKILL NVMe OPTIMIZATION - PCIe 3.0 MAXIMUM THROUGHPUT
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="2048"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="2048"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/io_poll}="1"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/io_poll_delay}="0"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nomerges}="1"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rq_affinity}="2"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/add_random}="0"

# Enable write cache
ACTION=="add|change", KERNEL=="nvme[0-9]*", RUN+="/bin/sh -c 'echo write through > /sys/block/%k/queue/write_cache'"
EOF

    log "Kernel optimizations applied - MAXIMUM PERFORMANCE ACHIEVED"
}

pi5_hardware_overkill() {
    section "PI 5 HARDWARE DOMINATION - NO RESTRICTIONS"

    # Backup configs if they exist and haven't been backed up before
    if [[ -f "$ARMBIAN_CONFIG" ]] && [[ ! -f "${ARMBIAN_CONFIG}.pre-overkill" ]]; then
        cp "$ARMBIAN_CONFIG" "${ARMBIAN_CONFIG}.pre-overkill"
        log "Backed up $ARMBIAN_CONFIG to ${ARMBIAN_CONFIG}.pre-overkill"
    fi
    if [[ -f "$ARMBIAN_ENV" ]] && [[ ! -f "${ARMBIAN_ENV}.pre-overkill" ]]; then
        cp "$ARMBIAN_ENV" "${ARMBIAN_ENV}.pre-overkill"
        log "Backed up $ARMBIAN_ENV to ${ARMBIAN_ENV}.pre-overkill"
    fi

    log "Applying MAXIMUM HARDWARE OVERKILL..."

    # Armbian environment settings - check before adding
    if ! grep -q "# OVERKILL ARMBIAN CONFIGURATION" "$ARMBIAN_ENV"; then
        cat >> "$ARMBIAN_ENV" << 'EOF'

# OVERKILL ARMBIAN CONFIGURATION
# Maximum performance, no compromises
extraargs=numa=fake=8 cma=512M coherent_pool=2M audit=0 initcall_debug=0 raid=noautodetect noisapnp
EOF
        log "Added Overkill settings to $ARMBIAN_ENV"
    else
        log "Overkill settings already exist in $ARMBIAN_ENV"
    fi

    # Hardware configuration - check before adding
    if ! grep -q "# OVERKILL PI 5 CONFIGURATION" "$ARMBIAN_CONFIG"; then
        cat >> "$ARMBIAN_CONFIG" << 'EOF'

#########################################
# OVERKILL PI 5 CONFIGURATION
# MAXIMUM PERFORMANCE, ZERO LIMITS
# Pushing the Pi 5 to its absolute potential
#########################################

# NVMe PCIe 3.0 - MAXIMUM SPEED
dtparam=pciex1_gen=3
dtparam=pcie_preset=0

# GPU Memory - ALL OF IT
gpu_mem=1024
gpu_mem_1024=512
gpu_mem_512=256
gpu_mem_256=128

# Video Core VII - MAXIMUM ACCELERATION
dtoverlay=vc4-kms-v3d-pi5
max_framebuffers=3
disable_fw_kms_setup=1
hdmi_enable_4kp60=1

# Boot Configuration - INSTANT ON
disable_splash=1
boot_delay=0
disable_overscan=1
avoid_warnings=2
initial_turbo=60

# HDMI - MAXIMUM COMPATIBILITY & QUALITY
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_force_mode=1
hdmi_blanking=0
hdmi_ignore_edid_audio=0
hdmi_force_edid_audio=1
hdmi_max_pixel_freq=600000000
hdmi_enable_hdr=1
hdmi_force_hdr=1
hdmi_hdr_type=2
config_hdmi_boost=8
hdmi_delay=5

# Fix Denon/AVR handshake issues that plague media centers
hdmi_ignore_cec_init=1
hdmi_ignore_cec=0

# Audio - AUDIOPHILE GRADE
dtparam=audio=on
audio_pwm_mode=2
disable_audio_dither=1
enable_audio_monitor=1

# OVERCLOCKING - ABSOLUTELY MENTAL
# Pushing beyond safe defaults - ensure cooling!
force_turbo=0
over_voltage=8
over_voltage_delta=50000
arm_freq=2800
gpu_freq=1000
core_freq=910
h264_freq=910
isp_freq=910
v3d_freq=910
sdram_freq=4267
sdram_schmoo=0x02000020
over_voltage_sdram=4

# Power Management - UNLIMITED
max_usb_current=1
usb_max_current_enable=1
disable_poe_fan=0

# Hardware Interfaces - EVERYTHING ENABLED
dtparam=spi=on
dtparam=i2c_arm=on
dtparam=i2c1=on
dtparam=i2s=on

# USB Optimization - MAXIMUM BANDWIDTH
dwc_otg.lpm_enable=0
dwc_otg.fiq_enable=1
dwc_otg.fiq_fsm_enable=1
dwc_otg.fiq_fsm_mask=0x3

# Fan Control - INTELLIGENT COOLING
dtoverlay=gpio-fan,gpiopin=14,temp=55000
cooling_fan=on

# Temperature Management - RUN HOT BUT SAFE
temp_limit=85
temp_soft_limit=82

# Disable unnecessary components
camera_auto_detect=0
display_auto_detect=0

# Enable experimental features for maximum performance
enable_tvout=0
arm_boost=1

#########################################
EOF
        log "Added Overkill settings to $ARMBIAN_CONFIG"
    else
        log "Overkill settings already exist in $ARMBIAN_CONFIG"
    fi
    
    warn "Applied EXTREME overclocking - monitor your temps!"
    log "Hardware configuration complete - Reboot required to apply changes"
}

setup_thermal_overkill() {
    section "INTELLIGENT THERMAL MANAGEMENT"
    
    log "Installing advanced fan control system..."
    
    cat > /usr/local/bin/overkill-fancontrol << 'EOF'
#!/bin/bash
# Overkill Intelligent Fan Control
# Adaptive cooling based on workload

LAST_TEMP=0
LAST_STATE=0

log_thermal() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Temp: $1°C, Fan: $2" >> /var/log/overkill/thermal.log
}

while true; do
    TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d. -f1)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Hysteresis to prevent rapid switching
    TEMP_DELTA=$((TEMP - LAST_TEMP))
    
    # Intelligent fan curve with workload prediction
    if [[ $TEMP -lt 40 ]]; then
        FAN_STATE=0  # Silent
    elif [[ $TEMP -lt 50 ]] && [[ $TEMP_DELTA -le 2 ]]; then
        FAN_STATE=1  # Whisper quiet
    elif [[ $TEMP -lt 60 ]] || [[ $CPU_USAGE -gt 50 ]]; then
        FAN_STATE=2  # Balanced
    elif [[ $TEMP -lt 70 ]] || [[ $CPU_USAGE -gt 70 ]]; then
        FAN_STATE=3  # Performance
    elif [[ $TEMP -lt 80 ]] || [[ $TEMP_DELTA -gt 5 ]]; then
        FAN_STATE=4  # Aggressive
    else
        FAN_STATE=5  # MAXIMUM COOLING
    fi
    
    # Apply state only if changed
    if [[ $FAN_STATE -ne $LAST_STATE ]]; then
        echo $FAN_STATE > /sys/class/thermal/cooling_device0/cur_state 2>/dev/null || true
        log_thermal $TEMP $FAN_STATE
    fi
    
    LAST_TEMP=$TEMP
    LAST_STATE=$FAN_STATE
    
    sleep 2
done
EOF

    chmod +x /usr/local/bin/overkill-fancontrol
    
    # Create systemd service
    cat > /etc/systemd/system/overkill-thermal.service << EOF
[Unit]
Description=Overkill Intelligent Thermal Management
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/overkill-fancontrol
Restart=always
Nice=-10

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
    
    log "Installing build tools - EVERYTHING..."
    apt install -y \
        build-essential cmake git autoconf automake libtool pkg-config \
        debhelper autopoint gettext autotools-dev curl default-jdk \
        doxygen gawk gperf yasm nasm ccache swig unzip zip \
        python3-dev python3-pip python3-setuptools python3-wheel \
        libssl-dev libcurl4-openssl-dev liblz4-dev libzstd-dev \
        ninja-build meson gnutls-dev crossbuild-essential-arm64
    
    log "Installing Kodi 21 specific dependencies..."
    apt install -y \
        libegl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dev libglu1-mesa-dev \
        libdrm-dev libgbm-dev mesa-common-dev libgl1-mesa-dri \
        mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers \
        v4l-utils libv4l-dev libdisplay-info-dev libinput-dev \
        libwayland-dev libxkbcommon-dev waylandpp-dev libwlroots-dev
    
    log "Installing codec libraries - ALL formats..."
    apt install -y \
        libavcodec-dev libavformat-dev libavutil-dev libpostproc-dev \
        libswscale-dev libswresample-dev libavfilter-dev libavdevice-dev \
        libass-dev libbluray-dev libcdio-dev libdav1d-dev \
        libdvdnav-dev libdvdread-dev libdvdcss2 libdvdcss-dev \
        libmad0-dev libmpeg2-4-dev libaom-dev libvpx-dev \
        libtheora-dev libvorbis-dev libopus-dev \
        libx264-dev libx265-dev libxvidcore-dev
    
    log "Installing audio subsystem - AUDIOPHILE GRADE..."
    apt install -y \
        libasound2-dev libpulse-dev libjack-jackd2-dev \
        alsa-utils pulseaudio pulseaudio-utils libsamplerate0-dev \
        pavucontrol pipewire pipewire-alsa pipewire-pulse pipewire-jack \
        libfdk-aac-dev ladspa-sdk libspeexdsp-dev
    
    log "Installing control systems - COMPLETE DOMINATION..."
    apt install -y \
        libcec-dev libp8-platform-dev cec-utils \
        lirc liblirc-dev libnss3-dev \
        libevdev-dev libudev-dev
    
    log "Installing extended features for complete system..."
    apt install -y \
        docker.io docker-compose podman \
        syncthing transmission-daemon \
        nginx postgresql redis \
        ffmpeg v4l2loopback-dkms \
        wine wine32 wine64 \
        flatpak snapd
    
    log "Installing Kodi build dependencies..."
    apt install -y \
        libdbus-1-dev libfontconfig-dev libfreetype6-dev \
        libfribidi-dev libfstrcmp-dev libgcrypt-dev \
        libgif-dev libgnutls28-dev libgpg-error-dev \
        libjpeg-dev liblcms2-dev libltdl-dev liblzo2-dev \
        libmicrohttpd-dev libnfs-dev libogg-dev libpcre2-dev \
        libplist-dev libpng-dev libsmbclient-dev libspdlog-dev \
        libsqlite3-dev libtag1-dev libtiff5-dev libtinyxml-dev \
        libva-dev libvdpau-dev libxmu-dev libxrandr-dev libxss-dev libxt-dev \
        libavahi-client-dev libavahi-common-dev \
        libbluetooth-dev libbz2-dev libcrossguid-dev \
        libcwiid-dev libenca-dev libflac-dev libfmt-dev \
        libgtest-dev libiso9660-dev libmysqlclient-dev \
        libshairplay-dev flatbuffers-dev libunistring-dev \
        libdisplay-info-dev libpipewire-0.3-dev libspa-0.2-dev
    
    log "Installing performance monitoring tools..."
    apt install -y \
        htop btop iotop iftop nethogs \
        stress-ng s-tui glances \
        lm-sensors fancontrol i2c-tools \
        smartmontools nvme-cli hdparm \
        sysbench fio iperf3
    
    log "ALL DEPENDENCIES INSTALLED - READY FOR ABSOLUTE DOMINATION"
}

build_kodi_overkill() {
    section "BUILDING KODI 21 OMEGA - MAXIMUM OPTIMIZATION"
    
    # Try repository first for speed
    if attempt_repo_install; then
        return 0
    fi
    
    warn "Building from source with EXTREME optimizations..."
    
    rm -rf $OVERKILL_BUILD_DIR
    mkdir -p $OVERKILL_BUILD_DIR
    cd $OVERKILL_BUILD_DIR
    
    log "Cloning Kodi 21 Omega source..."
    git clone --depth 1 --branch Omega https://github.com/xbmc/xbmc.git kodi
    cd kodi
    
    log "Configuring build with Pi 5 MAXIMUM optimization..."
    mkdir -p build
    cd build
    
    # EXTREME optimization flags for Cortex-A76
    local OVERKILL_FLAGS="-O3 -march=armv8.2-a+fp16+rcpc+dotprod+crypto -mcpu=cortex-a76+crypto -mtune=cortex-a76"
    OVERKILL_FLAGS="$OVERKILL_FLAGS -fomit-frame-pointer -funroll-loops -ftree-vectorize"
    OVERKILL_FLAGS="$OVERKILL_FLAGS -funsafe-math-optimizations -ffast-math -fno-finite-math-only"
    OVERKILL_FLAGS="$OVERKILL_FLAGS -fprefetch-loop-arrays -flto=auto -fuse-linker-plugin"
    
    # Kodi 21 specific CMake configuration
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="$OVERKILL_FLAGS" \
        -DCMAKE_CXX_FLAGS="$OVERKILL_FLAGS" \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCORE_PLATFORM_NAME=gbm \
        -DAPP_RENDER_SYSTEM=gles \
        -DENABLE_INTERNAL_FFmpeg=OFF \
        -DENABLE_VAAPI=ON \
        -DENABLE_VDPAU=OFF \
        -DENABLE_CEC=ON \
        -DENABLE_LIBCEC=ON \
        -DENABLE_LIRC=ON \
        -DENABLE_EVENTCLIENTS=ON \
        -DENABLE_UPNP=ON \
        -DENABLE_DVDCSS=ON \
        -DENABLE_OPTICAL=ON \
        -DENABLE_BLURAY=ON \
        -DENABLE_NONFREE=ON \
        -DENABLE_AVAHI=ON \
        -DENABLE_PLIST=ON \
        -DENABLE_NFS=ON \
        -DENABLE_PIPEWIRE=ON \
        -DENABLE_PULSEAUDIO=ON \
        -DENABLE_ALSA=ON \
        -DENABLE_MICROHTTPD=ON \
        -DENABLE_MYSQLCLIENT=ON \
        -DENABLE_INTERNAL_CROSSGUID=OFF \
        -DENABLE_INTERNAL_FLATBUFFERS=OFF \
        -DENABLE_INTERNAL_FMT=OFF \
        -DENABLE_INTERNAL_SPDLOG=OFF \
        -DENABLE_INTERNAL_DAV1D=OFF \
        -DENABLE_TESTING=OFF \
        -DVERBOSE=1
    
    log "Building with MAXIMUM PARALLELISM..."
    make -j$(nproc)
    
    log "Installing OVERKILL Kodi..."
    make install
    ldconfig
    
    # Install Python dependencies for addons
    pip3 install --upgrade \
        pycryptodome \
        pil \
        pycountry \
        arrow \
        pytz \
        requests \
        urllib3 \
        chardet \
        idna \
        certifi \
        beautifulsoup4 \
        lxml \
        dateutil \
        six \
        kodi-six \
        inputstreamhelper \
        jellyfin-apiclient-python \
        PlexAPI \
        trakt.py \
        tmdbsimple \
        google-api-python-client \
        oauth2client \
        httplib2
    
    log "KODI 21 OMEGA BUILD COMPLETE - MAXIMUM OPTIMIZATION ACHIEVED"
}

attempt_repo_install() {
    log "Checking for pre-built packages..."
    
    # Add Raspberry Pi repository
    if [[ ! -f /etc/apt/sources.list.d/raspi.list ]]; then
        echo "deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.gpg] https://archive.raspberrypi.org/debian/ bookworm main" > /etc/apt/sources.list.d/raspi.list
        
        if [[ ! -f /usr/share/keyrings/raspberrypi-archive-keyring.gpg ]]; then
            curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key | gpg --dearmor -o /usr/share/keyrings/raspberrypi-archive-keyring.gpg
        fi
    fi
    
    apt update
    
    # Try to install Kodi 21
    if apt install -y kodi kodi-eventclients-kodi-send kodi-inputstream-adaptive kodi-inputstream-ffmpegdirect kodi-inputstream-rtmp kodi-peripheral-joystick kodi-vfs-libarchive kodi-vfs-sftp kodi-visualization-spectrum; then
        log "Repository installation successful"
        
        # Install additional binary addons if available
        apt install -y kodi-pvr-iptvsimple kodi-pvr-hts || true
        
        return 0
    fi
    
    return 1
}

create_overkill_launcher() {
    section "CREATING ADVANCED LAUNCHER"
    
    log "Creating MAXIMUM PERFORMANCE launcher..."
    cat > $OVERKILL_HOME/bin/overkill << 'EOF'
#!/bin/bash
# OVERKILL Media Center Launcher
# UNLIMITED POWER, ZERO COMPROMISE

# Set MAXIMUM process priority
exec nice -n -20 ionice -c 1 -n 0 bash << 'MAXIMUM_OVERKILL'

# Environment setup
export KODI_HOME="/usr/local/share/kodi"
export KODI_TEMP="/tmp/overkill-$(id -u)"
export OVERKILL_SESSION="DOMINATION"
mkdir -p "$KODI_TEMP"

# Pi 5 Hardware Acceleration - ALL OF IT
export LIBVA_DRIVER_NAME=v4l2_request
export VDPAU_DRIVER=v4l2_request
export MESA_LOADER_DRIVER_OVERRIDE=v3d
export V4L2_REQUEST_MEDIA_DEVICE=/dev/media0

# Graphics Optimization - MAXIMUM
export __GL_THREADED_OPTIMIZATIONS=1
export __GL_SYNC_TO_VBLANK=0
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLSL_VERSION_OVERRIDE=460
export __GL_MaxFramesAllowed=1
export mesa_glthread=true

# Audio Configuration - AUDIOPHILE MODE
export PULSE_RUNTIME_PATH="/run/user/$(id -u)/pulse"
export PIPEWIRE_RUNTIME_DIR="/run/user/$(id -u)"
export ALSA_CARD=0
export AUDIODRIVER=pipewire

# Fix LibreELEC audio issues
if pgrep pipewire > /dev/null; then
    export KODI_AE_SINK=PIPEWIRE
else
    export KODI_AE_SINK=PULSE
fi

# Disable compositing for performance
export KODI_GL_INTERFACE=gbm
export EGL_PLATFORM=gbm

# CPU Performance mode
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true

# GPU Performance mode
echo performance > /sys/class/devfreq/gpu/governor 2>/dev/null || true

# Pre-cache libraries
ldconfig

# Launch Kodi with OVERKILL settings
exec /usr/local/bin/kodi \
    --standalone \
    --windowing=gbm \
    --audio-backend=${KODI_AE_SINK,,} \
    --loglevel=1 \
    "$@"

MAXIMUM_OVERKILL
EOF
    
    chmod +x $OVERKILL_HOME/bin/overkill
    ln -sf $OVERKILL_HOME/bin/overkill /usr/local/bin/overkill
    ln -sf $OVERKILL_HOME/bin/overkill /usr/local/bin/kodi-standalone
    
    log "Advanced launcher created"
}

setup_overkill_service() {
    section "CREATING SYSTEM SERVICE - NO RESTRICTIONS"
    
    log "Creating systemd service with ABSOLUTE PRIORITY..."
    cat > /etc/systemd/system/overkill.service << EOF
[Unit]
Description=Overkill Media Center - Advanced LibreELEC Alternative
Documentation=https://github.com/overkill/overkill
After=graphical-session.target sound.target network-online.target
Wants=network-online.target
Requires=dbus.service
ConditionPathExists=/usr/local/bin/overkill

[Service]
Type=simple
User=$OVERKILL_USER
Group=$OVERKILL_USER
PAMName=login
Environment="HOME=/home/$OVERKILL_USER"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u $OVERKILL_USER)"
Environment="XDG_SESSION_TYPE=tty"
Environment="XDG_SESSION_CLASS=user"
Environment="OVERKILL_MODE=DOMINATION"
Environment="DISPLAY=:0"
ExecStartPre=/bin/bash -c 'sleep 3; systemctl --user --machine=$OVERKILL_USER@ start pipewire pipewire-pulse wireplumber'
ExecStart=$OVERKILL_HOME/bin/overkill
Restart=always
RestartSec=3
TimeoutStopSec=10
KillMode=mixed

# MAXIMUM PERFORMANCE SETTINGS
Nice=-20
IOSchedulingClass=realtime
IOSchedulingPriority=0
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
LimitNOFILE=65536
LimitMEMLOCK=infinity
LimitRTPRIO=99
PrivateTmp=false

# Capabilities
AmbientCapabilities=CAP_SYS_NICE CAP_SYS_RESOURCE CAP_SYS_ADMIN
SecureBits=keep-caps

[Install]
WantedBy=graphical.target
EOF

    # Create auto-login service
    cat > /etc/systemd/system/overkill-autologin@.service << EOF
[Unit]
Description=Overkill Media Center Autologin on %I
After=systemd-user-sessions.service plymouth-quit-wait.service
After=rc-local.service
Before=getty.target
Conflicts=getty@%i.service
ConditionPathExists=/usr/local/bin/overkill

[Service]
ExecStart=-/sbin/agetty --autologin $OVERKILL_USER --noclear %I \$TERM
Type=idle
Restart=always
RestartSec=0
UtmpIdentifier=%I
TTYPath=/dev/%I
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
KillMode=process
IgnoreSIGPIPE=no
SendSIGHUP=yes

[Install]
WantedBy=getty.target
EOF

    systemctl daemon-reload
    systemctl enable overkill.service
    systemctl enable overkill-autologin@tty1.service
    
    log "OVERKILL service configured with MAXIMUM PRIORITY"
}

configure_display_overkill() {
    section "DISPLAY CONFIGURATION - PERFECT HDMI/HDR"
    
    log "Creating HDMI auto-fix system..."
    
    cat > /usr/local/bin/overkill-hdmi-fix << 'EOF'
#!/bin/bash
# Auto-fix HDMI handshake issues for perfect compatibility

EDID_DIR="/etc/overkill/edid"
mkdir -p "$EDID_DIR"

# Detect and cache EDID
for card in /sys/class/drm/card*-HDMI-A-1; do
    if [[ -e "$card/edid" ]]; then
        CARD_NAME=$(basename $card)
        if [[ ! -f "$EDID_DIR/$CARD_NAME.bin" ]]; then
            cat "$card/edid" > "$EDID_DIR/$CARD_NAME.bin"
            echo "Cached EDID for $CARD_NAME"
        fi
    fi
done

# Apply EDID override if needed
if ls $EDID_DIR/*.bin &>/dev/null; then
    EDID_FILE=$(ls $EDID_DIR/*.bin | head -1)
    if ! grep -q "drm.edid_firmware" /boot/cmdline.txt; then
        sed -i "s/$/ drm.edid_firmware=HDMI-A-1:$(basename $EDID_FILE) video=HDMI-A-1:D/" /boot/cmdline.txt
        echo "Applied EDID override - reboot required"
    fi
fi
EOF

    chmod +x /usr/local/bin/overkill-hdmi-fix
    
    # HDR configuration
    cat > $OVERKILL_CONFIG/display/hdr.conf << 'EOF'
# Overkill HDR Configuration
# Maximum quality settings

# Force HDR mode
hdmi_enable_hdr=1
hdmi_hdr_type=2
hdmi_max_pixel_freq=600000000

# Deep Color support
hdmi_pixel_encoding=2
hdmi_output_format=2

# Fix color space issues
hdmi_force_rgb_limited=0
hdmi_force_rgb_full=1
EOF

    log "Display fixes configured"
}

configure_overkill_kodi() {
    section "CONFIGURING KODI - MAXIMUM PERFORMANCE"
    
    log "Setting up advanced Kodi configuration..."
    sudo -u $OVERKILL_USER mkdir -p /home/$OVERKILL_USER/.kodi/{userdata,addons,system}
    
    log "Creating EXTREME performance advancedsettings.xml..."
    sudo -u $OVERKILL_USER cat > /home/$OVERKILL_USER/.kodi/userdata/advancedsettings.xml << 'EOF'
<advancedsettings>
    <loglevel>1</loglevel>
    
    <network>
        <buffermode>1</buffermode>
        <cachemembuffersize>2147483648</cachemembuffersize>
        <readbufferfactor>20</readbufferfactor>
        <curlclienttimeout>45</curlclienttimeout>
        <curllowspeedtime>60</curllowspeedtime>
        <curlretries>5</curlretries>
        <httpproxyusername></httpproxyusername>
        <httpproxypassword></httpproxypassword>
        <disablehttp2>false</disablehttp2>
        <nfstimeout>30</nfstimeout>
    </network>
    
    <video>
        <defaultplayer>VideoPlayer</defaultplayer>
        <fullscreenontoggle>true</fullscreenontoggle>
        <playcountminimumpercent>85</playcountminimumpercent>
        <ignoresecondsatstart>180</ignoresecondsatstart>
        <ignorepercentatend>10</ignorepercentatend>
        <smallstepbackseconds>3</smallstepbackseconds>
        <usetimeseeking>true</usetimeseeking>
        <timeseekforward>10</timeseekforward>
        <timeseekbackward>-10</timeseekbackward>
        <allowdrmprimerender>true</allowdrmprimerender>
        <videoplayer>
            <rendermethod>direct-to-plane</rendermethod>
            <adjustrefreshrate>always</adjustrefreshrate>
            <usedisplayasclock>true</usedisplayasclock>
            <errorinaspect>0</errorinaspect>
            <stretch43>0</stretch43>
            <toneMapMethod>reinhard</toneMapMethod>
            <toneMapParam>1.5</toneMapParam>
            <cms3dluts>true</cms3dluts>
            <displayhdrcolorspace>true</displayhdrcolorspace>
        </videoplayer>
        <fullscreen>true</fullscreen>
        <vsync>always</vsync>
        <gulimitsync>1</gulimitsync>
        <pauseafterrefreshchange>0</pauseafterrefreshchange>
        <blackbarcolour>0xFF000000</blackbarcolour>
        <stereoscopicregex3d>[-. _]3d[-. _]</stereoscopicregex3d>
        <stereoscopicregexsbs>[-. _]h?sbs[-. _]</stereoscopicregexsbs>
        <stereoscopicregextab>[-. _]h?tab[-. _]</stereoscopicregextab>
        <hqscalers>20</hqscalers>
    </video>
    
    <audio>
        <ac3transcode>false</ac3transcode>
        <ac3passthrough>true</ac3passthrough>
        <dtspassthrough>true</dtspassthrough>
        <truehdpassthrough>true</truehdpassthrough>
        <dtshdpassthrough>true</dtshdpassthrough>
        <eac3passthrough>true</eac3passthrough>
        <channels>7.1</channels>
        <defaultplayer>VideoPlayer</defaultplayer>
        <audiodevice>PIPEWIRE:@DEFAULT_SINK@</audiodevice>
        <passthroughdevice>PIPEWIRE:@DEFAULT_SINK@</passthroughdevice>
        <stereoupmix>true</stereoupmix>
        <maintainoriginalvolume>true</maintainoriginalvolume>
        <processquality>high</processquality>
        <streamsilence>0</streamsilence>
        <limiterhold>0.025</limiterhold>
        <limiterrelease>0.1</limiterrelease>
        <normalizelevels>false</normalizelevels>
        <guisoundmode>1</guisoundmode>
    </audio>
    
    <cec>
        <enabled>true</enabled>
        <activatesource>true</activatesource>
        <standbydevices>true</standbydevices>
        <useTVMenuLanguage>true</useTVMenuLanguage>
        <wakedevices>36037</wakedevices>
        <standbydevices>36037</standbydevices>
        <poweroffscreensaver>false</poweroffscreensaver>
        <powerofonstart>true</powerofonstart>
        <standbyonquit>false</standbyonquit>
        <tvvendor>0</tvvendor>
        <devicename>Overkill</devicename>
        <hdmiport>1</hdmiport>
        <physicaladdress>0</physicaladdress>
        <usetvmenuosd>true</usetvmenuosd>
        <wakecommand>on</wakecommand>
        <standbycommand>standby</standbycommand>
    </cec>
    
    <input>
        <remoteaskeyboard>false</remoteaskeyboard>
        <controllerpoweroffjoystickinput>false</controllerpoweroffjoystickinput>
        <enablemultitouch>true</enablemultitouch>
    </input>
    
    <cache>
        <memorysize>2147483648</memorysize>
        <buffermode>1</buffermode>
        <readfactor>20</readfactor>
    </cache>
    
    <gui>
        <algorithmdirtyregions>3</algorithmdirtyregions>
        <nofliptimeout>0</nofliptimeout>
        <visualizedirtyregions>false</visualizedirtyregions>
    </gui>
    
    <services>
        <upnpserver>false</upnpserver>
        <upnprenderer>false</upnprenderer>
        <upnpcontroller>false</upnpcontroller>
        <webserver>true</webserver>
        <webserverport>8080</webserverport>
        <webserverusername>overkill</webserverusername>
        <webserverpassword>overkill</webserverpassword>
        <esallinterfaces>true</esallinterfaces>
        <airplay>false</airplay>
        <zeroconf>false</zeroconf>
    </services>
    
    <powermanagement>
        <shutdowntime>0</shutdowntime>
        <shutdownstate>0</shutdownstate>
        <wakeonaccess>false</wakeonaccess>
    </powermanagement>
    
    <overkill>
        <version>$OVERKILL_VERSION</version>
        <performance>MAXIMUM</performance>
        <restrictions>NONE</restrictions>
        <superiority>ABSOLUTE</superiority>
    </overkill>
</advancedsettings>
EOF

    log "Creating H.264 50/60fps performance fix..."
    if ! grep -q "core_freq_min=500" "$ARMBIAN_CONFIG"; then
        echo "core_freq_min=500" >> "$ARMBIAN_CONFIG"
    fi
    if ! grep -q "force_turbo=1" "$ARMBIAN_CONFIG"; then
         echo "force_turbo=1" >> "$ARMBIAN_CONFIG"
    fi

    chown -R $OVERKILL_USER:$OVERKILL_USER /home/$OVERKILL_USER/.kodi
    log "Kodi configured for ABSOLUTE DOMINATION"
}

setup_media_structure() {
    section "CREATING ADVANCED MEDIA STRUCTURE"
    
    log "Creating NVMe-optimized media directories..."
    
    # Find NVMe mount point more reliably
    local nvme_mount_info=$(lsblk -no NAME,MOUNTPOINT | grep "^$NVME_DEVICE" | grep -w '/')
    if [[ -n "$nvme_mount_info" ]]; then
        NVME_MOUNT=$(echo "$nvme_mount_info" | awk '{print $2}')
        log "Using NVMe mount point at $NVME_MOUNT"
    else
        NVME_MOUNT="/"
        warn "Could not determine a separate NVMe mount point, using root filesystem at '/'."
    fi

    # Create optimized structure on NVMe
    mkdir -p "$NVME_MOUNT/overkill"/{movies/{4K/{HDR,DolbyVision,HDR10+},HD,SD,Classic},tv/{4K,HD,Anime,Documentaries},music/{FLAC,DSD,MP3,Playlists},pictures/{Photos,Wallpapers,Art},downloads,games,backups}
    
    # Create symlinks
    mkdir -p $MEDIA_ROOT
    if [[ "$NVME_MOUNT" == "/" ]]; then
        # If media is on root fs, source is /overkill
        ln -sfn "/overkill" "$MEDIA_ROOT/overkill"
    else
        # Otherwise, it's on a separate mount
        ln -sfn "$NVME_MOUNT/overkill" "$MEDIA_ROOT/overkill"
    fi
    
    # Set optimized permissions
    chown -R $OVERKILL_USER:$OVERKILL_USER "$NVME_MOUNT/overkill"
    chmod 755 "$NVME_MOUNT/overkill"
    chmod -R 775 "$NVME_MOUNT/overkill"/*
    
    # Create index for fast scanning
    log "Creating media index for instant library updates..."
    cat > /usr/local/bin/overkill-media-index << 'EOF'
#!/bin/bash
# Fast media indexing for Kodi

find /media/overkill -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.flac" -o -iname "*.mp3" \) > /var/lib/overkill/media.index
EOF
    chmod +x /usr/local/bin/overkill-media-index
    
    log "Advanced media structure established on NVMe"
}

configure_power_overkill() {
    section "POWER MANAGEMENT - MAXIMUM STABILITY"
    
    log "Configuring power for maximum performance..."
    
    # Maximum USB power
    if ! grep -q "max_usb_current=1" "$ARMBIAN_CONFIG"; then
        echo "max_usb_current=1" >> "$ARMBIAN_CONFIG"
    fi
    if ! grep -q "usb_max_current_enable=1" "$ARMBIAN_CONFIG"; then
        echo "usb_max_current_enable=1" >> "$ARMBIAN_CONFIG"
    fi
    
    # PSU detection and optimization
    cat > /etc/udev/rules.d/99-overkill-power.rules << 'EOF'
# Overkill Power Management - Maximum performance
# Ensures all USB devices get full power

# Maximum power for all USB devices
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/level", ATTR{power/level}="on"

# Disable USB autosuspend completely
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="*", ATTR{power/control}="on"

# PSU detection
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/local/bin/overkill-power-optimize"
EOF

    # Power optimization script
    cat > /usr/local/bin/overkill-power-optimize << 'EOF'
#!/bin/bash
# Detect PSU and optimize accordingly

PSU_CURRENT=$(vcgencmd get_config int | grep -E "max_current|usb_max_current" | head -1 | cut -d= -f2)

if [[ $PSU_CURRENT -ge 5000 ]]; then
    echo "5A PSU detected - MAXIMUM POWER MODE"
    echo 1 > /sys/module/dwc2/parameters/besl
    echo 512 > /sys/module/usbcore/parameters/usbfs_memory_mb
else
    echo "Lower power PSU - optimizing"
fi
EOF

    chmod +x /usr/local/bin/overkill-power-optimize
    
    log "Power management configured - No more USB issues"
}

install_popular_addons() {
    local install_umbrella_flag=$1
    local install_fap_flag=$2

    section "INSTALLING POPULAR KODI ADDONS"
    
    log "Installing addon repositories for a complete experience..."
    
    local python_args=""
    if [[ "$install_umbrella_flag" == "true" ]]; then
        python_args="$python_args --install-umbrella"
        log "Umbrella addon repository installation requested."
    fi
    if [[ "$install_fap_flag" == "true" ]]; then
        python_args="$python_args --install-fap"
        log "Adult addon repository installation requested."
    fi

    # Download addon installer script
    cat > /tmp/install-addons.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import zipfile
import shutil
import time
import urllib.request

KODI_ADDON_DIR = "/home/overkill/.kodi/addons"
KODI_DATA_DIR = "/home/overkill/.kodi/userdata/addon_data"
OVERKILL_USER_ID = 1000

EXTERNAL_REPOS = {
    "repository.slyguy": {
        "url": "https://k.slyguy.xyz/repository.slyguy-2.0.4.zip",
    },
    "repository.castagnait": {
        "url": "https://github.com/castagnait/repository.castagnait/raw/kodi/repository.castagnait-2.0.0.zip",
    }
}

UMBRELLA_REPO = {
    "repository.umbrella": {
        "url": "https://umbrellaplug.github.io/repository.umbrella-2.0.2.zip",
    }
}

ADULT_REPO = {
    "repository.thecrew": {
        "url": "https://team-crew.github.io/repository.thecrew-0.3.4.zip",
    }
}

def ensure_directories():
    os.makedirs(KODI_ADDON_DIR, exist_ok=True)
    os.makedirs(KODI_DATA_DIR, exist_ok=True)
    if os.geteuid() == 0:
        os.chown(KODI_ADDON_DIR, OVERKILL_USER_ID, OVERKILL_USER_ID)
        os.chown(KODI_DATA_DIR, OVERKILL_USER_ID, OVERKILL_USER_ID)

def download_file(url, dest):
    try:
        print(f"Downloading {url}...")
        urllib.request.urlretrieve(url, dest)
        return True
    except Exception as e:
        print(f"Error downloading {url}: {e}")
        return False

def install_zip_addon(zip_path, addon_dir):
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            for file in zip_ref.namelist():
                if file.endswith('addon.xml'):
                    addon_id = os.path.dirname(file).split('/')[0]
                    if addon_id:
                        dest_dir = os.path.join(addon_dir, addon_id)
                        print(f"Installing {addon_id}...")
                        temp_dir = f"/tmp/{addon_id}_temp"
                        if os.path.exists(temp_dir):
                            shutil.rmtree(temp_dir)
                        zip_ref.extractall(temp_dir)
                        source = os.path.join(temp_dir, addon_id)
                        if os.path.exists(source):
                            if os.path.exists(dest_dir):
                                shutil.rmtree(dest_dir)
                            shutil.move(source, addon_dir)
                            if os.geteuid() == 0:
                                for root, dirs, files in os.walk(dest_dir):
                                    os.chown(root, OVERKILL_USER_ID, OVERKILL_USER_ID)
                                    for d in dirs:
                                        os.chown(os.path.join(root, d), OVERKILL_USER_ID, OVERKILL_USER_ID)
                                    for f in files:
                                        os.chown(os.path.join(root, f), OVERKILL_USER_ID, OVERKILL_USER_ID)
                            shutil.rmtree(temp_dir, ignore_errors=True)
                            return True
                    break
    except Exception as e:
        print(f"Error installing addon from zip: {e}")
    return False

def main():
    print("=== OVERKILL ADDON INSTALLER ===")
    ensure_directories()
    
    install_umbrella = '--install-umbrella' in sys.argv
    install_fap = '--install-fap' in sys.argv

    if install_umbrella:
        print("\n--umbrella flag detected. Adding Umbrella repository to the installation list.")
        EXTERNAL_REPOS.update(UMBRELLA_REPO)

    if install_fap:
        print("\n--fap flag detected. Adding adult content repository to the installation list.")
        EXTERNAL_REPOS.update(ADULT_REPO)

    print("\nInstalling external repositories...")
    for repo_id, repo_info in EXTERNAL_REPOS.items():
        zip_file = f"/tmp/{repo_id}.zip"
        if download_file(repo_info['url'], zip_file):
            if install_zip_addon(zip_file, KODI_ADDON_DIR):
                print(f"✓ Installed {repo_id}")
            os.remove(zip_file)
        time.sleep(1)
    
    print("\n✓ Addon repository installation complete!")
    print("\nInstalled repositories:")
    for repo in EXTERNAL_REPOS:
        print(f"- {repo}")
    print("\nAddons can now be installed from these repositories inside Kodi.")
    print("Go to Settings > Add-ons > Install from repository.")
    if install_fap:
        print("\n- Cumination can be found in The Crew Repository.")

if __name__ == "__main__":
    main()
EOF

    chmod +x /tmp/install-addons.py
    python3 /tmp/install-addons.py $python_args
    rm -f /tmp/install-addons.py

    log "Addon repositories installed. You can now install specific addons from within Kodi."
}

create_overkill_tools() {
    section "CREATING MANAGEMENT TOOLS"
    
    # Status tool
    cat > $OVERKILL_HOME/bin/overkill-status << 'EOF'
#!/bin/bash
# Overkill System Status - Complete system overview

echo -e "\033[1;31m"
echo "╔════════════════════════════════════════════════════════╗"
echo "║          OVERKILL SYSTEM STATUS - FULL REPORT          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

echo "System Information:"
echo "  Model: $(cat /proc/device-tree/model 2>/dev/null)"
echo "  Kernel: $(uname -r)"
echo "  Uptime: $(uptime -p)"
echo ""

echo "Hardware Status:"
echo "  CPU Temp: $(vcgencmd measure_temp | cut -d'=' -f2)"
echo "  CPU Freq: $(vcgencmd measure_clock arm | cut -d'=' -f2 | awk '{print int($1/1000000)" MHz"}')"
echo "  GPU Freq: $(vcgencmd measure_clock v3d | cut -d'=' -f2 | awk '{print int($1/1000000)" MHz"}')"
echo "  Voltage: $(vcgencmd measure_volts | cut -d'=' -f2)"
echo "  Throttling: $(vcgencmd get_throttled | cut -d'=' -f2)"
echo ""

echo "System Resources:"
echo "  Memory: $(free -h | grep Mem | awk '{print $3 "/" $2 " (" int($3/$2*100) "%)"}')"
echo "  Swap: $(free -h | grep Swap | awk '{print $3 "/" $2}')"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  Processes: $(ps aux | wc -l)"
echo ""

echo "Storage:"
df -h | grep -E "(nvme|root|media)" | awk '{print "  " $1 ": " $3 "/" $2 " (" $5 ") on " $6}'
echo ""

echo "NVMe Status:"
if command -v nvme &>/dev/null && [[ -e /dev/nvme0 ]]; then
    nvme smart-log /dev/nvme0 | grep -E "(temperature|available_spare|percentage_used)"
fi
echo ""

echo "Overkill Service:"
if systemctl is-active --quiet overkill; then
    echo "  Status: ✓ DOMINATION MODE ACTIVE"
    echo "  Uptime: $(systemctl show overkill -p ActiveEnterTimestamp | cut -d= -f2-)"
else
    echo "  Status: ✗ OVERKILL INACTIVE"
fi
echo ""

echo "Network:"
local_ip=$(hostname -I | awk '{print $1}')
echo "  IP: $local_ip"
echo "  Gateway: $(ip route | grep default | awk '{print $3}')"
echo "  DNS: $(resolvectl status | grep "DNS Servers" | head -1 | cut -d: -f2)"
echo "  Speed: $(ethtool eth0 2>/dev/null | grep Speed | awk '{print $2}')"
echo ""

echo "Performance Mode:"
echo "  CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "  GPU Governor: $(cat /sys/class/devfreq/gpu/governor 2>/dev/null || echo "N/A")"
echo ""

echo "Quick Commands:"
echo "  overkill-config   - Configuration menu"
echo "  overkill-update   - System updates"
echo "  overkill-logs     - View logs"
echo "  overkill-network  - Network management"
echo "  overkill-dashboard - Performance monitor"
EOF

    # Configuration tool
    cat > $OVERKILL_HOME/bin/overkill-config << 'EOF'
#!/bin/bash
# Overkill Configuration - FULL CONTROL

show_menu() {
    clear
    echo -e "\033[1;31m"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║         OVERKILL CONFIGURATION - NO LIMITS             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "\033[0m"
    echo ""
    echo "1. Network Settings (Advanced)"
    echo "2. Audio Configuration (All backends)"
    echo "3. Display & HDR Settings"
    echo "4. Overclocking Control (Edit config.txt)"
    echo "5. Thermal Management"
    echo "6. Performance Monitoring"
    echo "7. System Information"
    echo "8. Package Management"
    echo "9. Docker Services"
    echo "10. Update System"
    echo "11. Recovery Options"
    echo "12. Exit"
    echo ""
}

while true; do
    show_menu
    read -p "Choose option (1-12): " choice
    
    case $choice in
        1) overkill-network ;;
        2) pavucontrol ;;
        3) overkill-hdmi-fix ;;
        4) nano /boot/config.txt ;;
        5) systemctl status overkill-thermal ;;
        6) overkill-dashboard ;;
        7) overkill-status ;;
        8) aptitude ;;
        9) docker ps -a ;;
        10) overkill-update ;;
        11) overkill-recovery ;;
        12) echo "Returning to DOMINATION MODE"; break ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
EOF

    # Update tool
    cat > $OVERKILL_HOME/bin/overkill-update << 'EOF'
#!/bin/bash
# Overkill Update System - UNLIMITED UPGRADES

echo -e "\033[1;31m"
echo "╔════════════════════════════════════════════════════════╗"
echo "║            OVERKILL UPDATE SYSTEM                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "\033[0m"

echo "Backing up current configuration..."
cp -r /etc/overkill /etc/overkill.backup.$(date +%Y%m%d)

echo "Updating ALL packages (not just Kodi like LibreELEC)..."
apt update
apt full-upgrade -y

echo "Updating Kodi and addons..."
apt install -y kodi kodi-* || true

echo "Updating Docker images..."
docker images | grep -v REPOSITORY | awk '{print $1":"$2}' | xargs -I {} docker pull {} 2>/dev/null || true

echo "Updating Python packages..."
pip3 install --upgrade pip
pip3 list --outdated | cut -d' ' -f1 | tail -n +3 | xargs -I {} pip3 install --upgrade {} 2>/dev/null || true

echo "Cleaning up..."
apt autoremove -y
apt autoclean
docker system prune -f

echo "UPDATE COMPLETE - MAXIMUM OVERKILL MAINTAINED"
EOF

    # Log viewer
    cat > $OVERKILL_HOME/bin/overkill-logs << 'EOF'
#!/bin/bash
# Overkill Log Viewer - Complete system logs

case "${1:-menu}" in
    "kodi")
        echo "=== KODI LOGS ==="
        tail -f /home/overkill/.kodi/temp/kodi.log
        ;;
    "system")
        echo "=== OVERKILL SYSTEM LOGS ==="
        journalctl -u overkill -f
        ;;
    "thermal")
        echo "=== THERMAL LOGS ==="
        tail -f /var/log/overkill/thermal.log
        ;;
    "kernel")
        echo "=== KERNEL LOGS ==="
        dmesg -wH
        ;;
    "all")
        echo "=== ALL LOGS ==="
        journalctl -f
        ;;
    *)
        echo "Overkill Log Viewer"
        echo "Usage: overkill-logs [kodi|system|thermal|kernel|all]"
        echo ""
        echo "1. Kodi logs"
        echo "2. System logs"
        echo "3. Thermal logs"
        echo "4. Kernel logs"
        echo "5. All logs"
        read -p "Choice: " choice
        case $choice in
            1) $0 kodi ;;
            2) $0 system ;;
            3) $0 thermal ;;
            4) $0 kernel ;;
            5) $0 all ;;
        esac
        ;;
esac
EOF

    # Make all tools executable
    chmod +x $OVERKILL_HOME/bin/overkill-{status,config,update,logs}
    
    # Create global links
    for tool in status config update logs; do
        ln -sf $OVERKILL_HOME/bin/overkill-$tool /usr/local/bin/overkill-$tool
    done
    
    log "Complete management tools created"
}

create_overkill_dashboard() {
    section "CREATING PERFORMANCE DASHBOARD"
    
    log "Building real-time monitoring system..."
    
    cat > /usr/local/bin/overkill-dashboard << 'EOF'
#!/bin/bash
# Overkill Performance Dashboard - Real-time system monitoring

while true; do
    clear
    echo -e "\033[1;31m╔══════════════════ OVERKILL PERFORMANCE MONITOR ═══════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m"
    
    # CPU info
    CPU_FREQ=$(vcgencmd measure_clock arm | cut -d= -f2)
    CPU_TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "\033[1;31m║\033[0m CPU: \033[1;32m$(echo "scale=1; $CPU_FREQ/1000000000" | bc) GHz\033[0m @ \033[1;33m$CPU_TEMP\033[0m [\033[1;36m$CPU_USAGE%\033[0m]"
    
    # GPU info
    GPU_FREQ=$(vcgencmd measure_clock v3d | cut -d= -f2)
    echo -e "\033[1;31m║\033[0m GPU: \033[1;32m$(echo "scale=0; $GPU_FREQ/1000000" | bc) MHz\033[0m"
    
    # Memory
    MEM_INFO=$(free -h | awk '/^Mem:/ {print $3 " / " $2 " (" int($3/$2*100) "%)"}')
    echo -e "\033[1;31m║\033[0m RAM: \033[1;35m$MEM_INFO\033[0m"
    
    # NVMe
    if command -v nvme &>/dev/null; then
        NVME_TEMP=$(nvme smart-log /dev/nvme0 2>/dev/null | grep -i temperature | head -1 | awk '{print $3}')
        [[ -n "$NVME_TEMP" ]] && echo -e "\033[1;31m║\033[0m NVMe: \033[1;33m${NVME_TEMP}°C\033[0m"
    fi
    
    # Network
    NET_RX=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null || echo 0)
    NET_TX=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null || echo 0)
    
    # Fan speed
    if [[ -f /sys/class/thermal/cooling_device0/cur_state ]]; then
        FAN_STATE=$(cat /sys/class/thermal/cooling_device0/cur_state)
        echo -e "\033[1;31m║\033[0m Fan: \033[1;34mLevel $FAN_STATE\033[0m"
    fi
    
    # Voltage
    VOLTAGE=$(vcgencmd measure_volts | cut -d= -f2)
    echo -e "\033[1;31m║\033[0m Core: \033[1;33m$VOLTAGE\033[0m"
    
    # Throttling check
    THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)
    if [[ "$THROTTLED" != "0x0" ]]; then
        echo -e "\033[1;31m║ ⚠️  THROTTLING DETECTED: $THROTTLED\033[0m"
    fi
    
    echo -e "\033[1;31m║\033[0m"
    echo -e "\033[1;31m╚═══════════════════════════════════════════════════════════════════╝\033[0m"
    sleep 1
done
EOF

    chmod +x /usr/local/bin/overkill-dashboard
    ln -sf /usr/local/bin/overkill-dashboard $OVERKILL_HOME/bin/overkill-dashboard
    
    log "Performance dashboard created"
}

create_recovery_mode() {
    section "CREATING RECOVERY SYSTEM"
    
    log "Building advanced recovery mode..."
    
    # Recovery script
    cat > /usr/local/bin/overkill-recovery << 'EOF'
#!/bin/bash
# Overkill Recovery Mode

echo "OVERKILL RECOVERY MODE"
echo "====================="
echo ""
echo "1. Reset to safe defaults (Revert hardware/kernel settings)"
echo "2. Disable overclocking only"
echo "3. Reset Kodi configuration"
echo "4. Repair system packages"
echo "5. Check filesystem"
echo "6. Exit"
echo ""
read -p "Choice: " choice

case $choice in
    1)
        echo "Resetting to safe defaults..."
        [[ -f /boot/config.txt.pre-overkill ]] && cp /boot/config.txt.pre-overkill /boot/config.txt
        [[ -f /boot/armbianEnv.txt.pre-overkill ]] && cp /boot/armbianEnv.txt.pre-overkill /boot/armbianEnv.txt
        rm -f /etc/sysctl.d/99-overkill-extreme.conf
        echo "Reset complete - reboot required"
        ;;
    2)
        echo "Disabling overclocking..."
        sed -i 's/^arm_freq=.*/#arm_freq=2400/' /boot/config.txt
        sed -i 's/^gpu_freq=.*/#gpu_freq=800/' /boot/config.txt
        sed -i 's/^over_voltage=.*/#over_voltage=0/' /boot/config.txt
        echo "Overclocking disabled - reboot required"
        ;;
    3)
        echo "Resetting Kodi..."
        systemctl stop overkill
        mv /home/overkill/.kodi /home/overkill/.kodi.backup.$(date +%Y%m%d-%H%M%S)
        echo "Kodi settings have been backed up and reset."
        echo "A new default configuration will be created on next start."
        ;;
    4)
        echo "Repairing packages..."
        apt update
        apt --fix-broken install
        apt autoremove -y
        ;;
    5)
        echo "Checking NVMe filesystem..."
        fsck -f /dev/nvme0n1p1 # Assumes standard partition, adjust if necessary
        ;;
    6)
        exit 0
        ;;
esac
EOF

    chmod +x /usr/local/bin/overkill-recovery
    ln -sf /usr/local/bin/overkill-recovery $OVERKILL_HOME/bin/overkill-recovery
    
    log "Recovery system created"
}

install_extras() {
    section "INSTALLING EXTRA SERVICES (DOCKER)"
    
    log "Configuring optional Docker services..."
    
    # Docker containers
    systemctl enable --now docker
    
    # Create docker compose for media stack
    cat > /opt/overkill/docker-compose.yml << 'EOF'
version: '3.8'
services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: overkill-jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    volumes:
      - ./jellyfin-config:/config
      - /media/overkill:/media
    environment:
      - PUID=1000
      - PGID=1000
      
  transmission:
    image: linuxserver/transmission
    container_name: overkill-transmission
    restart: unless-stopped
    ports:
      - "9091:9091"
      - "51413:51413"
      - "51413:51413/udp"
    volumes:
      - ./transmission-config:/config
      - /media/overkill/downloads:/downloads
    environment:
      - PUID=1000
      - PGID=1000
      
  portainer:
    image: portainer/portainer-ce
    container_name: overkill-portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer-data:/data
EOF
    
    log "Docker Compose file created in /opt/overkill."
    info "To start these services, run 'cd /opt/overkill && docker-compose up -d'"
}

finalize_overkill() {
    section "FINALIZING OVERKILL INSTALLATION"
    
    log "Setting final permissions..."
    chown -R $OVERKILL_USER:$OVERKILL_USER /home/$OVERKILL_USER
    chown -R $OVERKILL_USER:$OVERKILL_USER /media/overkill 2>/dev/null || true
    chown -R root:root $OVERKILL_HOME
    chmod 755 $OVERKILL_HOME
    chmod -R 755 $OVERKILL_HOME/bin

    log "Enabling core services..."
    systemctl enable overkill.service
    systemctl enable overkill-thermal.service
    
    log "Creating desktop entry for compatibility..."
    mkdir -p /usr/share/applications
    cat > /usr/share/applications/overkill.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Overkill Media Center
Comment=Advanced LibreELEC Alternative - Unlimited Power
Exec=overkill
Icon=kodi
Terminal=false
Type=Application
Categories=AudioVideo;Video;Player;TV;
StartupNotify=true
Keywords=media;center;overkill;performance;unlimited;
EOF

    # First boot marker
    cat > /etc/overkill/first-boot << EOF
OVERKILL_FIRST_BOOT=false
OVERKILL_INSTALL_DATE=$(date)
OVERKILL_VERSION=$OVERKILL_VERSION
EOF

    # System info file
    cat > $OVERKILL_HOME/system-info << EOF
Overkill Media Center - Maximum Performance Media System
Version: $OVERKILL_VERSION
Installation: $(date)
Hardware: $(cat /proc/device-tree/model 2>/dev/null)
Kernel: $(uname -r)
Performance: UNLIMITED
Features:
- Full Armbian Linux system
- Complete package management
- NVMe-optimized architecture
- Advanced thermal management
- Expandable beyond media center
- Monitoring and recovery tools
- Docker and server capabilities
- Popular addon repositories pre-installed
EOF

    log "OVERKILL INSTALLATION COMPLETE"
}

main() {
    # --- Gatekeeper ---
    if [[ -z "$OVERKILL_AGREED" ]]; then
        show_disclaimer
        export OVERKILL_AGREED=true
    fi

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
        echo "Run as: sudo ./overkill-install.sh"
        exit 1
    fi
    
    # --- Start of Installation ---
    clear
    show_banner
    set_tty_font # Set readable font before displaying more output
    
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
    create_overkill_launcher
    setup_overkill_service
    configure_display_overkill
    configure_overkill_kodi
    setup_media_structure
    configure_power_overkill
    create_overkill_tools
    create_overkill_dashboard
    create_recovery_mode
    install_extras
    install_popular_addons "$INSTALL_UMBRELLA" "$INSTALL_FAP"
    finalize_overkill
    
    echo -e "\n${RED}╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║     🔥 OVERKILL INSTALLATION COMPLETE 🔥               ║"
    echo "║                                                        ║"
    echo "║         MAXIMUM PERFORMANCE MEDIA CENTER               ║"
    echo "║              ADDON REPOS PRE-INSTALLED                 ║"
    echo "╚════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${CYAN}What OVERKILL gives you:${NC}"
    echo -e "  ✓ ${WHITE}Full Linux system${NC} - Install anything you want"
    echo -e "  ✓ ${WHITE}NVMe optimized${NC} - PCIe 3.0 enabled for speed"
    echo -e "  ✓ ${WHITE}Advanced thermal${NC} - Intelligent fan control"
    echo -e "  ✓ ${WHITE}Docker support${NC} - Run servers alongside Kodi"
    echo -e "  ✓ ${WHITE}Full monitoring${NC} - Complete system visibility"
    echo -e "  ✓ ${WHITE}Popular addon repos${NC} - Pre-installed for easy setup"
    
    echo -e "\n${CYAN}ACTION REQUIRED: Install Addons from Repositories${NC}"
    echo -e "  This script installed the necessary repositories."
    echo -e "  ${YELLOW}You must now go into Kodi to install your desired addons:${NC}"
    echo -e "  1. Open Kodi"
    echo -e "  2. Go to ${WHITE}Settings -> Add-ons -> Install from repository${NC}"
    echo -e "  3. Select a repository (e.g., SlyGuy, CastagnaIT) and install video addons."
    if [[ "$INSTALL_UMBRELLA" == "true" ]]; then
        echo -e "  ☂️  ${WHITE}Umbrella Repository${NC} - Installed. Install the addon from this repo."
    fi
    if [[ "$INSTALL_FAP" == "true" ]]; then
        echo -e "  💦 ${WHITE}The Crew Repository${NC} - Installed. Cumination and others are in here."
    fi

    echo -e "\n${CYAN}Access Points:${NC}"
    echo -e "  📁 Media: ${WHITE}/media/overkill/{movies,tv,music}${NC}"
    echo -e "  🌐 Web UI: ${WHITE}http://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo -e "  🎬 Jellyfin: ${WHITE}http://$(hostname -I | awk '{print $1}'):8096${NC}"
    echo -e "  🐳 Portainer: ${WHITE}http://$(hostname -I | awk '{print $1}'):9000${NC}"
    
    echo -e "\n${RED}WARNING:${NC} ${YELLOW}Extreme overclocking applied!${NC}"
    echo -e "${YELLOW}Ensure adequate cooling for sustained operation${NC}"
    
    echo -e "\n${WHITE}Ready to experience UNLIMITED POWER?${NC}"
    read -p "Reboot now to apply all changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}ACTIVATING OVERKILL MODE...${NC}"
        sleep 3
        reboot
    else
        echo -e "${YELLOW}Manual activation required: ${WHITE}sudo reboot${NC}"
        echo -e "${RED}Your Pi 5 is ready for OVERKILL...${NC}"
    fi
}

# Execute the main function, starting the entire process
main "$@"
