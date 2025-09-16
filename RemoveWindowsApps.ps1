<#
.SYNOPSIS
    Removes built-in Windows 10 bloatware apps for all users.
.DESCRIPTION
    This script removes a comprehensive list of built-in Windows 10 apps.
    Logs all actions, errors, and warnings to a file: RemoveWindowsApps_Log_[Date].txt
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
$logFileName = "RemoveWindowsApps_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
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

# Main script execution
try {
    Write-Log "Script started."

    # List of apps to remove (Package Name Partial)
    $appsToRemove = @(
        "Microsoft.MicrosoftEdge",
        "Microsoft.WindowsCommunicationsApps",
        "Microsoft.MSPaint",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.WindowsCalculator",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.ZuneMusic",
        "Microsoft.WindowsCamera",
        "Microsoft.XboxApp",
        "Microsoft.SkypeApp",
        "Microsoft.Office.OneNote",
        "Microsoft.People",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.Xbox.TCUI",
        "Microsoft.Windows.Holographic.FirstRun",
        "Microsoft.549981C3F5F10",
        "Microsoft.WindowsMaps",
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.BingSports",
        "Microsoft.BingFinance",
        "InternetExplorer",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.Office.Sway",
        "Microsoft.OneConnect",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.ScreenSketch",
        "Microsoft.WindowsFeedback",
        "Microsoft.WindowsStore",
        "Microsoft.YourPhone"
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

        Write-Log "Attempting to remove $app for all users..."

        # Remove provisioned packages
        try {
            $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$app*" -ErrorAction Stop
            if ($provisionedPackages) {
                foreach ($package in $provisionedPackages) {
                    try {
                        Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop
                        Write-Log "Successfully removed provisioned package for $($package.DisplayName)."
                    } catch {
                        Write-Log "Failed to remove provisioned package $($package.DisplayName): $_" -Level "ERROR"
                    }
                }
            } else {
                Write-Log "No provisioned package found for $app." -Level "WARN"
            }
        } catch {
            Write-Log "Error checking provisioned packages for $app: $_" -Level "ERROR"
        }

        # Remove installed packages
        try {
            $appPackages = Get-AppxPackage -AllUsers | Where-Object Name -like "*$app*" -ErrorAction Stop
            if ($appPackages) {
                foreach ($package in $appPackages) {
                    try {
                        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                        Write-Log "Successfully removed app package for $($package.Name)."
                    } catch {
                        Write-Log "Failed to remove app package $($package.Name): $_" -Level "ERROR"
                    }
                }
            } else {
                Write-Log "No app package found for $app." -Level "WARN"
            }
        } catch {
            Write-Log "Error checking app packages for $app: $_" -Level "ERROR"
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
