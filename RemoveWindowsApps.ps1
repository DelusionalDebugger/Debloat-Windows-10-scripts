<#
.SYNOPSIS
    Removes built-in Windows 10 bloatware apps for all users.
.DESCRIPTION
    This script removes a comprehensive list of built-in Windows 10 apps while keeping Microsoft Paint.
    Logs all actions, errors, and warnings to a file: RemoveWindowsApps_Log_[Date].txt
.NOTES
    Run this script as Administrator.
    Backup your system or create a restore point before running this script.
#>

# Function to ensure the script runs with admin privileges
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running as Administrator
if (-not (Test-Admin)) {
    Write-Host "This script must be run as Administrator. Please restart PowerShell as Administrator and try again." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Create log directory if it doesn't exist
$logDir = "$env:USERPROFILE\Desktop\Logs"
if (-not (Test-Path $logDir)) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    } catch {
        Write-Host "Failed to create log directory: $_" -ForegroundColor Red
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
}

# Define log file path
$logFileName = "RemoveWindowsApps_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$logFilePath = Join-Path -Path $logDir -ChildPath $logFileName

# Create empty log file immediately
try {
    New-Item -Path $logFilePath -ItemType File -Force | Out-Null
} catch {
    Write-Host "Failed to create log file: $_" -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

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

# Function to remove apps using multiple methods
function Remove-App {
    param (
        [string]$AppName,
        [string]$PackageNameFilter
    )

    Write-Log ("Attempting to remove " + $AppName + "...")

    # Try to remove provisioned packages
    try {
        $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$PackageNameFilter*" } -ErrorAction SilentlyContinue
        if ($provisionedPackages) {
            foreach ($package in $provisionedPackages) {
                try {
                    $packageName = $package.PackageName
                    Write-Log ("Found provisioned package: " + $packageName)
                    Remove-AppxProvisionedPackage -Online -PackageName $packageName -ErrorAction Stop
                    Write-Log ("Successfully removed provisioned package: " + $packageName)
                } catch {
                    $errorMsg = $_ | Out-String
                    Write-Log ("Failed to remove provisioned package " + $packageName + ": " + $errorMsg) -Level "ERROR"

                    # Try DISM as fallback
                    try {
                        Write-Log ("Attempting to remove " + $packageName + " using DISM...")
                        Start-Process -FilePath "dism.exe" -ArgumentList "/Online", "/Remove-ProvisionedAppxPackage", "/PackageName:$packageName" -Wait -NoNewWindow
                        Write-Log ("Successfully removed provisioned package using DISM: " + $packageName)
                    } catch {
                        Write-Log ("Failed to remove provisioned package using DISM for " + $packageName + ": " + ($_ | Out-String)) -Level "ERROR"
                    }
                }
            }
        } else {
            Write-Log ("No provisioned package found for " + $AppName + ".") -Level "WARN"
        }
    } catch {
        $errorMsg = $_ | Out-String
        Write-Log ("Error checking provisioned packages for " + $AppName + ": " + $errorMsg) -Level "ERROR"
    }

    # Try to remove installed packages
    try {
        $appPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$PackageNameFilter*" } -ErrorAction SilentlyContinue
        if ($appPackages) {
            foreach ($package in $appPackages) {
                try {
                    $packageName = $package.Name
                    Write-Log ("Found app package: " + $packageName)
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                    Write-Log ("Successfully removed app package: " + $packageName)
                } catch {
                    $errorMsg = $_ | Out-String
                    Write-Log ("Failed to remove app package " + $packageName + ": " + $errorMsg) -Level "ERROR"

                    # Try DISM as fallback for installed packages
                    try {
                        Write-Log ("Attempting to remove " + $packageName + " using DISM...")
                        $packageFullName = $package.PackageFullName
                        Start-Process -FilePath "powershell.exe" -ArgumentList "-Command `"`"Get-AppxPackage -Name '$packageName' | Remove-AppxPackage`"`"" -Verb RunAs -Wait
                        Write-Log ("Successfully removed app package using elevated command: " + $packageName)
                    } catch {
                        Write-Log ("Failed to remove app package using elevated command for " + $packageName + ": " + ($_ | Out-String)) -Level "ERROR"
                    }
                }
            }
        } else {
            Write-Log ("No app package found for " + $AppName + ".") -Level "WARN"
        }
    } catch {
        $errorMsg = $_ | Out-String
        Write-Log ("Error checking app packages for " + $AppName + ": " + $errorMsg) -Level "ERROR"
    }
}

# Main script execution
try {
    Write-Log "Script started."

    # List of apps to remove (Package Name Partial)
    $appsToRemove = @(
        @{Name="Microsoft Edge"; PackageNameFilter="Microsoft.MicrosoftEdge"},
        @{Name="Mail and Calendar"; PackageNameFilter="WindowsCommunicationsApps"},
        @{Name="Microsoft Sticky Notes"; PackageNameFilter="MicrosoftStickyNotes"},
        @{Name="Calculator"; PackageNameFilter="WindowsCalculator"},
        @{Name="Alarms & Clock"; PackageNameFilter="WindowsAlarms"},
        @{Name="Voice Recorder"; PackageNameFilter="WindowsSoundRecorder"},
        @{Name="Groove Music"; PackageNameFilter="ZuneMusic"},
        @{Name="Camera"; PackageNameFilter="WindowsCamera"},
        @{Name="Skype"; PackageNameFilter="SkypeApp"},
        @{Name="OneNote"; PackageNameFilter="Office.OneNote"},
        @{Name="People"; PackageNameFilter="People"},
        @{Name="Feedback Hub"; PackageNameFilter="WindowsFeedbackHub"},
        @{Name="Xbox TCUI"; PackageNameFilter="Xbox.TCUI"},
        @{Name="Cortana"; PackageNameFilter="549981C3F5F10"},
        @{Name="Maps"; PackageNameFilter="WindowsMaps"},
        @{Name="Weather"; PackageNameFilter="BingWeather"},
        @{Name="News"; PackageNameFilter="BingNews"},
        @{Name="Sports"; PackageNameFilter="BingSports"},
        @{Name="Money"; PackageNameFilter="BingFinance"},
        @{Name="Internet Explorer"; PackageNameFilter="InternetExplorer"},
        @{Name="Get Help"; PackageNameFilter="GetHelp"},
        @{Name="Get Started"; PackageNameFilter="Getstarted"},
        @{Name="Office Hub"; PackageNameFilter="MicrosoftOfficeHub"},
        @{Name="Solitaire Collection"; PackageNameFilter="MicrosoftSolitaireCollection"},
        @{Name="Sway"; PackageNameFilter="Office.Sway"},
        @{Name="OneConnect"; PackageNameFilter="OneConnect"},
        @{Name="Power Automate"; PackageNameFilter="PowerAutomateDesktop"},
        @{Name="Screen Sketch"; PackageNameFilter="ScreenSketch"},
        @{Name="Windows Store"; PackageNameFilter="WindowsStore"},
        @{Name="Your Phone"; PackageNameFilter="YourPhone"}
    )

    # Remove apps for all users
    foreach ($app in $appsToRemove) {
        Remove-App -AppName $app.Name -PackageNameFilter $app.PackageNameFilter
    }

    Write-Log "Script completed successfully." -Level "INFO"
} catch {
    $errorMsg = $_ | Out-String
    Write-Log ("Script terminated unexpectedly: " + $errorMsg) -Level "ERROR"
} finally {
    Write-Log "Script execution finished."
    Write-Host "`nScript completed. Log file saved to: $logFilePath" -ForegroundColor Green

    # Ensure the prompt appears even when run from a single command
    if ($Host.UI.RawUI.KeyAvailable) {
        # If input is waiting, clear it to ensure the prompt appears
        $Host.UI.RawUI.FlushInputBuffer()
    }

    # Force the prompt to appear
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    Write-Host "`nPress Enter to exit..."
    Read-Host
}