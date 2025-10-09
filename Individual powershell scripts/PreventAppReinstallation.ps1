<#
.SYNOPSIS
    Prevents Windows from reinstalling removed apps.
.DESCRIPTION
    This script prevents Windows from reinstalling removed apps by creating registry keys and using PowerShell commands to deprovision apps.
.NOTES
    File Name      : PreventReinstall.ps1
    Author         : Le Chat
    Prerequisite   : PowerShell 5.1 or later
#>

# Function to write log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Level] $Message"
}

# Function to prevent apps from being reinstalled
function Prevent-AppReinstall {
    param (
        [string[]]$AppNames
    )
    foreach ($appName in $AppNames) {
        Write-Log ("Processing app: " + $appName)
        try {
            # Get the package full name for the app
            $package = Get-AppxPackage -Name $appName -ErrorAction SilentlyContinue
            if ($package) {
                $packageFullName = $package.PackageFullName
                Write-Log ("Found package: " + $packageFullName)

                # Remove the app for all users
                Remove-AppxPackage -Package $packageFullName -AllUsers -ErrorAction Stop
                Write-Log ("Successfully removed app package: " + $packageFullName)

                # Deprovision the app to prevent reinstallation
                Remove-AppxProvisionedPackage -Online -PackageName $packageFullName -ErrorAction Stop
                Write-Log ("Successfully deprovisioned package: " + $packageFullName)

                # Create registry key to prevent reinstallation
                $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned"
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }
                New-Item -Path ($regPath + "\" + $packageFullName) -Force | Out-Null
                Write-Log ("Created registry key to prevent reinstallation for: " + $packageFullName)
            } else {
                Write-Log ("App package not found: " + $appName) -Level "WARN"
            }
        } catch {
            $errorMsg = $_ | Out-String
            Write-Log ("Error processing app " + $appName + ": " + $errorMsg) -Level "ERROR"
            # Special handling for system components
            if ($appName -like "*MicrosoftEdgeDevToolsClient*" -or $appName -like "*Windows.PeopleExperienceHost*") {
                Write-Log ("$appName is a system component and cannot be fully removed.") -Level "WARN"
                Write-Log ("You may try to remove it using Turn Windows Features on or off.") -Level "INFO"
            }
        }
    }
}

# List of apps to prevent from being reinstalled
$appsToPrevent = @(
    "Microsoft.MicrosoftEdge",
    "Microsoft.MicrosoftEdgeDevToolsClient",
    "microsoft.windowscommunicationsapps", # Mail and Calendar
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.ZuneMusic", # Groove Music
    "Microsoft.WindowsCamera",
    "Microsoft.SkypeApp",
    "Microsoft.Office.OneNote",
    "Microsoft.People",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.Xbox.TCUI",
    "Microsoft.549981C3F5F10", # Cortana
    "Microsoft.WindowsMaps",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted", # Get Started
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.ScreenSketch",
    "Microsoft.BingWeather",
    "Microsoft.BingNews" # Microsoft News and Weather apps
)

# Prevent the apps from being reinstalled
Prevent-AppReinstall -AppNames $appsToPrevent

Write-Log ("Script completed.")
