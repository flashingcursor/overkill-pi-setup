"""OVERKILL API Client for Kodi addon"""

import json
import requests
import xbmc
import xbmcaddon
from typing import Dict, Optional, Any


class OverkillClient:
    """Client for communicating with OVERKILL service"""
    
    def __init__(self):
        self.addon = xbmcaddon.Addon()
        self.api_host = self.addon.getSetting('api_host') or 'localhost'
        self.api_port = int(self.addon.getSetting('api_port') or '9876')
        self.base_url = f"http://{self.api_host}:{self.api_port}/api"
        self.timeout = 5
        self.debug = self.addon.getSetting('debug_logging') == 'true'
        
    def _log(self, message: str, level: int = xbmc.LOGDEBUG):
        """Log message if debug enabled"""
        if self.debug or level >= xbmc.LOGWARNING:
            xbmc.log(f"OVERKILL Client: {message}", level)
    
    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Optional[Dict]:
        """Make API request"""
        url = f"{self.base_url}/{endpoint}"
        
        try:
            self._log(f"{method} {url}")
            
            if method == 'GET':
                response = requests.get(url, timeout=self.timeout)
            elif method == 'POST':
                response = requests.post(url, json=data, timeout=self.timeout)
            elif method == 'PUT':
                response = requests.put(url, json=data, timeout=self.timeout)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            self._log(f"Request failed: {str(e)}", xbmc.LOGWARNING)
            return None
        except Exception as e:
            self._log(f"Unexpected error: {str(e)}", xbmc.LOGERROR)
            return None
    
    def get_status(self) -> Optional[Dict[str, Any]]:
        """Get current system status"""
        # For now, return mock data since API isn't implemented
        # In production, this would call: return self._request('GET', 'status')
        
        try:
            # Try to read from local system
            temp = self._get_local_temperature()
            
            return {
                'temperature': temp,
                'profile': 'balanced',
                'fan_speed': 50,
                'throttle_status': {
                    'throttled': False,
                    'temperature_limit': False,
                    'undervoltage': False,
                    'frequency_capped': False
                }
            }
        except:
            return None
    
    def get_system_info(self) -> Optional[Dict[str, Any]]:
        """Get detailed system information"""
        # Mock implementation
        return {
            'model': 'Raspberry Pi 5 Model B Rev 1.0',
            'cpu': 'BCM2712 Cortex-A76',
            'memory_gb': 8.0,
            'kernel': '6.1.0-rpi7-rpi-2712',
            'storage_devices': [
                {
                    'device': '/dev/nvme0n1p1',
                    'total_gb': 931.5,
                    'percent': 15.2
                }
            ],
            'nvme_devices': ['/dev/nvme0n1'],
            'temperature': self._get_local_temperature(),
            'cpu_freq': {'current': 2600},
            'gpu_freq': 950
        }
    
    def get_overclock_profiles(self) -> Optional[Dict[str, Dict]]:
        """Get available overclock profiles"""
        # Mock implementation
        return {
            'safe': {
                'name': 'Safe',
                'arm_freq': 2400,
                'gpu_freq': 900,
                'description': 'Conservative settings for stability'
            },
            'balanced': {
                'name': 'Balanced',
                'arm_freq': 2600,
                'gpu_freq': 950,
                'description': 'Good performance with reasonable temps'
            },
            'performance': {
                'name': 'Performance',
                'arm_freq': 2700,
                'gpu_freq': 975,
                'description': 'High performance, requires good cooling'
            },
            'extreme': {
                'name': 'Extreme',
                'arm_freq': 2800,
                'gpu_freq': 1000,
                'description': 'Maximum performance, excellent cooling required'
            }
        }
    
    def get_current_profile(self) -> str:
        """Get current overclock profile"""
        return 'balanced'  # Mock
    
    def set_overclock_profile(self, profile: str) -> Optional[Dict]:
        """Set overclock profile"""
        self._log(f"Setting overclock profile to: {profile}")
        # In production: return self._request('POST', 'overclock/profile', {'profile': profile})
        return {'success': True, 'message': f'Profile {profile} applied'}
    
    def set_fan_mode(self, mode: str) -> Optional[Dict]:
        """Set fan control mode"""
        self._log(f"Setting fan mode to: {mode}")
        # In production: return self._request('POST', 'thermal/fan_mode', {'mode': mode})
        return {'success': True, 'message': f'Fan mode set to {mode}'}
    
    def _get_local_temperature(self) -> float:
        """Get temperature from local system"""
        try:
            # Try reading thermal zone
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                return float(f.read().strip()) / 1000.0
        except:
            return 45.0  # Default mock temperature