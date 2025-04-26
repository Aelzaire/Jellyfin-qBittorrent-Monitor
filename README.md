🧠 What It Does

This PowerShell-based monitor checks whether your Jellyfin server is currently streaming media. If it detects active playback, it pauses all qBittorrent downloads to prioritize bandwidth. When no media is streaming, it resumes the downloads—automatically, silently, and efficiently.

Ideal for home servers or media centers where network congestion from torrenting can interfere with smooth playback.

⚙️ Features

✅ Monitors Jellyfin's API for active streaming sessions

✅ Pauses all qBittorrent downloads during playback

✅ Resumes downloads when playback ends

 ✅ Runs silently as a Windows service using NSSM

 ✅ Logs status changes, errors, and API interactions for troubleshooting

🛠 Requirements

Windows (tested on Windows Server 2022)

 qBittorrent with Web UI enabled

 Jellyfin media server

 NSSM to run as a background service

  PowerShell 5.1 or newer

🚀 Installation

 Clone this repo or download the .ps1 script and helper files.

 Modify the script to include your:

   Jellyfin server address and API key

   qBittorrent Web UI credentials and port

 Install as a service manually with nssm (Make sure to modify the path below):
   
    nssm install JellyfinQbtMonitor PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Path\To\JellyfinQbtMonitor.ps1"
    nssm set JellyfinQbtMonitor DisplayName "Jellyfin qBittorrent Monitor"
    nssm set JellyfinQbtMonitor Description "Monitors Jellyfin streaming and manages qBittorrent download speeds"
    nssm set JellyfinQbtMonitor ObjectName "LocalSystem" # or a specific user account
    nssm set JellyfinQbtMonitor Start SERVICE_AUTO_START
    nssm set JellyfinQbtMonitor AppStdout "C:\path\to\logs\jellyfin-qbt-monitor.log"
    nssm set JellyfinQbtMonitor AppStderr "C:\path\to\logs\jellyfin-qbt-monitor-error.log"

   Configure the service to start automatically and set log paths if needed.

Done! The script will monitor your Jellyfin server every 30 seconds.

📄 Logging

Logs are written to a specified directory (default: C:\ServerScripts\Logs) and include:

Timestamps

Playback state changes

qBittorrent API responses

Errors or failed requests

💡 Why?

Streaming media and torrenting don't always play nicely on the same connection. This lightweight automation ensures a smooth Jellyfin experience without having to pause downloads manually.
