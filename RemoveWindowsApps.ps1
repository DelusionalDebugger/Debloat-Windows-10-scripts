<#
.SYNOPSIS
    Removes built-in Windows 10 bloatware apps for all users.
.DESCRIPTION
    This script removes a comprehensive list of built-in Windows 10 apps.
    Logs all actions, errors, and warnings to a file: RemoveWindowsApps_Log_[Date].txt
.NOTES
    Run this script as Administrator or SYSTEM.
    Backup your system or create a restore point before running this script.
#>

# Define log file path
$logFileName = "RemoveWindowsApps_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$logFilePath = Join-Path -Path $env:USERPROFILE\Desktop -ChildPath $logFileName
Write-Host "Log file will be saved to: $logFilePath" -ForegroundColor Cyan

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

try {
    # Log script start
    Write-Log "Script started."

    # List of apps to remove (Package Name Partial)
    $appsToRemove = @(
        "Microsoft.MicrosoftEdge",                # Microsoft Edge
        "Microsoft.WindowsCommunicationsApps",   # Mail and Calendar
        "Microsoft.MSPaint",                     # Paint 3D
        "Microsoft.MicrosoftStickyNotes",       # Sticky Notes
        "Microsoft.WindowsCalculator",           # Calculator
        "Microsoft.WindowsAlarms",               # Alarms & Clock
        "Microsoft.WindowsSoundRecorder",       # Voice Recorder
        "Microsoft.ZuneMusic",                   # Groove Music
        "Microsoft.WindowsCamera",               # Camera
        "Microsoft.XboxApp",                     # Xbox
        "Microsoft.SkypeApp",                    # Skype
        "Microsoft.Office.OneNote",              # OneNote
        "Microsoft.People",                      # People
        "Microsoft.WindowsFeedbackHub",          # Feedback Hub
        "Microsoft.Xbox.TCUI",                   # Xbox Console Companion
        "Microsoft.Windows.Holographic.FirstRun", # Mixed Reality Portal
        "Microsoft.549981C3F5F10",               # Cortana
        "Microsoft.WindowsMaps",                 # Maps
        "Microsoft.BingWeather",                 # Weather
        "Microsoft.BingNews",                    # News
        "Microsoft.BingSports",                  # Sports
        "Microsoft.BingFinance",                 # Money
        "InternetExplorer",                      # Internet Explorer
        "Microsoft.GetHelp",                     # Get Help
        "Microsoft.Getstarted",                  # Get Started
        "Microsoft.MicrosoftOfficeHub",          # Office Hub
        "Microsoft.MicrosoftSolitaireCollection", # Solitaire
        "Microsoft.Office.Sway",                 # Sway
        "Microsoft.OneConnect",                  # OneConnect
        "Microsoft.PowerAutomateDesktop",        # Power Automate
        "Microsoft.ScreenSketch",                # Screen Sketch
        "Microsoft.WindowsFeedback",            # Feedback
        "Microsoft.WindowsStore",                # Microsoft Store
        "Microsoft.YourPhone"                    # Your Phone
    )

    # List of problematic apps to skip
    $problematicApps = @(
        "Microsoft.ZuneVideo",
        "Microsoft.XboxApp"
    )

    # Remove apps for all users
    foreach ($app in $appsToRemove) {
        if ($problematicApps -contains $app) {
            Write-Log "Skipping $app (known issue)." -Level "WARN"
            continue
        }
        Write-Log "Removing $app for all users..."
        try {
            $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$app*"
            if ($provisionedPackages) {
                $provisionedPackages | Remove-AppxProvisionedPackage -Online -ErrorAction Stop
                Write-Log "Successfully removed provisioned package for $app."
            } else {
                Write-Log "No provisioned package found for $app." -Level "WARN"
            }
        } catch {
            Write-Log "Failed to remove provisioned package for $app: $_" -Level "ERROR"
        }
        try {
            $appPackages = Get-AppxPackage -AllUsers *$app*
            if ($appPackages) {
                $appPackages | Remove-AppxPackage -ErrorAction Stop
                Write-Log "Successfully removed app package for $app."
            } else {
                Write-Log "No app package found for $app." -Level "WARN"
            }
        } catch {
            Write-Log "Failed to remove app package for $app: $_" -Level "ERROR"
        }
    }

    Write-Log "Script completed successfully." -Level "INFO"
} catch {
    Write-Log "Script terminated unexpectedly: $_" -Level "ERROR"
}

Write-Log "Script execution finished."
Write-Host "Script completed. Log file saved to: $logFilePath" -ForegroundColor Green
Read-Host -Prompt "Press Enter to exit"
