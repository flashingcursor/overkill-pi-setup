#!/usr/bin/env python3
"""Main OVERKILL configurator application"""

import sys
import os
from typing import Optional
import click
from .ui.tui import OverkillTUI
from .core.config import Config
from .core.system import get_system_detector, get_system_info
from .core.logger import logger, setup_logging
from .core.utils import is_root, format_bytes
from .media.addon_manager import AddonManager


class OverkillConfigurator:
    """Main configuration application"""
    
    def __init__(self):
        self.config = Config()
        self.system = get_system_detector()
        self.tui = OverkillTUI()
        self.addon_manager = AddonManager()
        self.running = True
        
    def main_menu(self):
        """Main menu options"""
        return [
            "System Information",
            "Overclock Settings",
            "Thermal Management", 
            "Media Services",
            "Network Settings",
            "Display Settings",
            "Advanced Options",
            "About OVERKILL",
            "Exit"
        ]
    
    def show_system_info(self):
        """Display detailed system information"""
        info = get_system_info()
        
        # Format system information
        lines = [
            f"Model: {info.model}",
            f"CPU: {info.cpu}",
            f"Memory: {info.memory_gb:.1f} GB",
            f"Kernel: {info.kernel}",
            f"OS: {info.os_name} {info.os_version[:50]}...",
            "",
            "Storage Devices:"
        ]
        
        # Add storage info
        for device in info.storage_devices[:3]:  # Limit to 3 devices
            lines.append(f"  {device['device']}: {device['total_gb']:.1f}GB "
                        f"({device['percent']:.1f}% used)")
        
        # Add NVMe info
        if info.nvme_devices:
            lines.append("")
            lines.append("NVMe Devices:")
            for nvme in info.nvme_devices:
                lines.append(f"  {nvme}")
        
        # Add temperature
        if info.temperature:
            lines.append("")
            lines.append(f"Temperature: {info.temperature:.1f}°C")
        
        # Add frequency info
        if info.cpu_freq:
            lines.append(f"CPU Frequency: {info.cpu_freq['current']:.0f} MHz")
        if info.gpu_freq:
            lines.append(f"GPU Frequency: {info.gpu_freq} MHz")
        
        # Check overclock status
        current_profile = self.config.get("overclock.current_profile", "none")
        lines.append("")
        lines.append(f"Overclock Profile: {current_profile}")
        
        # Silicon grade
        silicon_grade = self.config.get("hardware.silicon_grade", "unknown")
        lines.append(f"Silicon Grade: {silicon_grade}")
        
        message = "\n".join(lines)
        self.tui.show_info("System Information", message)
    
    def configure_overclock(self):
        """Overclock configuration menu"""
        profiles = self.config.get_all_profiles()
        current = self.config.get("overclock.current_profile", "safe")
        
        menu_items = []
        for name, profile in profiles.items():
            indicator = " (current)" if name == current else ""
            menu_items.append(
                f"{profile.name}: {profile.arm_freq}MHz/{profile.gpu_freq}MHz"
                f"{indicator}"
            )
        
        menu_items.extend([
            "Test Silicon Quality",
            "Create Custom Profile",
            "Back"
        ])
        
        while True:
            choice = self.tui.menu("Overclock Settings", menu_items)
            
            if choice is None or choice == len(menu_items) - 1:
                break
            elif choice < len(profiles):
                # Select a profile
                profile_name = list(profiles.keys())[choice]
                if self.apply_overclock_profile(profile_name):
                    self.tui.show_success("Success", 
                        f"Applied {profile_name} overclock profile\n"
                        "Reboot required to take effect")
                    break
            elif choice == len(profiles):
                # Test silicon quality
                self.test_silicon_quality()
            elif choice == len(profiles) + 1:
                # Create custom profile
                self.create_custom_profile()
    
    def apply_overclock_profile(self, profile_name: str) -> bool:
        """Apply an overclock profile"""
        profile = self.config.get_profile(profile_name)
        if not profile:
            self.tui.show_error("Error", f"Profile {profile_name} not found")
            return False
        
        # Here we would apply the actual overclock settings
        # For now, just update the config
        self.config.set("overclock.enabled", True)
        self.config.set("overclock.current_profile", profile_name)
        
        logger.info(f"Applied overclock profile: {profile_name}")
        return True
    
    def test_silicon_quality(self):
        """Test silicon quality (placeholder)"""
        self.tui.show_info("Silicon Testing", 
            "Silicon quality testing will:\n"
            "1. Apply temporary overclock settings\n"
            "2. Run stress tests for stability\n"
            "3. Monitor temperatures\n"
            "4. Determine safe overclock levels\n\n"
            "This feature is not yet implemented")
    
    def create_custom_profile(self):
        """Create custom overclock profile (placeholder)"""
        self.tui.show_info("Custom Profile", 
            "Custom profile creation allows you to:\n"
            "- Set specific ARM frequency\n"
            "- Set specific GPU frequency\n"
            "- Adjust voltage settings\n"
            "- Save with a custom name\n\n"
            "This feature is not yet implemented")
    
    def configure_thermal(self):
        """Thermal management configuration"""
        menu_items = [
            "Fan Control Mode",
            "Temperature Targets",
            "Fan Curve Editor",
            "View Current Status",
            "Back"
        ]
        
        while True:
            choice = self.tui.menu("Thermal Management", menu_items)
            
            if choice is None or choice == len(menu_items) - 1:
                break
            elif choice == 0:
                self.configure_fan_mode()
            elif choice == 1:
                self.configure_temp_targets()
            elif choice == 2:
                self.edit_fan_curve()
            elif choice == 3:
                self.show_thermal_status()
    
    def configure_fan_mode(self):
        """Configure fan control mode"""
        modes = ["Auto", "Manual", "Aggressive", "Silent"]
        current = self.config.get("thermal.fan_mode", "auto")
        
        # Find current mode index
        current_idx = 0
        for i, mode in enumerate(modes):
            if mode.lower() == current.lower():
                current_idx = i
                break
        
        choice = self.tui.menu("Select Fan Mode", modes, selected=current_idx)
        if choice is not None:
            self.config.set("thermal.fan_mode", modes[choice].lower())
            self.tui.show_success("Success", f"Fan mode set to {modes[choice]}")
    
    def configure_temp_targets(self):
        """Configure temperature targets (placeholder)"""
        current_target = self.config.get("thermal.target_temp", 65)
        current_max = self.config.get("thermal.max_temp", 80)
        
        self.tui.show_info("Temperature Targets",
            f"Current Settings:\n"
            f"Target Temperature: {current_target}°C\n"
            f"Maximum Temperature: {current_max}°C\n\n"
            "Temperature adjustment not yet implemented")
    
    def edit_fan_curve(self):
        """Edit fan curve (placeholder)"""
        self.tui.show_info("Fan Curve Editor",
            "Fan curve editing allows precise control\n"
            "over fan speed at different temperatures.\n\n"
            "This feature is not yet implemented")
    
    def show_thermal_status(self):
        """Show current thermal status"""
        info = get_system_info()
        temp = info.temperature or 0
        
        # Determine fan speed (placeholder)
        fan_speed = "Unknown"
        if temp < 50:
            fan_speed = "Low"
        elif temp < 65:
            fan_speed = "Medium"
        else:
            fan_speed = "High"
        
        self.tui.show_info("Thermal Status",
            f"Current Temperature: {temp:.1f}°C\n"
            f"Fan Speed: {fan_speed}\n"
            f"Fan Mode: {self.config.get('thermal.fan_mode', 'auto')}")
    
    def configure_media_services(self):
        """Media services configuration"""
        menu_items = [
            "Kodi Settings",
            "Addon Repositories",
            "Network Shares (Samba)",
            "DLNA Server",
            "AirPlay Support",
            "Bluetooth Audio",
            "Back"
        ]
        
        while True:
            choice = self.tui.menu("Media Services", menu_items)
            
            if choice is None or choice == len(menu_items) - 1:
                break
            elif choice == 0:
                self.configure_kodi_settings()
            elif choice == 1:
                self.manage_addon_repositories()
            else:
                self.tui.show_info("Coming Soon",
                    f"{menu_items[choice]} configuration\n"
                    "is not yet implemented")
    
    def configure_kodi_settings(self):
        """Configure Kodi-specific settings"""
        self.tui.show_info("Kodi Settings",
            "Kodi configuration includes:\n"
            "- Performance settings\n"
            "- Cache optimization\n"
            "- Audio/Video settings\n"
            "- Library management\n\n"
            "Not yet implemented")
    
    def manage_addon_repositories(self):
        """Manage Kodi addon repositories"""
        # Check if Kodi is installed
        if not self.addon_manager.check_kodi_installed():
            self.tui.show_warning("Kodi Not Found",
                "Kodi installation not detected.\n"
                "Please install Kodi first.")
            return
        
        while True:
            # Get repository status
            installed_repos = self.addon_manager.get_installed_repositories()
            
            menu_items = []
            
            # Premium repositories (what was --umbrella and --fap)
            menu_items.append("═══ PREMIUM REPOSITORIES ═══")
            
            # Umbrella
            umbrella_status = " [INSTALLED]" if "umbrella" in installed_repos else ""
            menu_items.append(f"Umbrella Repository{umbrella_status}")
            
            # FEN/Seren pack
            fap_status = " [INSTALLED]" if "fap" in installed_repos else ""
            menu_items.append(f"FEN/Seren Addon Pack{fap_status}")
            
            menu_items.append("═══ OTHER REPOSITORIES ═══")
            
            # Other repos
            for repo_name in ["crew", "numbers", "shadow", "rising_tides"]:
                repo_info = self.addon_manager.get_repository_info(repo_name)
                if repo_info:
                    status = " [INSTALLED]" if repo_info["installed"] else ""
                    menu_items.append(f"{repo_info['name']}{status}")
            
            menu_items.extend([
                "═══ MANAGEMENT ═══",
                "Install Essential Addons",
                "Configure Real-Debrid",
                "Update All Repositories",
                "Back"
            ])
            
            choice = self.tui.menu("Addon Repository Management", menu_items)
            
            if choice is None or choice == len(menu_items) - 1:
                break
            elif choice == 1:  # Umbrella
                self.install_repository("umbrella")
            elif choice == 2:  # FEN/Seren
                self.install_repository("fap")
            elif choice == 4:  # Crew
                self.install_repository("crew")
            elif choice == 5:  # Numbers
                self.install_repository("numbers")
            elif choice == 6:  # Shadow
                self.install_repository("shadow")
            elif choice == 7:  # Rising Tides
                self.install_repository("rising_tides")
            elif choice == 9:  # Essential addons
                self.install_essential_addons()
            elif choice == 10:  # Real-Debrid
                self.configure_real_debrid()
            elif choice == 11:  # Update all
                self.update_all_repositories()
    
    def install_repository(self, repo_name: str):
        """Install a specific repository"""
        repo_info = self.addon_manager.get_repository_info(repo_name)
        if not repo_info:
            self.tui.show_error("Error", f"Unknown repository: {repo_name}")
            return
        
        if repo_info["installed"]:
            self.tui.show_info("Already Installed",
                f"{repo_info['name']} is already installed.")
            return
        
        # Show repository details
        details = f"{repo_info['name']}\n\n{repo_info['description']}\n\n"
        details += "This will install:\n"
        for addon in repo_info['addons']:
            details += f"- {addon}\n"
        details += "\nProceed with installation?"
        
        if self.tui.confirm("Install Repository", details):
            self.tui.show_info("Installing", f"Installing {repo_info['name']}...")
            
            success, message = self.addon_manager.install_repository(repo_name)
            
            if success:
                self.tui.show_success("Success", message)
            else:
                self.tui.show_error("Installation Failed", message)
    
    def install_essential_addons(self):
        """Install essential/recommended addons"""
        if self.tui.confirm("Install Essential Addons",
            "This will install:\n"
            "- YouTube\n"
            "- Netflix (requires account)\n"
            "- Spotify Connect\n"
            "- Twitch\n\n"
            "Continue?"):
            
            self.tui.show_info("Installing", "Installing essential addons...")
            results = self.addon_manager.install_essential_addons()
            
            # Show results
            success_count = sum(1 for r in results.values() if r)
            total_count = len(results)
            
            if success_count == total_count:
                self.tui.show_success("Success", 
                    f"All {total_count} addons installed successfully!")
            else:
                self.tui.show_warning("Partial Success",
                    f"Installed {success_count} of {total_count} addons.\n"
                    "Check logs for details.")
    
    def configure_real_debrid(self):
        """Configure Real-Debrid integration"""
        self.tui.show_info("Real-Debrid Configuration",
            "Real-Debrid provides premium links for streaming.\n\n"
            "To configure:\n"
            "1. Get your API key from real-debrid.com\n"
            "2. Enter it in the next screen\n\n"
            "This feature is not yet fully implemented.")
    
    def update_all_repositories(self):
        """Update all installed repositories"""
        installed = self.addon_manager.get_installed_repositories()
        
        if not installed:
            self.tui.show_info("No Repositories",
                "No repositories are currently installed.")
            return
        
        if self.tui.confirm("Update Repositories",
            f"Update {len(installed)} installed repositories?"):
            
            self.tui.show_info("Updating", "Updating repositories...")
            results = self.addon_manager.update_all_repositories()
            
            success_count = sum(1 for r in results.values() if r)
            self.tui.show_success("Update Complete",
                f"Updated {success_count} of {len(results)} repositories.")
    
    def configure_network(self):
        """Network configuration"""
        self.tui.show_info("Network Settings",
            "Network configuration includes:\n"
            "- WiFi settings\n"
            "- Performance optimization\n"
            "- Wake-on-LAN\n"
            "- Static IP configuration\n\n"
            "Not yet implemented")
    
    def configure_display(self):
        """Display configuration"""
        self.tui.show_info("Display Settings",
            "Display configuration includes:\n"
            "- Resolution settings\n"
            "- Refresh rate\n"
            "- HDR configuration\n"
            "- Overscan adjustment\n\n"
            "Not yet implemented")
    
    def advanced_options(self):
        """Advanced options menu"""
        menu_items = [
            "Backup Configuration",
            "Restore Configuration",
            "Reset to Defaults",
            "View Logs",
            "Developer Options",
            "Back"
        ]
        
        while True:
            choice = self.tui.menu("Advanced Options", menu_items)
            
            if choice is None or choice == len(menu_items) - 1:
                break
            elif choice == 2:
                # Reset to defaults
                if self.tui.confirm("Reset Configuration",
                    "This will reset all settings to defaults"):
                    self.config.reset_to_defaults()
                    self.tui.show_success("Success", 
                        "Configuration reset to defaults")
            else:
                self.tui.show_info("Coming Soon",
                    f"{menu_items[choice]} is not yet implemented")
    
    def show_about(self):
        """Show about information"""
        self.tui.show_info("About OVERKILL",
            "OVERKILL v3.0.0\n"
            "Professional Media Center for Raspberry Pi 5\n\n"
            "Features:\n"
            "- Extreme overclocking\n"
            "- Intelligent thermal management\n"
            "- Custom Kodi builds\n"
            "- Advanced media services\n\n"
            "UNLIMITED POWER. ZERO RESTRICTIONS.\n\n"
            "Use at your own risk!")
    
    def run(self, tui: OverkillTUI):
        """Main run loop"""
        # Check requirements
        meets_requirements, issues = self.system.check_requirements()
        
        if not meets_requirements:
            message = "System does not meet all requirements:\n\n"
            for issue in issues:
                message += f"- {issue}\n"
            message += "\nContinue anyway?"
            
            if not tui.confirm("Requirements Check", message):
                return
        
        # Main menu loop
        while self.running:
            menu_items = self.main_menu()
            choice = tui.menu("OVERKILL Configuration", menu_items)
            
            if choice is None or choice == len(menu_items) - 1:
                # Exit
                if tui.confirm("Exit", "Are you sure you want to exit?"):
                    self.running = False
            elif choice == 0:
                self.show_system_info()
            elif choice == 1:
                self.configure_overclock()
            elif choice == 2:
                self.configure_thermal()
            elif choice == 3:
                self.configure_media_services()
            elif choice == 4:
                self.configure_network()
            elif choice == 5:
                self.configure_display()
            elif choice == 6:
                self.advanced_options()
            elif choice == 7:
                self.show_about()
    
    def start(self):
        """Start the configurator"""
        try:
            self.tui.run(self.run)
        except Exception as e:
            logger.error(f"Configurator error: {e}")
            raise


@click.command()
@click.option('--debug', is_flag=True, help='Enable debug output')
def main(debug: bool):
    """OVERKILL Media Center Configurator"""
    # Check for root
    if not is_root():
        print("This program must be run as root (use sudo)")
        sys.exit(1)
    
    # Setup logging
    setup_logging(debug)
    
    # Create and run configurator
    configurator = OverkillConfigurator()
    configurator.start()


if __name__ == "__main__":
    main()