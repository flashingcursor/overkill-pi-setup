# OVERKILL Python Architecture Design

## Overview

Transform OVERKILL from a monolithic bash script into a sophisticated Python-based configuration system with a minimal bash bootstrap, inspired by raspi-config. This approach provides better maintainability, error handling, and user experience while enabling advanced features like custom Kodi builds and in-app configuration.

## Architecture Components

### 1. Bootstrap Script (bash)
```bash
#!/bin/bash
# overkill-install.sh - Minimal bootstrap script

# Basic validation
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# Install Python and dependencies
bootstrap_python() {
    apt-get update
    apt-get install -y python3 python3-pip python3-venv git dialog
    
    # Create virtual environment
    python3 -m venv /opt/overkill/venv
    source /opt/overkill/venv/bin/activate
    
    # Install Python requirements
    pip install wheel setuptools
    pip install -r /opt/overkill/requirements.txt
}

# Download OVERKILL Python application
install_overkill() {
    git clone https://github.com/flashingcursor/overkill-pi /opt/overkill
    cd /opt/overkill
    python setup.py install
}

# Launch configuration tool
main() {
    check_root
    bootstrap_python
    install_overkill
    
    # Launch Python configurator
    /opt/overkill/venv/bin/python -m overkill.configurator
}

main "$@"
```

### 2. Python Application Structure
```
overkill/
├── setup.py
├── requirements.txt
├── overkill/
│   ├── __init__.py
│   ├── __main__.py
│   ├── configurator.py         # Main TUI application
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py          # Configuration management
│   │   ├── system.py          # System detection/info
│   │   ├── logger.py          # Logging framework
│   │   └── utils.py           # Utility functions
│   ├── hardware/
│   │   ├── __init__.py
│   │   ├── pi5.py             # Pi 5 specific functions
│   │   ├── overclock.py       # Overclocking profiles
│   │   ├── thermal.py         # Thermal management
│   │   └── storage.py         # NVMe optimization
│   ├── media/
│   │   ├── __init__.py
│   │   ├── kodi_builder.py    # Custom Kodi compilation
│   │   ├── kodi_config.py     # Kodi configuration
│   │   ├── addons.py          # Addon management
│   │   └── services.py        # Media services
│   ├── ui/
│   │   ├── __init__.py
│   │   ├── tui.py             # Terminal UI (curses)
│   │   ├── dialogs.py         # Dialog components
│   │   ├── menus.py           # Menu definitions
│   │   └── themes.py          # UI themes
│   └── plugins/               # Plugin system
│       ├── __init__.py
│       └── base.py
├── kodi-addon/
│   ├── addon.xml
│   ├── service.overkill/
│   │   ├── default.py
│   │   ├── resources/
│   │   │   ├── settings.xml
│   │   │   └── lib/
│   │   │       └── overkill_api.py
│   │   └── icon.png
└── tests/
```

### 3. Main Configurator (Python TUI)

```python
# overkill/configurator.py
import curses
from typing import Dict, List, Callable
from overkill.ui.tui import OverkillTUI
from overkill.core.system import SystemInfo
from overkill.core.config import Config

class OverkillConfigurator:
    """Main configuration application similar to raspi-config"""
    
    def __init__(self):
        self.config = Config()
        self.system = SystemInfo()
        self.tui = OverkillTUI()
        
    def main_menu(self) -> Dict[str, Callable]:
        """Define main menu structure"""
        return {
            "1 System Information": self.show_system_info,
            "2 Overclock Settings": self.configure_overclock,
            "3 Build/Update Kodi": self.build_kodi,
            "4 Media Services": self.configure_services,
            "5 Network Settings": self.configure_network,
            "6 Display Settings": self.configure_display,
            "7 Advanced Options": self.advanced_menu,
            "8 About OVERKILL": self.show_about,
            "9 Exit": self.exit_configurator
        }
    
    def show_system_info(self):
        """Display detailed system information"""
        info = self.system.get_full_info()
        self.tui.show_info_dialog(
            "System Information",
            f"""
            Model: {info['model']}
            Memory: {info['memory']}
            Storage: {info['storage']}
            Temperature: {info['temperature']}
            Kernel: {info['kernel']}
            Overclock: {info['overclock_status']}
            """
        )
    
    def configure_overclock(self):
        """Interactive overclocking configuration"""
        profiles = {
            "Safe (2.4GHz/900MHz)": "safe",
            "Balanced (2.6GHz/950MHz)": "balanced",
            "Extreme (2.8GHz/1000MHz)": "extreme",
            "Custom": "custom"
        }
        
        choice = self.tui.menu("Select Overclock Profile", profiles.keys())
        if choice:
            self.apply_overclock_profile(profiles[choice])
    
    def build_kodi(self):
        """Build Kodi from source with optimizations"""
        options = {
            "1 Build Latest Stable": self.build_kodi_stable,
            "2 Build Nightly": self.build_kodi_nightly,
            "3 Update Existing": self.update_kodi,
            "4 Configure Build Options": self.configure_build_options
        }
        
        choice = self.tui.menu("Kodi Build Options", options.keys())
        if choice:
            options[choice]()
```

### 4. Kodi Builder Module

```python
# overkill/media/kodi_builder.py
import os
import subprocess
from pathlib import Path
from overkill.core.logger import logger

class KodiBuilder:
    """Build Kodi from source with Pi 5 optimizations"""
    
    def __init__(self, config):
        self.config = config
        self.build_dir = Path("/opt/overkill/build/kodi")
        self.install_prefix = Path("/opt/overkill/kodi")
        
    def prepare_build_environment(self):
        """Install build dependencies"""
        deps = [
            "build-essential", "cmake", "git", "python3-dev",
            "libgl1-mesa-dev", "libgles2-mesa-dev", "libgbm-dev",
            "libdrm-dev", "libegl1-mesa-dev", "libavahi-client-dev",
            # ... comprehensive dependency list
        ]
        
        logger.info("Installing build dependencies...")
        subprocess.run(["apt-get", "install", "-y"] + deps, check=True)
        
    def clone_repository(self, branch="master"):
        """Clone Kodi repository"""
        repo_url = "https://github.com/xbmc/xbmc.git"
        
        if self.build_dir.exists():
            logger.info("Updating existing repository...")
            subprocess.run(["git", "pull"], cwd=self.build_dir, check=True)
        else:
            logger.info(f"Cloning Kodi repository (branch: {branch})...")
            subprocess.run([
                "git", "clone", "-b", branch, "--depth", "1",
                repo_url, str(self.build_dir)
            ], check=True)
    
    def configure_build(self):
        """Configure build with Pi 5 optimizations"""
        cmake_args = [
            f"-DCMAKE_INSTALL_PREFIX={self.install_prefix}",
            "-DENABLE_INTERNAL_FLATBUFFERS=ON",
            "-DENABLE_INTERNAL_RapidJSON=ON",
            "-DENABLE_VAAPI=OFF",
            "-DENABLE_VDPAU=OFF",
            "-DCORE_PLATFORM_NAME=gbm",
            "-DGBM_RENDER_SYSTEM=gles",
            "-DENABLE_PULSEAUDIO=ON",
            # Pi 5 specific optimizations
            "-DCMAKE_CXX_FLAGS='-march=armv8.2-a+crypto+fp16+rcpc+dotprod -mtune=cortex-a76'",
            "-DCMAKE_C_FLAGS='-march=armv8.2-a+crypto+fp16+rcpc+dotprod -mtune=cortex-a76'",
        ]
        
        build_path = self.build_dir / "build"
        build_path.mkdir(exist_ok=True)
        
        logger.info("Configuring build...")
        subprocess.run(
            ["cmake"] + cmake_args + [".."],
            cwd=build_path,
            check=True
        )
    
    def build_and_install(self, jobs=4):
        """Build and install Kodi"""
        build_path = self.build_dir / "build"
        
        logger.info(f"Building Kodi with {jobs} parallel jobs...")
        subprocess.run(["make", f"-j{jobs}"], cwd=build_path, check=True)
        
        logger.info("Installing Kodi...")
        subprocess.run(["make", "install"], cwd=build_path, check=True)
        
        self.create_systemd_service()
        self.install_overkill_addon()
```

### 5. Kodi Addon Structure

```python
# kodi-addon/service.overkill/default.py
import xbmc
import xbmcaddon
import xbmcgui
from resources.lib.overkill_api import OverkillAPI

class OverkillService:
    """Kodi service addon for OVERKILL configuration"""
    
    def __init__(self):
        self.addon = xbmcaddon.Addon()
        self.api = OverkillAPI()
        self.monitor = xbmc.Monitor()
        
    def run(self):
        """Main service loop"""
        xbmc.log("OVERKILL Service: Starting", xbmc.LOGINFO)
        
        while not self.monitor.abortRequested():
            # Monitor system temperature
            temp = self.api.get_temperature()
            if temp > 75:
                self.show_temp_warning(temp)
            
            # Check for configuration updates
            if self.api.config_changed():
                self.apply_runtime_changes()
            
            if self.monitor.waitForAbort(10):
                break
        
        xbmc.log("OVERKILL Service: Stopped", xbmc.LOGINFO)
    
    def show_settings(self):
        """Show OVERKILL settings within Kodi"""
        dialog = xbmcgui.Dialog()
        
        options = [
            "System Information",
            "Overclock Profile",
            "Fan Control",
            "Performance Monitor",
            "Network Optimization",
            "Advanced Settings"
        ]
        
        selection = dialog.select("OVERKILL Configuration", options)
        
        if selection == 0:
            self.show_system_info()
        elif selection == 1:
            self.configure_overclock()
        # ... handle other options
```

### 6. Configuration Management

```python
# overkill/core/config.py
import json
import os
from pathlib import Path
from typing import Dict, Any

class Config:
    """Centralized configuration management"""
    
    def __init__(self):
        self.config_dir = Path("/etc/overkill")
        self.config_file = self.config_dir / "config.json"
        self.defaults = {
            "version": "3.0.0",
            "profile": "balanced",
            "hardware": {
                "overclock": {
                    "arm_freq": 2600,
                    "gpu_freq": 950,
                    "over_voltage": 4
                },
                "thermal": {
                    "fan_mode": "auto",
                    "target_temp": 65
                }
            },
            "media": {
                "kodi": {
                    "version": "stable",
                    "addons": ["inputstream.adaptive", "pvr.iptvsimple"],
                    "cache_size": 524288000
                },
                "services": {
                    "samba": True,
                    "dlna": True,
                    "airplay": False
                }
            },
            "network": {
                "wifi_country": "US",
                "performance_mode": True
            }
        }
        
        self.load()
    
    def load(self):
        """Load configuration from file"""
        if self.config_file.exists():
            with open(self.config_file) as f:
                self._config = json.load(f)
        else:
            self._config = self.defaults.copy()
            self.save()
    
    def save(self):
        """Save configuration to file"""
        self.config_dir.mkdir(parents=True, exist_ok=True)
        with open(self.config_file, 'w') as f:
            json.dump(self._config, f, indent=2)
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value with dot notation support"""
        keys = key.split('.')
        value = self._config
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    
    def set(self, key: str, value: Any):
        """Set configuration value with dot notation support"""
        keys = key.split('.')
        config = self._config
        
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        
        config[keys[-1]] = value
        self.save()
```

### 7. System Detection and Hardware Profiles

```python
# overkill/hardware/pi5.py
import subprocess
import re
from typing import Dict, Optional

class Pi5Hardware:
    """Raspberry Pi 5 hardware detection and profiling"""
    
    def __init__(self):
        self.model = self.detect_model()
        self.revision = self.detect_revision()
        self.memory = self.detect_memory()
        self.silicon_grade = None
        
    def detect_model(self) -> str:
        """Detect Pi model"""
        try:
            with open('/proc/device-tree/model', 'r') as f:
                return f.read().strip()
        except:
            return "Unknown"
    
    def detect_silicon_quality(self) -> str:
        """Test silicon quality through stress testing"""
        test_profiles = [
            {"name": "extreme", "arm": 2800, "gpu": 1000, "voltage": 5},
            {"name": "high", "arm": 2700, "gpu": 975, "voltage": 4},
            {"name": "balanced", "arm": 2600, "gpu": 950, "voltage": 3},
            {"name": "safe", "arm": 2400, "gpu": 900, "voltage": 2}
        ]
        
        for profile in test_profiles:
            if self.stress_test(profile):
                self.silicon_grade = profile["name"]
                return profile["name"]
        
        return "conservative"
    
    def stress_test(self, profile: Dict) -> bool:
        """Run stress test with given profile"""
        # Apply temporary overclock
        self.apply_test_overclock(profile)
        
        try:
            # Run stress test
            result = subprocess.run([
                "stress-ng",
                "--cpu", "8",
                "--cpu-method", "all",
                "--verify",
                "--timeout", "60s"
            ], capture_output=True, timeout=70)
            
            # Check temperature didn't exceed limits
            max_temp = self.get_max_temp_during_test()
            
            return result.returncode == 0 and max_temp < 80
            
        except subprocess.TimeoutExpired:
            return False
        finally:
            # Restore default settings
            self.restore_default_overclock()
```

### 8. Terminal UI Framework

```python
# overkill/ui/tui.py
import curses
from typing import List, Optional, Callable

class OverkillTUI:
    """Terminal User Interface using curses"""
    
    def __init__(self):
        self.stdscr = None
        
    def run(self, main_func: Callable):
        """Run TUI application"""
        curses.wrapper(self._run, main_func)
    
    def _run(self, stdscr, main_func):
        self.stdscr = stdscr
        
        # Configure curses
        curses.curs_set(0)
        stdscr.keypad(True)
        
        # Initialize color pairs
        curses.init_pair(1, curses.COLOR_RED, curses.COLOR_BLACK)
        curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)
        curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)
        
        main_func(self)
    
    def draw_header(self):
        """Draw OVERKILL header"""
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()
        
        # ASCII art header
        header = [
            "        ....            _                                       ..         .          ..       .. ",
            "    .x~X88888Hx.       u                                  < .z@8\"`        @88>  x .d88\"  x .d88\"  ",
            "   H8X 888888888h.    88Nu.   u.                .u    .    !@88E          %8P    5888R    5888R   ",
            "  8888:`*888888888:  '88888.o888c      .u     .d88B :@8c   '888E   u       .     '888R    '888R   ",
            "  88888:        `%8   ^8888  8888   ud8888.  =\"8888f8888r   888E u@8NL   .@88u    888R     888R   ",
            ". `88888          ?>   8888  8888 :888'8888.   4888>'88\"    888E`\"88*\"  ''888E`   888R     888R   ",
            "`. ?888%           X   8888  8888 d888 '88%\"   4888> '      888E .dN.     888E    888R     888R   ",
            "  ~*??.            >   8888  8888 8888.+\"      4888>        888E~8888     888E    888R     888R   ",
            " .x88888h.        <   .8888b.888P 8888L       .d888L .+     888E '888&    888E    888R     888R   ",
            ":\"\"\"8888888x..  .x     ^Y8888*\"\"  '8888c. .+  ^\"8888*\"      888E  9888.   888&   .888B .  .888B . ",
            "`    `*888888888\"        `Y\"       \"88888%       \"Y\"      '\"888*\" 4888\"   R888\"  ^*888%   ^*888%  ",
            "        \"\"***\"\"                      \"YP'                    \"\"    \"\"      \"\"      \"%       \"%    "
        ]
        
        start_y = 1
        for line in header:
            start_x = (width - len(line)) // 2
            self.stdscr.attron(curses.color_pair(1))
            self.stdscr.addstr(start_y, start_x, line)
            self.stdscr.attroff(curses.color_pair(1))
            start_y += 1
        
        # Subtitle
        subtitle = "Raspberry Pi 5 Media Center Configuration"
        self.stdscr.attron(curses.color_pair(4))
        self.stdscr.addstr(start_y + 1, (width - len(subtitle)) // 2, subtitle)
        self.stdscr.attroff(curses.color_pair(4))
    
    def menu(self, title: str, options: List[str]) -> Optional[str]:
        """Display menu and get selection"""
        self.draw_header()
        
        height, width = self.stdscr.getmaxyx()
        menu_height = len(options) + 4
        menu_width = max(len(title), max(len(opt) for opt in options)) + 10
        
        # Calculate position
        start_y = (height - menu_height) // 2
        start_x = (width - menu_width) // 2
        
        # Draw menu box
        self.draw_box(start_y, start_x, menu_height, menu_width)
        
        # Draw title
        self.stdscr.attron(curses.A_BOLD)
        self.stdscr.addstr(start_y + 1, start_x + 2, title)
        self.stdscr.attroff(curses.A_BOLD)
        
        # Draw options
        current_option = 0
        
        while True:
            for idx, option in enumerate(options):
                y = start_y + 3 + idx
                x = start_x + 2
                
                if idx == current_option:
                    self.stdscr.attron(curses.A_REVERSE)
                    self.stdscr.addstr(y, x, f"> {option}")
                    self.stdscr.attroff(curses.A_REVERSE)
                else:
                    self.stdscr.addstr(y, x, f"  {option}")
            
            key = self.stdscr.getch()
            
            if key == curses.KEY_UP:
                current_option = (current_option - 1) % len(options)
            elif key == curses.KEY_DOWN:
                current_option = (current_option + 1) % len(options)
            elif key == ord('\n'):
                return options[current_option]
            elif key == 27:  # ESC
                return None
```

## Key Advantages

### 1. **Maintainability**
- Clean Python codebase with proper structure
- Modular design with clear separation of concerns
- Comprehensive error handling and logging
- Easy to test and debug

### 2. **User Experience**
- Professional TUI interface like raspi-config
- Interactive configuration with immediate feedback
- In-Kodi configuration through addon
- Progress indicators for long operations

### 3. **Advanced Features**
- Custom Kodi builds with Pi 5 optimizations
- Silicon quality detection for safe overclocking
- Runtime configuration changes
- Plugin system for extensibility

### 4. **Safety & Reliability**
- Automatic backups before changes
- Rollback capabilities
- Hardware validation
- Temperature monitoring

### 5. **Performance**
- Optimized Kodi build for Pi 5
- Dynamic overclocking based on silicon quality
- Intelligent thermal management
- Memory and I/O optimizations

## Implementation Timeline

### Phase 1: Core Framework (Week 1)
- Bash bootstrap script
- Python application structure
- Basic TUI framework
- Configuration management

### Phase 2: Hardware Integration (Week 2)
- Pi 5 detection and profiling
- Overclock management
- Thermal control
- System optimization

### Phase 3: Kodi Integration (Week 3-4)
- Kodi build system
- Custom compilation with optimizations
- Basic addon development
- Service management

### Phase 4: Advanced Features (Week 5-6)
- Complete TUI implementation
- Kodi addon with full features
- Plugin system
- Network services

### Phase 5: Polish & Testing (Week 7-8)
- Comprehensive testing
- Documentation
- Performance optimization
- Release preparation

## Conclusion

This Python-based architecture provides a professional, maintainable, and feature-rich solution that transforms the Raspberry Pi 5 into an ultimate media center. The combination of a robust configuration tool and integrated Kodi addon ensures users can easily optimize their system while maintaining the "OVERKILL" philosophy of maximum performance.