# qBittorrent Web API settings
$qbtHost = "localhost"
$qbtPort = "8080"
$qbtUsername = "username"
$qbtPassword = "password"

# Jellyfin settings
$jellyfinHost = "localhost"
$jellyfinPort = "8096"
$jellyfinApiKey = "yourapikey" # Generate this in Jellyfin dashboard

# Enhanced logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
}

# Function to check if Jellyfin is streaming
function Is-JellyfinStreaming {
    try {
        Write-Log "Checking Jellyfin streaming status..."
        # Get current Jellyfin sessions
        $uri = "http://$jellyfinHost`:$jellyfinPort/Sessions?api_key=$jellyfinApiKey"
        Write-Log "Requesting Jellyfin sessions from: $uri" "DEBUG"
        $sessions = Invoke-RestMethod -Uri $uri -Method Get -UseBasicParsing
        
        Write-Log "Retrieved $($sessions.Count) Jellyfin sessions" "DEBUG"
        
        # Check if any session is currently playing video
        foreach ($session in $sessions) {
            Write-Log "Checking session: $($session.Id) - PlayState: $($session.PlayState)" "DEBUG"
            
            # Check if this session has an active playback
            if ($session.PlayState -and 
                $session.PlayState.IsPaused -eq $false -and
                $session.PlayState.PositionTicks -gt 0) {
                
                Write-Log "Active streaming detected in session $($session.Id)" "INFO"
                return $true
            }
        }
        Write-Log "No active streaming detected" "INFO"
        return $false
    }
    catch {
        Write-Log "Error checking Jellyfin: $_" "ERROR"
        Write-Log "Exception details: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to get qBittorrent auth cookie
function Get-QBittorrentSession {
    try {
        Write-Log "Authenticating with qBittorrent..."
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $uri = "http://$qbtHost`:$qbtPort/api/v2/auth/login"
        Write-Log "qBittorrent auth URL: $uri" "DEBUG"
        $auth = Invoke-WebRequest -Uri $uri -Method POST `
                -Body "username=$qbtUsername&password=$qbtPassword" -WebSession $session -UseBasicParsing
        
        Write-Log "qBittorrent authentication successful: $($auth.StatusCode)" "INFO"
        return $session
    }
    catch {
        Write-Log "Error authenticating with qBittorrent: $_" "ERROR"
        Write-Log "Exception details: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to manage all qBittorrent downloads
function Manage-QBittorrentDownloads {
    param (
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [bool]$ShouldPause
    )
    
    try {
        if ($null -eq $Session) {
            Write-Log "Invalid session - cannot manage qBittorrent downloads" "ERROR"
            return
        }

        # Determine the action to take
        if ($ShouldPause) {
            Write-Log "Stopping all torrents..." "INFO"
            $uri = "http://$qbtHost`:$qbtPort/api/v2/torrents/stop"
        } else {
            Write-Log "Starting all torrents..." "INFO"
            $uri = "http://$qbtHost`:$qbtPort/api/v2/torrents/start"
        }

        # Create the POST body with hashes=all
        $body = @{ hashes = 'all' }

        # Send the POST request with the body containing 'hashes=all'
        $response = Invoke-WebRequest -Uri $uri -Method POST -Body $body -WebSession $Session -UseBasicParsing
        Write-Log "Torrent operation response: $($response.StatusCode) $($response.StatusDescription)" "INFO"
    }
    catch {
        Write-Log "Error managing torrents: $_" "ERROR"
        Write-Log "Exception details: $($_.Exception.Message)" "ERROR"
    }
}

# Function to verify services are accessible
function Test-Services {
    # Test qBittorrent
    try {
        # Try several endpoints to detect qBittorrent API
        try {
            $qbtTest = Invoke-WebRequest -Uri "http://$qbtHost`:$qbtPort/api/v2/app/version" -Method GET -UseBasicParsing -TimeoutSec 5
            Write-Log "qBittorrent API v2 accessible - Version: $($qbtTest.Content)" "INFO"
        }
        catch {
            # Try alternative API endpoint
            try {
                $qbtTest = Invoke-WebRequest -Uri "http://$qbtHost`:$qbtPort/version/api" -Method GET -UseBasicParsing -TimeoutSec 5
                Write-Log "qBittorrent legacy API accessible - Version: $($qbtTest.Content)" "INFO"
                
                # If we're using legacy API, update the global host/port for use in other functions
                $script:qbtApiVersion = "legacy"
            }
            catch {
                Write-Log "Cannot access qBittorrent API - Error: $($_.Exception.Message)" "ERROR"
            }
        }
    }
    catch {
        Write-Log "qBittorrent connectivity test error: $($_.Exception.Message)" "ERROR"
    }
    
    # Test Jellyfin
    try {
        $jfTest = Invoke-WebRequest -Uri "http://$jellyfinHost`:$jellyfinPort/System/Info/Public" -Method GET -UseBasicParsing -TimeoutSec 5
        Write-Log "Jellyfin API accessible" "INFO"
    }
    catch {
        Write-Log "Cannot access Jellyfin API at http://$jellyfinHost`:$jellyfinPort - Error: $($_.Exception.Message)" "ERROR"
    }
}

# Main monitoring loop
Write-Log "===== Starting Jellyfin/qBittorrent monitoring =====" "INFO"
Write-Log "Script configuration:" "INFO"
Write-Log "qBittorrent: http://$qbtHost`:$qbtPort" "INFO"
Write-Log "Jellyfin: http://$jellyfinHost`:$jellyfinPort" "INFO"

# Test connectivity to services
Test-Services

$session = Get-QBittorrentSession
$lastAuth = Get-Date
$previousState = $false

while ($true) {
    # Refresh session periodically to prevent timeout
    if (($null -eq $session) -or ((Get-Date) - $lastAuth).TotalMinutes -gt 10) {
        Write-Log "Refreshing qBittorrent authentication session" "INFO"
        $session = Get-QBittorrentSession
        $lastAuth = Get-Date
    }
    
    # Check if Jellyfin is streaming
    $isStreaming = Is-JellyfinStreaming
    Write-Log "Current streaming status: $isStreaming, Previous state: $previousState" "DEBUG"
    
    # Only take action if the state has changed
    if ($isStreaming -ne $previousState) {
        if ($isStreaming) {
            Write-Log "STATE CHANGE: Jellyfin streaming detected - pausing downloads" "INFO"
            Manage-QBittorrentDownloads -Session $session -ShouldPause $true
        } else {
            Write-Log "STATE CHANGE: No Jellyfin streaming detected - resuming downloads" "INFO"
            Manage-QBittorrentDownloads -Session $session -ShouldPause $false
        }
        $previousState = $isStreaming
    }
    
    # Wait before checking again
    Write-Log "Waiting 30 seconds before next check..." "DEBUG"
    Start-Sleep -Seconds 30
}