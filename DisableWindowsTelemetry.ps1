<#
.SYNOPSIS
    Disables Windows 10 telemetry and diagnostic tracking for all users.
.DESCRIPTION
    This script disables telemetry, services, and scheduled tasks for a privacy-focused experience.
    Logs all actions, errors, and warnings to a file: DisableWindowsTelemetry_Log_[Date].txt
.NOTES
    Run this script as Administrator.
    Backup your system or create a restore point before running this script.
#>

# Create log directory if it doesn't exist
$logDir = "$env:USERPROFILE\Desktop\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Define log file path
$logFileName = "DisableWindowsTelemetry_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$logFilePath = Join-Path -Path $logDir -ChildPath $logFileName

# Create empty log file immediately
New-Item -Path $logFilePath -ItemType File -Force | Out-Null

# Function to log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Output $logEntry

    try {
        Add-Content -Path $logFilePath -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Host "Failed to write to log file: $_" -ForegroundColor Red
    }
}

# Function to safely set registry properties
function Set-RegistryProperty {
    param (
        [string]$Path,
        [string]$Name,
        [int]$Value,
        [string]$Type
    )

    try {
        if (Test-Path $Path) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            Write-Log "Successfully set registry property: $Path\$Name"
        } else {
            # Create the path if it doesn't exist
            New-Item -Path $Path -Force | Out-Null
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            Write-Log "Created path and set registry property: $Path\$Name"
        }
    } catch {
        Write-Log "Failed to set registry property $Path\$Name: $_" -Level "ERROR"
    }
}

# Main script execution
try {
    Write-Log "Script started."

    # Disable and remove Windows telemetry and diagnostic tracking
    Write-Log "Disabling Windows telemetry and diagnostic tracking..."

    # Disable telemetry via Registry
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type "DWord"
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type "DWord"

    # Disable Windows Customer Experience Improvement Program
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0 -Type "DWord"

    # Disable Diagnostic Data Collection
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "EnableDiagTrack" -Value 0 -Type "DWord"

    # Disable Windows Error Reporting
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type "DWord"

    # Disable Activity History
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type "DWord"

    # Disable Tailored Experiences
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type "DWord"

    # Disable Advertising ID
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "LetAppsUseAdvertisingId" -Value 0 -Type "DWord"

    # Disable OneDrive telemetry
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableTelemetry" -Value 1 -Type "DWord"

    # Disable Windows Update Sharing
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0 -Type "DWord"

    # Disable Handwriting Data Sharing
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Handwriting" -Name "EnableInkWorkspace" -Value 0 -Type "DWord"

    # Disable Location Tracking
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type "String"

    # Disable Sensor Data Collection
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\sensors" -Name "Value" -Value "Deny" -Type "String"

    # Disable App Launch Tracking
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Start_TrackProgs" -Value 0 -Type "DWord"

    # Disable Windows Tips and Tricks
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowWindowsTips" -Value 0 -Type "DWord"

    # Disable Live Tiles
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Type "DWord"

    # Disable Lock Screen Ads and Spotlight
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type "DWord"
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1 -Type "DWord"

    # Disable Windows Game Bar and DVR
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type "DWord"
    Set-RegistryProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\xbgm" -Name "Start" -Value 4 -Type "DWord"

    # Stop and disable telemetry-related services
    $servicesToDisable = @(
        "DiagTrack",
        "dmwappushservice",
        "WaaSMedicSvc",
        "WpnService",
        "WerSvc",
        "PcaSvc",
        "RetailDemo"
    )

    foreach ($service in $servicesToDisable) {
        try {
            $serviceObj = Get-Service -Name $service -ErrorAction Stop
            if ($serviceObj -ne $null) {
                Write-Log "Stopping and disabling service: $service"
                try {
                    if ($serviceObj.Status -ne "Stopped") {
                        Stop-Service -Name $service -Force -ErrorAction Stop
                        Write-Log "Successfully stopped service: $service"
                    }
                    Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                    Write-Log "Successfully disabled service: $service"
                } catch {
                    Write-Log "Failed to stop/disable service $service: $_" -Level "ERROR"
                }
            } else {
                Write-Log "Service $service not found. Skipping..." -Level "WARN"
            }
        } catch {
            Write-Log "Error checking service $service: $_" -Level "ERROR"
        }
    }

    # Disable Windows Telemetry and Data Collection Tasks
    $taskPaths = @(
        "\Microsoft\Windows\Application Experience\",
        "\Microsoft\Windows\Customer Experience Improvement Program\",
        "\Microsoft\Windows\Autochk\",
        "\Microsoft\Windows\CloudExperienceHost\",
        "\Microsoft\Windows\DiskDiagnostic\",
        "\Microsoft\Windows\FileHistory\",
        "\Microsoft\Windows\Maintenance\",
        "\Microsoft\Windows\PI\",
        "\Microsoft\Windows\Power Efficiency Diagnostics\"
    )

    foreach ($path in $taskPaths) {
        try {
            $tasks = Get-ScheduledTask -TaskPath $path -ErrorAction Stop
            if ($tasks) {
                foreach ($task in $tasks) {
                    try {
                        Write-Log "Disabling scheduled task: $($task.TaskName)"
                        Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction Stop
                        Write-Log "Successfully disabled scheduled task: $($task.TaskName)"
                    } catch {
                        Write-Log "Failed to disable scheduled task $($task.TaskName): $_" -Level "ERROR"
                    }
                }
            } else {
                Write-Log "No tasks found in path: $path" -Level "WARN"
            }
        } catch {
            Write-Log "Failed to access task path $path: $_" -Level "ERROR"
        }
    }

    Write-Log "Script completed successfully." -Level "INFO"
} catch {
    Write-Log "Script terminated unexpectedly: $_" -Level "ERROR"
} finally {
    Write-Log "Script execution finished."
    Write-Host "`nScript completed. Log file saved to: $logFilePath" -ForegroundColor Green
    Read-Host -Prompt "Press Enter to exit"
}
