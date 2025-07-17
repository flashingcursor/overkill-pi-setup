# OVERKILL Installation Guide

## Quick Install

For a fresh Raspberry Pi 5 with Armbian:

```bash
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi/main/overkill-bootstrap.sh | sudo bash
```

## Prerequisites

- Raspberry Pi 5 (8GB recommended)
- NVMe storage with M.2 HAT
- Active cooling solution (fan or heatsink with fan)
- Armbian or Raspberry Pi OS (64-bit)
- Internet connection

## Manual Installation

### 1. Clone the Repository

```bash
git clone https://github.com/flashingcursor/overkill-pi
cd overkill-pi
```

### 2. Run Bootstrap Script

```bash
sudo ./overkill-bootstrap.sh
```

The bootstrap script will:
- Check system compatibility
- Install Python 3 and dependencies
- Create virtual environment
- Install OVERKILL Python package
- Create launcher script

### 3. Launch Configurator

```bash
sudo overkill
```

## First Run Configuration

1. **System Check**: OVERKILL will verify your hardware meets requirements
2. **Main Menu**: Navigate using arrow keys, Enter to select, ESC to go back
3. **Recommended Steps**:
   - View System Information to confirm hardware detection
   - Configure Thermal Management first
   - Select appropriate Overclock Profile
   - Configure Media Services as needed

## Overclock Profiles

| Profile | ARM Freq | GPU Freq | Voltage | Cooling Required |
|---------|----------|----------|---------|------------------|
| Safe | 2.4 GHz | 900 MHz | +2 | Passive |
| Balanced | 2.6 GHz | 950 MHz | +3 | Active (small) |
| Performance | 2.7 GHz | 975 MHz | +4 | Active (medium) |
| Extreme | 2.8 GHz | 1.0 GHz | +5 | Active (large) |

## Kodi Integration

### Installing the Kodi Addon

1. Copy addon to Kodi directory:
```bash
sudo cp -r /opt/overkill/kodi-addon/service.overkill /home/overkill/.kodi/addons/
```

2. Launch Kodi and enable the addon:
   - Settings → Add-ons → My add-ons → Services
   - Find "OVERKILL Configuration" and enable

3. Access OVERKILL from within Kodi:
   - Settings → Add-ons → My add-ons → Program add-ons → OVERKILL Configuration

## Configuration Files

OVERKILL stores configuration in:
- `/etc/overkill/config.json` - Main configuration
- `/etc/overkill/profiles.yaml` - Overclock profiles
- `/var/log/overkill/` - Log files

## Troubleshooting

### System Won't Boot After Overclock

1. Remove SD card/NVMe and mount on another system
2. Edit `/boot/config.txt` and remove OVERKILL section
3. Boot and run `sudo overkill` to select a lower profile

### High Temperatures

1. Check fan is connected and working
2. Select a lower overclock profile
3. Improve case ventilation
4. Check thermal paste application

### Kodi Addon Not Working

1. Check OVERKILL service is running:
```bash
sudo systemctl status overkill-api
```

2. Check Kodi logs:
```bash
tail -f /home/overkill/.kodi/temp/kodi.log
```

## Uninstallation

To completely remove OVERKILL:

```bash
# Stop services
sudo systemctl stop overkill-thermal
sudo systemctl stop overkill-api

# Disable services
sudo systemctl disable overkill-thermal
sudo systemctl disable overkill-api

# Remove files
sudo rm -rf /opt/overkill
sudo rm -rf /etc/overkill
sudo rm -f /usr/local/bin/overkill
sudo rm -f /usr/local/bin/overkill-fancontrol

# Remove Kodi addon
rm -rf ~/.kodi/addons/service.overkill

# Restore original config.txt
sudo cp /boot/config.txt.pre-overkill /boot/config.txt
```

## Support

- GitHub Issues: https://github.com/flashingcursor/overkill-pi/issues
- Discussions: https://github.com/flashingcursor/overkill-pi/discussions

## Safety Warning

⚠️ **IMPORTANT**: Overclocking can cause:
- System instability
- Data corruption
- Hardware damage
- Voided warranty

Always ensure adequate cooling and monitor temperatures!