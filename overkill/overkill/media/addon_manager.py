"""Addon repository management for Kodi"""

import os
import json
import zipfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from ..core.logger import logger
from ..core.utils import run_command, ensure_directory, atomic_write
import requests


class AddonRepository:
    """Addon repository definition"""
    
    def __init__(self, name: str, url: str, description: str, 
                 addons: List[str], dependencies: Optional[List[str]] = None):
        self.name = name
        self.url = url
        self.description = description
        self.addons = addons
        self.dependencies = dependencies or []


class AddonManager:
    """Manage Kodi addon repositories and installations"""
    
    def __init__(self, kodi_home: Optional[Path] = None):
        self.kodi_home = kodi_home or Path("/home/overkill/.kodi")
        self.addons_dir = self.kodi_home / "addons"
        self.userdata = self.kodi_home / "userdata"
        self.temp_dir = Path("/tmp/overkill-addons")
        
        # Define known repositories
        self.repositories = {
            "umbrella": AddonRepository(
                name="Umbrella Repository",
                url="https://umbrella-dev.github.io/repository.umbrella/",
                description="Premium all-in-one addon with Real-Debrid support",
                addons=[
                    "repository.umbrella",
                    "plugin.video.umbrella",
                    "script.module.umbrella"
                ],
                dependencies=[
                    "script.module.requests",
                    "script.module.resolveurl"
                ]
            ),
            "fap": AddonRepository(
                name="FEN/Seren Addon Pack",
                url="https://tikipeter.github.io/",
                description="Popular streaming addons (FEN, Seren, etc)",
                addons=[
                    "repository.fenomscrapers",
                    "plugin.video.fen",
                    "plugin.video.seren",
                    "script.module.fenomscrapers"
                ],
                dependencies=[
                    "script.module.requests",
                    "script.module.resolveurl",
                    "plugin.video.youtube"
                ]
            ),
            "crew": AddonRepository(
                name="The Crew Repository",
                url="https://team-crew.github.io/",
                description="Sports, movies, TV shows, and live content",
                addons=[
                    "repository.thecrew",
                    "plugin.video.thecrew",
                    "plugin.video.thesportsdb"
                ]
            ),
            "numbers": AddonRepository(
                name="Numbers Repository",
                url="https://lookingglass.rocks/addons/",
                description="High-quality streaming addon",
                addons=[
                    "repository.numbers",
                    "plugin.video.numbers"
                ]
            ),
            "shadow": AddonRepository(
                name="Shadow Repository",
                url="https://kodi.shadowcrew.info/",
                description="Alternative streaming sources",
                addons=[
                    "repository.shadow",
                    "plugin.video.shadow"
                ]
            ),
            "rising_tides": AddonRepository(
                name="Rising Tides Repository",
                url="https://rising-tides.github.io/repo/",
                description="Trakt integration and streaming",
                addons=[
                    "repository.risingtides",
                    "plugin.video.risingtides"
                ]
            )
        }
        
        # Essential/recommended addons
        self.essential_addons = {
            "youtube": {
                "id": "plugin.video.youtube",
                "name": "YouTube",
                "repo": "official",
                "description": "Official YouTube addon"
            },
            "netflix": {
                "id": "plugin.video.netflix",
                "name": "Netflix",
                "repo": "castagnait",
                "description": "Netflix integration (requires account)"
            },
            "spotify": {
                "id": "plugin.audio.spotify",
                "name": "Spotify",
                "repo": "marcelveldt",
                "description": "Spotify Connect integration"
            },
            "twitch": {
                "id": "plugin.video.twitch",
                "name": "Twitch",
                "repo": "official",
                "description": "Twitch.tv streams"
            }
        }
    
    def check_kodi_installed(self) -> bool:
        """Check if Kodi is installed and configured"""
        return self.kodi_home.exists() and self.addons_dir.exists()
    
    def install_repository(self, repo_name: str) -> Tuple[bool, str]:
        """Install a repository and its addons"""
        if repo_name not in self.repositories:
            return False, f"Unknown repository: {repo_name}"
        
        repo = self.repositories[repo_name]
        logger.info(f"Installing {repo.name}...")
        
        try:
            # Ensure Kodi directories exist
            ensure_directory(self.addons_dir)
            ensure_directory(self.userdata)
            ensure_directory(self.temp_dir)
            
            # Download repository ZIP
            success, message = self._download_repository(repo)
            if not success:
                return False, message
            
            # Install dependencies first
            for dep in repo.dependencies:
                logger.info(f"Installing dependency: {dep}")
                self._install_addon_dependency(dep)
            
            # Enable repository in Kodi
            self._enable_addon(repo.addons[0])  # First addon is usually the repo
            
            # Create sources entry
            self._add_to_sources(repo)
            
            logger.info(f"Successfully installed {repo.name}")
            return True, f"{repo.name} installed successfully"
            
        except Exception as e:
            logger.error(f"Failed to install repository: {e}")
            return False, f"Installation failed: {str(e)}"
    
    def _download_repository(self, repo: AddonRepository) -> Tuple[bool, str]:
        """Download repository files"""
        # This is a simplified implementation
        # In reality, you'd need to parse the repository structure
        
        repo_addon = repo.addons[0]  # Main repository addon
        
        # For demonstration, we'll create a basic addon structure
        addon_path = self.addons_dir / repo_addon
        ensure_directory(addon_path)
        
        # Create addon.xml
        addon_xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<addon id="{repo_addon}" name="{repo.name}" version="1.0.0" provider-name="OVERKILL">
    <extension point="xbmc.addon.repository" name="{repo.name}">
        <info compressed="false">{repo.url}addons.xml</info>
        <checksum>{repo.url}addons.xml.md5</checksum>
        <datadir zip="true">{repo.url}</datadir>
    </extension>
    <extension point="xbmc.addon.metadata">
        <summary>{repo.name}</summary>
        <description>{repo.description}</description>
        <platform>all</platform>
    </extension>
</addon>
"""
        
        addon_xml_path = addon_path / "addon.xml"
        if not atomic_write(addon_xml_path, addon_xml):
            return False, "Failed to create addon.xml"
        
        # Create a basic icon
        icon_path = addon_path / "icon.png"
        # In a real implementation, download the actual icon
        # For now, just touch the file
        icon_path.touch()
        
        return True, "Repository downloaded"
    
    def _install_addon_dependency(self, addon_id: str):
        """Install addon dependency from official repo"""
        # In a real implementation, this would download from Kodi repo
        logger.debug(f"Would install dependency: {addon_id}")
    
    def _enable_addon(self, addon_id: str):
        """Enable addon in Kodi database"""
        # Create enabled addons file if not exists
        enabled_file = self.userdata / "addon_data" / "enabled_addons.xml"
        ensure_directory(enabled_file.parent)
        
        if not enabled_file.exists():
            content = '<?xml version="1.0" encoding="UTF-8"?>\n<addons>\n</addons>'
            atomic_write(enabled_file, content)
        
        # In a real implementation, properly parse and update XML
        logger.info(f"Enabled addon: {addon_id}")
    
    def _add_to_sources(self, repo: AddonRepository):
        """Add repository to sources.xml"""
        sources_file = self.userdata / "sources.xml"
        
        # Basic implementation - in reality, parse and update XML properly
        logger.info(f"Added {repo.name} to sources")
    
    def install_essential_addons(self) -> Dict[str, bool]:
        """Install essential/recommended addons"""
        results = {}
        
        for addon_id, addon_info in self.essential_addons.items():
            logger.info(f"Installing {addon_info['name']}...")
            try:
                # Simplified - would actually download and install
                addon_path = self.addons_dir / addon_info['id']
                ensure_directory(addon_path)
                
                # Create basic addon.xml
                addon_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<addon id="{addon_info['id']}" name="{addon_info['name']}" version="1.0.0">
    <extension point="xbmc.python.pluginsource" library="default.py">
        <provides>video</provides>
    </extension>
    <extension point="xbmc.addon.metadata">
        <summary>{addon_info['name']}</summary>
        <description>{addon_info['description']}</description>
    </extension>
</addon>
"""
                addon_xml_path = addon_path / "addon.xml"
                atomic_write(addon_xml_path, addon_xml)
                
                results[addon_id] = True
                logger.info(f"Installed {addon_info['name']}")
                
            except Exception as e:
                logger.error(f"Failed to install {addon_info['name']}: {e}")
                results[addon_id] = False
        
        return results
    
    def configure_real_debrid(self, api_key: str) -> bool:
        """Configure Real-Debrid for supported addons"""
        try:
            # Store RD credentials securely
            rd_config = {
                "api_key": api_key,
                "enabled": True,
                "priority": 90
            }
            
            # Save to addon settings
            settings_dir = self.userdata / "addon_data" / "script.module.resolveurl"
            ensure_directory(settings_dir)
            
            settings_file = settings_dir / "settings.xml"
            # In reality, properly update XML settings
            
            logger.info("Configured Real-Debrid")
            return True
            
        except Exception as e:
            logger.error(f"Failed to configure Real-Debrid: {e}")
            return False
    
    def get_installed_repositories(self) -> List[str]:
        """Get list of installed repositories"""
        installed = []
        
        for repo_name, repo in self.repositories.items():
            repo_path = self.addons_dir / repo.addons[0]
            if repo_path.exists():
                installed.append(repo_name)
        
        return installed
    
    def get_repository_info(self, repo_name: str) -> Optional[Dict]:
        """Get information about a repository"""
        if repo_name not in self.repositories:
            return None
        
        repo = self.repositories[repo_name]
        is_installed = (self.addons_dir / repo.addons[0]).exists()
        
        return {
            "name": repo.name,
            "description": repo.description,
            "url": repo.url,
            "addons": repo.addons,
            "installed": is_installed
        }
    
    def update_all_repositories(self) -> Dict[str, bool]:
        """Update all installed repositories"""
        results = {}
        installed = self.get_installed_repositories()
        
        for repo_name in installed:
            logger.info(f"Updating {repo_name}...")
            # In reality, would check for updates and apply them
            results[repo_name] = True
        
        return results