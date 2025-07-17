"""Build Kodi from source with Pi 5 optimizations"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Dict
from datetime import datetime
from ..core.logger import logger
from ..core.utils import run_command, ensure_directory


class KodiBuilder:
    """Build Kodi from source with MAXIMUM OPTIMIZATION"""
    
    def __init__(self, build_dir: Optional[Path] = None):
        self.build_dir = build_dir or Path("/opt/overkill/build/kodi")
        self.source_dir = self.build_dir / "xbmc"
        self.install_prefix = Path("/opt/overkill/kodi")
        self.kodi_repo = "https://github.com/xbmc/xbmc.git"
        self.build_type = "Release"
        self.cpu_count = os.cpu_count() or 4
        
        # Pi 5 specific optimizations
        self.cmake_flags = {
            "CMAKE_BUILD_TYPE": self.build_type,
            "CMAKE_INSTALL_PREFIX": str(self.install_prefix),
            "CMAKE_C_FLAGS": "-march=armv8.2-a+crypto+fp16+rcpc+dotprod -mtune=cortex-a76 -O3 -pipe",
            "CMAKE_CXX_FLAGS": "-march=armv8.2-a+crypto+fp16+rcpc+dotprod -mtune=cortex-a76 -O3 -pipe",
            "ENABLE_INTERNAL_FLATBUFFERS": "ON",
            "ENABLE_INTERNAL_RapidJSON": "ON",
            "ENABLE_INTERNAL_FMT": "ON",
            "ENABLE_INTERNAL_SPDLOG": "ON",
            "ENABLE_INTERNAL_CROSSGUID": "ON",
            "ENABLE_VAAPI": "OFF",  # Not available on Pi
            "ENABLE_VDPAU": "OFF",  # Not available on Pi
            "CORE_PLATFORM_NAME": "gbm",
            "GBM_RENDER_SYSTEM": "gles",
            "ENABLE_PULSEAUDIO": "ON",
            "ENABLE_ALSA": "ON",
            "ENABLE_CEC": "ON",
            "ENABLE_BLUETOOTH": "ON",
            "ENABLE_AVAHI": "ON",
            "ENABLE_AIRTUNES": "ON",
            "ENABLE_OPTICAL": "ON",
            "ENABLE_DVDCSS": "ON"
        }
        
        # Build dependencies
        self.build_deps = [
            "autoconf", "automake", "autopoint", "gettext", "autotools-dev",
            "cmake", "curl", "default-jre", "gawk", "gcc", "g++", "cpp",
            "flatbuffers-compiler", "gdc", "gperf", "libasound2-dev",
            "libass-dev", "libavahi-client-dev", "libavahi-common-dev",
            "libbluetooth-dev", "libbluray-dev", "libbz2-dev", "libcdio-dev",
            "libcec-dev", "libp8-platform-dev", "libcrossguid-dev",
            "libcurl4-openssl-dev", "libcwiid-dev", "libdbus-1-dev",
            "libegl1-mesa-dev", "libenca-dev", "libflac-dev", "libfontconfig-dev",
            "libfmt-dev", "libfreetype6-dev", "libfribidi-dev", "libfstrcmp-dev",
            "libgbm-dev", "libgcrypt20-dev", "libgif-dev", "libgles2-mesa-dev",
            "libgl1-mesa-dev", "libglu1-mesa-dev", "libgnutls28-dev",
            "libgpg-error-dev", "libgtest-dev", "libinput-dev", "libiso9660-dev",
            "libjpeg-dev", "liblcms2-dev", "liblirc-dev", "libltdl-dev",
            "liblzo2-dev", "libmicrohttpd-dev", "libmysqlclient-dev",
            "libnfs-dev", "libogg-dev", "libomxil-bellagio-dev", "libpcre3-dev",
            "libplist-dev", "libpng-dev", "libpulse-dev", "libshairplay-dev",
            "libsmbclient-dev", "libspdlog-dev", "libsqlite3-dev", "libssl-dev",
            "libtag1-dev", "libtiff5-dev", "libtinyxml-dev", "libudev-dev",
            "libunistring-dev", "libva-dev", "libvorbis-dev", "libxkbcommon-dev",
            "libxmu-dev", "libxrandr-dev", "libxslt1-dev", "libxt-dev",
            "lsb-release", "meson", "nasm", "ninja-build", "python3-dev",
            "python3-pil", "python3-pip", "rapidjson-dev", "swig", "unzip",
            "uuid-dev", "vainfo", "wayland-protocols", "waylandpp-dev", "zip", "zlib1g-dev"
        ]
    
    def prepare_build_environment(self) -> bool:
        """Install all build dependencies"""
        logger.info("Installing Kodi build dependencies...")
        
        # Update package list
        ret, _, _ = run_command(["apt-get", "update"])
        if ret != 0:
            logger.error("Failed to update package list")
            return False
        
        # Install dependencies in chunks to avoid command line length issues
        chunk_size = 20
        for i in range(0, len(self.build_deps), chunk_size):
            chunk = self.build_deps[i:i + chunk_size]
            logger.info(f"Installing dependencies chunk {i//chunk_size + 1}...")
            
            ret, _, err = run_command(["apt-get", "install", "-y"] + chunk, timeout=600)
            if ret != 0:
                logger.error(f"Failed to install dependencies: {err}")
                # Continue anyway, some might be optional
        
        # Install Python dependencies
        python_deps = ["mako", "requests", "setuptools"]
        ret, _, _ = run_command(["pip3", "install"] + python_deps)
        
        return True
    
    def clone_or_update_source(self, branch: str = "master") -> bool:
        """Clone or update Kodi source code"""
        ensure_directory(self.build_dir)
        
        if self.source_dir.exists():
            logger.info("Updating existing Kodi source...")
            ret, _, err = run_command(["git", "pull"], cwd=self.source_dir)
            if ret != 0:
                logger.error(f"Failed to update source: {err}")
                return False
        else:
            logger.info(f"Cloning Kodi source (branch: {branch})...")
            ret, _, err = run_command([
                "git", "clone", "-b", branch, "--depth", "1",
                self.kodi_repo, str(self.source_dir)
            ], timeout=600)
            
            if ret != 0:
                logger.error(f"Failed to clone source: {err}")
                return False
        
        return True
    
    def configure_build(self) -> bool:
        """Configure Kodi build with CMake"""
        build_path = self.source_dir / "build"
        ensure_directory(build_path)
        
        # Prepare CMake arguments
        cmake_args = ["cmake"]
        for key, value in self.cmake_flags.items():
            cmake_args.append(f"-D{key}={value}")
        cmake_args.append("..")
        
        logger.info("Configuring Kodi build...")
        logger.debug(f"CMake arguments: {' '.join(cmake_args)}")
        
        ret, stdout, err = run_command(cmake_args, cwd=build_path, timeout=300)
        
        if ret != 0:
            logger.error(f"CMake configuration failed: {err}")
            return False
        
        logger.info("Build configuration complete")
        return True
    
    def build_kodi(self) -> bool:
        """Build Kodi with maximum optimization"""
        build_path = self.source_dir / "build"
        
        if not build_path.exists():
            logger.error("Build directory not found. Run configure first.")
            return False
        
        logger.info(f"Building Kodi with {self.cpu_count} parallel jobs...")
        logger.info("This will take 30-60 minutes on Pi 5...")
        
        # Create build timestamp
        start_time = datetime.now()
        
        # Build with make
        ret, _, err = run_command(
            ["make", f"-j{self.cpu_count}"],
            cwd=build_path,
            timeout=7200  # 2 hours timeout
        )
        
        if ret != 0:
            logger.error(f"Build failed: {err}")
            return False
        
        build_time = (datetime.now() - start_time).total_seconds() / 60
        logger.info(f"Build completed in {build_time:.1f} minutes")
        
        return True
    
    def install_kodi(self) -> bool:
        """Install Kodi to prefix directory"""
        build_path = self.source_dir / "build"
        
        logger.info(f"Installing Kodi to {self.install_prefix}")
        
        ret, _, err = run_command(
            ["make", "install"],
            cwd=build_path,
            timeout=300
        )
        
        if ret != 0:
            logger.error(f"Installation failed: {err}")
            return False
        
        # Create symlinks in /usr/local/bin
        self._create_symlinks()
        
        return True
    
    def _create_symlinks(self):
        """Create symlinks for easy access"""
        symlinks = {
            "/usr/local/bin/kodi": self.install_prefix / "bin/kodi",
            "/usr/local/bin/kodi-standalone": self.install_prefix / "bin/kodi-standalone"
        }
        
        for link, target in symlinks.items():
            try:
                if Path(link).exists():
                    Path(link).unlink()
                Path(link).symlink_to(target)
                logger.info(f"Created symlink: {link} -> {target}")
            except Exception as e:
                logger.warning(f"Failed to create symlink {link}: {e}")
    
    def create_systemd_service(self) -> bool:
        """Create systemd service for Kodi"""
        service_content = """[Unit]
Description=OVERKILL Kodi Media Center
After=multi-user.target network.target

[Service]
Type=simple
User=overkill
Group=overkill
Environment="HOME=/home/overkill"
Environment="DISPLAY=:0"
ExecStartPre=/bin/sh -c 'until systemctl is-active graphical.target; do sleep 1; done'
ExecStart=/usr/local/bin/kodi-standalone
Restart=on-failure
RestartSec=5
TimeoutStopSec=20

[Install]
WantedBy=graphical.target
"""
        
        service_path = Path("/etc/systemd/system/kodi.service")
        
        try:
            with open(service_path, 'w') as f:
                f.write(service_content)
            
            # Reload systemd and enable service
            run_command(["systemctl", "daemon-reload"])
            run_command(["systemctl", "enable", "kodi.service"])
            
            logger.info("Created and enabled Kodi systemd service")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create systemd service: {e}")
            return False
    
    def optimize_for_pi5(self) -> bool:
        """Apply Pi 5 specific optimizations"""
        # Create performance tweaks script
        tweaks_script = self.install_prefix / "bin/kodi-performance.sh"
        
        script_content = """#!/bin/bash
# OVERKILL Kodi Performance Tweaks

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Increase GPU memory split (requires reboot)
# This is handled by overclock module

# Disable HDMI audio if not needed (reduces load)
# amixer cset numid=3 0

# Launch Kodi with optimizations
KODI_HOME=/opt/overkill/kodi/share/kodi \\
    exec /opt/overkill/kodi/bin/kodi-standalone "$@"
"""
        
        try:
            with open(tweaks_script, 'w') as f:
                f.write(script_content)
            tweaks_script.chmod(0o755)
            
            logger.info("Created performance optimization script")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create optimization script: {e}")
            return False
    
    def full_build(self, branch: str = "master") -> bool:
        """Perform complete Kodi build from source"""
        logger.info("Starting OVERKILL Kodi build from source...")
        
        # Prepare environment
        if not self.prepare_build_environment():
            return False
        
        # Get source
        if not self.clone_or_update_source(branch):
            return False
        
        # Configure
        if not self.configure_build():
            return False
        
        # Build
        if not self.build_kodi():
            return False
        
        # Install
        if not self.install_kodi():
            return False
        
        # Create service
        if not self.create_systemd_service():
            return False
        
        # Optimize
        if not self.optimize_for_pi5():
            return False
        
        logger.info("KODI BUILD COMPLETE - MAXIMUM OPTIMIZATION ACHIEVED!")
        logger.info(f"Kodi installed to: {self.install_prefix}")
        logger.info("Start with: systemctl start kodi")
        
        return True