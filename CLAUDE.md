# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OVERKILL is a Raspberry Pi 5 media center setup tool that applies extreme overclocking and optimizations. It's a single Bash script (`overkill-install.sh`) designed for advanced users running Armbian with NVMe storage.

## Key Commands

### Running the installer
```bash
# Basic installation
sudo bash overkill-install.sh

# With addon repositories
sudo bash overkill-install.sh --umbrella --fap

# Remote installation via curl
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi-setup/main/overkill-install.sh | sudo bash
```

### Testing changes
Since this is a system configuration script, testing requires:
- A Raspberry Pi 5 test environment
- Armbian OS with NVMe storage
- Willingness to potentially damage hardware (as per warnings)

## Architecture & Structure

### Single Script Design
The entire project is contained in `overkill-install.sh` (v2.4.2-REMOTE_AWARE), which:

1. **Validates System** - Checks for Pi 5 hardware and Armbian OS
2. **Creates User** - Sets up 'overkill' user with extensive sudo permissions
3. **Applies Overclocking** - Modifies boot configs for 2.8GHz ARM, 1GHz GPU
4. **Optimizes System** - Kernel parameters, NVMe settings, thermal management
5. **Installs Kodi** - Media center with custom configurations
6. **Optional Addons** - Can install additional repositories with flags

### Critical System Modifications
- `/boot/config.txt` - Hardware overclocking settings
- `/boot/armbianEnv.txt` - Kernel boot parameters
- `/etc/X11/` - Display server configurations
- `/opt/overkill/` - Main application directory structure

### Safety Considerations
- Always backs up config files before modification
- Requires explicit user agreement to disclaimers
- Contains hardware compatibility checks
- Implements thermal management to prevent damage

## Development Guidelines

When modifying the script:
1. Maintain the existing backup strategy for any system file modifications
2. Preserve all safety checks and warnings
3. Test thoroughly on appropriate hardware before committing
4. Keep the single-script architecture - don't split into multiple files
5. Update the VERSION variable when making changes
6. Ensure remote installation compatibility is maintained