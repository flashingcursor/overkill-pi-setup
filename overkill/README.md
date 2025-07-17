# OVERKILL Python Configurator

Professional media center configuration tool for Raspberry Pi 5, featuring a terminal-based UI similar to raspi-config.

## Features

- **Interactive TUI**: Professional terminal interface for easy configuration
- **Hardware Detection**: Automatic Pi 5 detection and silicon quality assessment
- **Smart Overclocking**: Safe overclock profiles based on chip capability
- **Thermal Management**: Intelligent fan control and temperature monitoring
- **Kodi Integration**: Custom Kodi builds and in-app configuration
- **Modular Design**: Clean, extensible Python architecture

## Quick Start

```bash
# Download and run bootstrap script
curl -sSL https://raw.githubusercontent.com/flashingcursor/overkill-pi/main/overkill-bootstrap.sh | sudo bash

# Or clone and install locally
git clone https://github.com/flashingcursor/overkill-pi
cd overkill-pi
sudo ./overkill-bootstrap.sh

# Launch configurator
sudo overkill
```

## Requirements

- Raspberry Pi 5 (8GB recommended)
- NVMe storage (M.2 HAT)
- Armbian or Raspberry Pi OS
- Active cooling solution
- Python 3.9+

## Architecture

```
overkill/
├── core/          # Core functionality (config, logging, utils)
├── hardware/      # Hardware detection and control
├── media/         # Kodi and media services
├── ui/            # Terminal UI components
└── plugins/       # Extension system
```

## Development

```bash
# Set up development environment
python3 -m venv venv
source venv/bin/activate
pip install -e .[dev]

# Run tests
pytest

# Format code
black overkill/

# Type checking
mypy overkill/
```

## License

MIT License - See LICENSE file for details

## Warning

This tool applies aggressive optimizations that may:
- Void your warranty
- Cause system instability
- Damage hardware if cooling is inadequate

Use at your own risk!