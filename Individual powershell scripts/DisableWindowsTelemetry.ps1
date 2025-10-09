<#
.SYNOPSIS
    Disables Windows telemetry and diagnostic tracking for privacy-focused users.
.DESCRIPTION
    This script disables telemetry services and settings that can result in Microsoft gaining data on a user.
.NOTES
    Run this script as Administrator.
    Backup your system or create a restore point before running this script.
#>

# Function to log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Output $logEntry
}

# Function to set registry property
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
            Write-Log "Successfully set registry property: ${Path}\${Name}"
        } else {
            New-Item -Path $Path -Force | Out-Null
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            Write-Log "Created path and set registry property: ${Path}\${Name}"
        }
    } catch {
        Write-Log "Failed to set registry property ${Path}\${Name}: $_" -Level "ERROR"
    }
}

# Function to stop and disable a service
function Stop-Disable-Service {
    param (
        [string]$ServiceName
    )
    try {
        $serviceObj = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($serviceObj -ne $null) {
            Write-Log "Stopping and disabling service: $ServiceName"
            try {
                if ($serviceObj.Status -ne "Stopped") {
                    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                    Write-Log "Successfully stopped service: $ServiceName"
                }
                Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
                Write-Log "Successfully disabled service: $ServiceName"
            } catch {
                Write-Log "Failed to stop/disable service $ServiceName : $_" -Level "ERROR"
            }
        } else {
            Write-Log "Service $ServiceName not found. Skipping..." -Level "WARN"
        }
    } catch {
        Write-Log "Error checking service $ServiceName : $_" -Level "ERROR"
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
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "EnableDiagTrack" -Value 0 -Type "DWord"
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0 -Type "DWord"

    # Disable Windows Customer Experience Improvement Program
    Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0 -Type "DWord"

    # Stop and disable telemetry-related services
    $servicesToDisable = @(
        "DiagTrack",
        "WerSvc"
    )

    foreach ($serviceName in $servicesToDisable) {
        Stop-Disable-Service -ServiceName $serviceName
    }

    Write-Log "Script completed successfully." -Level "INFO"
} catch {
    Write-Log "Script terminated unexpectedly: $_" -Level "ERROR"
} finally {
    Write-Log "Script execution finished."
    Read-Host -Prompt "Press Enter to exit"
}
