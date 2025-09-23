<#
.SYNOPSIS
    Removes built-in Windows 10/11 bloatware apps for all users with special handling for Microsoft Edge.
.DESCRIPTION
    This script removes a comprehensive list of built-in Windows apps.
    It includes special handling for Microsoft Edge to ensure it's fully removed from memory.
    Logs all actions, errors, and warnings to a file: RemoveWindowsApps_Log_[Date].txt
.NOTES
    Run this script as Administrator.
    Backup your system or create a restore point before running this script.
    After running this script, a reboot is recommended to fully remove Microsoft Edge from memory.
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
# Function to terminate processes by name
function Terminate-Processes {
    param (
        [string[]]$ProcessNames
    )
    foreach ($processName in $ProcessNames) {
        try {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Log ("Terminating $($processes.Count) $processName process(es)...")
                foreach ($process in $processes) {
                    try {
                        $process | Stop-Process -Force -ErrorAction Stop
                        Write-Log ("Successfully terminated $processName process with ID $($process.Id)")
                    } catch {
                        Write-Log ("Failed to terminate $processName process with ID $($process.Id): $_") -Level "ERROR"
                    }
                }
            } else {
                Write-Log ("No $processName processes found.") -Level "INFO"
            }
        } catch {
            Write-Log ("Error checking for $processName processes: $_") -Level "ERROR"
        }
    }
}
# Function to remove registry keys related to Microsoft Edge
function Remove-EdgeRegistryKeys {
    $edgeRegistryPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
        "HKLM:\SOFTWARE\Microsoft\Edge",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
        "HKCU:\Software\Microsoft\Edge",
        "HKCU:\Software\Microsoft\EdgeUpdate",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate"
    )
    foreach ($path in $edgeRegistryPaths) {
        try {
            if (Test-Path $path) {
                Write-Log ("Removing registry key: $path")
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Log ("Successfully removed registry key: $path")
            } else {
                Write-Log ("Registry key not found: $path") -Level "INFO"
            }
        } catch {
            Write-Log ("Failed to remove registry key ${path}: $_") -Level "ERROR"
        }
    }
}
# Function to remove Microsoft Edge scheduled tasks
function Remove-EdgeTasks {
    $edgeTaskNames = @(
        "MicrosoftEdgeUpdateTaskMachineCore",
        "MicrosoftEdgeUpdateTaskMachineUA",
        "MicrosoftEdgeUpdateTaskUserS-1-5-21-*"
    )
    foreach ($taskName in $edgeTaskNames) {
        try {
            $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*$taskName*" } -ErrorAction SilentlyContinue
            if ($tasks) {
                foreach ($task in $tasks) {
                    try {
                        Write-Log ("Disabling and removing scheduled task: $($task.TaskName)")
                        $task | Disable-ScheduledTask -ErrorAction Stop
                        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                        Write-Log ("Successfully disabled and removed scheduled task: $($task.TaskName)")
                    } catch {
                        Write-Log ("Failed to disable/remove scheduled task $($task.TaskName): $_") -Level "ERROR"
                    }
                }
            } else {
                Write-Log ("No scheduled tasks found matching: $taskName") -Level "INFO"
            }
        } catch {
            Write-Log ("Error checking for scheduled tasks matching ${taskName}: $_") -Level "ERROR"
        }
    }
}
# Function to remove Microsoft Edge services
function Remove-EdgeServices {
    $edgeServiceNames = @(
        "edgeupdate",
        "edgeupdatem"
    )
    foreach ($serviceName in $edgeServiceNames) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-Log ("Stopping and disabling service: $($service.Name)")
                try {
                    Stop-Service -Name $service.Name -Force -ErrorAction Stop
                    Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
                    Write-Log ("Successfully stopped and disabled service: $($service.Name)")
                } catch {
                    Write-Log ("Failed to stop/disable service $($service.Name): $_") -Level "ERROR"
                }
            } else {
                Write-Log ("Service not found: $serviceName") -Level "INFO"
            }
        } catch {
            Write-Log ("Error checking for service ${serviceName}: $_") -Level "ERROR"
        }
    }
}
# Function to remove apps using multiple methods
function Remove-App {
    param (
        [string]$AppName,
        [string]$PackageNameFilter,
        [bool]$IsCritical = $false
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
                    # Special handling for Microsoft Edge
                    if ($AppName -eq "Microsoft Edge" -and $packageName -like "*Microsoft.MicrosoftEdge*") {
                        Write-Log ("Terminating Microsoft Edge processes before removal...")
                        Terminate-Processes -ProcessNames @("msedge", "MicrosoftEdge", "MicrosoftEdgeCP", "MicrosoftEdgeUpdate")
                        # Remove Edge-specific registry keys
                        Remove-EdgeRegistryKeys
                        # Remove Edge scheduled tasks
                        Remove-EdgeTasks
                        # Remove Edge services
                        Remove-EdgeServices
                    }
                    Remove-AppxProvisionedPackage -Online -PackageName $packageName -ErrorAction Stop
                    Write-Log ("Successfully removed provisioned package: " + $packageName)
                } catch {
                    $errorMsg = $_ | Out-String
                    Write-Log ("Failed to remove provisioned package " + $packageName + ": " + $errorMsg) -Level "ERROR"
                    # Special handling for Microsoft Edge DevTools Client
                    if ($packageName -like "*Microsoft.MicrosoftEdgeDevToolsClient*") {
                        Write-Log ("Microsoft.MicrosoftEdgeDevToolsClient is a system component and cannot be fully removed.") -Level "WARN"
                        Write-Log ("This is expected behavior for this package.") -Level "WARN"
                    }
                    # Try DISM as fallback for other packages
                    elseif ($IsCritical) {
                        try {
                            Write-Log ("Attempting to remove " + $packageName + " using DISM...")
                            Start-Process -FilePath "dism.exe" -ArgumentList "/Online", "/Remove-ProvisionedAppxPackage", "/PackageName:$packageName" -Wait -NoNewWindow
                            Write-Log ("Successfully removed provisioned package using DISM: " + $packageName)
                        } catch {
                            Write-Log ("Failed to remove provisioned package using DISM for " + $packageName + ": " + ($_ | Out-String)) -Level "ERROR"
                        }
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
                    # Special handling for Microsoft Edge
                    if ($AppName -eq "Microsoft Edge" -and $packageName -like "*Microsoft.MicrosoftEdge*") {
                        Write-Log ("Terminating Microsoft Edge processes before removal...")
                        Terminate-Processes -ProcessNames @("msedge", "MicrosoftEdge", "MicrosoftEdgeCP", "MicrosoftEdgeUpdate")
                    }
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                    Write-Log ("Successfully removed app package: " + $packageName)
                } catch {
                    $errorMsg = $_ | Out-String
                    Write-Log ("Failed to remove app package " + $packageName + ": " + $errorMsg) -Level "ERROR"
                    # Special handling for Microsoft Edge DevTools Client
                    if ($packageName -like "*MicrosoftEdgeDevToolsClient*") {
                        Write-Log ("Microsoft Edge DevTools Client is a system component and cannot be fully removed.") -Level "WARN"
                        Write-Log ("This is expected behavior for this package.") -Level "WARN"
                    }
                    # Try DISM as fallback for other packages
                    elseif ($IsCritical) {
                        try {
                            Write-Log ("Attempting to remove " + $packageName + " using DISM...")
                            Start-Process -FilePath "powershell.exe" -ArgumentList "-Command `"`"Get-AppxPackage -Name '$packageName' | Remove-AppxPackage`"`"" -Verb RunAs -Wait
                            Write-Log ("Successfully removed app package using elevated command: " + $packageName)
                        } catch {
                            Write-Log ("Failed to remove app package using elevated command for " + $packageName + ": " + ($_ | Out-String)) -Level "ERROR"
                        }
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
# Function to search for and remove Microsoft News and Weather apps
function Remove-NewsAndWeather {
    Write-Log "Searching for Microsoft News and Weather apps..."
    # Try different package name patterns for Microsoft News
    $newsPatterns = @(
        "Microsoft.BingNews",
        "Microsoft.News",
        "News",
        "Microsoft.MSNNews",
        "Microsoft.WindowsNews"
    )
    foreach ($pattern in $newsPatterns) {
        try {
            Write-Log ("Searching for news apps with pattern: " + $pattern)
            # Check provisioned packages
            $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$pattern*" } -ErrorAction SilentlyContinue
            if ($provisionedPackages) {
                foreach ($package in $provisionedPackages) {
                    try {
                        $packageName = $package.PackageName
                        Write-Log ("Found news provisioned package: " + $packageName)
                        Remove-AppxProvisionedPackage -Online -PackageName $packageName -ErrorAction Stop
                        Write-Log ("Successfully removed news provisioned package: " + $packageName)
                    } catch {
                        $errorMsg = $_ | Out-String
                        Write-Log ("Failed to remove news provisioned package " + $packageName + ": " + $errorMsg) -Level "ERROR"
                    }
                }
            }
            # Check installed packages
            $appPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$pattern*" } -ErrorAction SilentlyContinue
            if ($appPackages) {
                foreach ($package in $appPackages) {
                    try {
                        $packageName = $package.Name
                        Write-Log ("Found news app package: " + $packageName)
                        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                        Write-Log ("Successfully removed news app package: " + $packageName)
                    } catch {
                        $errorMsg = $_ | Out-String
                        Write-Log ("Failed to remove news app package " + $packageName + ": " + $errorMsg) -Level "ERROR"
                    }
                }
            }
        } catch {
            $errorMsg = $_ | Out-String
            Write-Log ("Error searching for news apps with pattern " + $pattern + ": " + $errorMsg) -Level "ERROR"
        }
    }
    # Try different package name patterns for Microsoft Weather
    $weatherPatterns = @(
        "Microsoft.BingWeather",
        "Microsoft.Weather",
        "Weather",
        "Microsoft.MSNWeather",
        "Microsoft.WindowsWeather"
    )
    foreach ($pattern in $weatherPatterns) {
        try {
            Write-Log ("Searching for weather apps with pattern: " + $pattern)
            # Check provisioned packages
            $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$pattern*" } -ErrorAction SilentlyContinue
            if ($provisionedPackages) {
                foreach ($package in $provisionedPackages) {
                    try {
                        $packageName = $package.PackageName
                        Write-Log ("Found weather provisioned package: " + $packageName)
                        Remove-AppxProvisionedPackage -Online -PackageName $packageName -ErrorAction Stop
                        Write-Log ("Successfully removed weather provisioned package: " + $packageName)
                    } catch {
                        $errorMsg = $_ | Out-String
                        Write-Log ("Failed to remove weather provisioned package " + $packageName + ": " + $errorMsg) -Level "ERROR"
                    }
                }
            }
            # Check installed packages
            $appPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$pattern*" } -ErrorAction SilentlyContinue
            if ($appPackages) {
                foreach ($package in $appPackages) {
                    try {
                        $packageName = $package.Name
                        Write-Log ("Found weather app package: " + $packageName)
                        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                        Write-Log ("Successfully removed weather app package: " + $packageName)
                    } catch {
                        $errorMsg = $_ | Out-String
                        Write-Log ("Failed to remove weather app package " + $packageName + ": " + $errorMsg) -Level "ERROR"
                    }
                }
            }
        } catch {
            $errorMsg = $_ | Out-String
            Write-Log ("Error searching for weather apps with pattern " + $pattern + ": " + $errorMsg) -Level "ERROR"
        }
    }
}
# Function to remove Microsoft Edge completely
function Remove-MicrosoftEdge {
    Write-Log "Starting comprehensive Microsoft Edge removal..."
    # 1. Terminate all Edge-related processes
    Write-Log "Terminating all Microsoft Edge processes..."
    Terminate-Processes -ProcessNames @("msedge", "MicrosoftEdge", "MicrosoftEdgeCP", "MicrosoftEdgeUpdate", "edge")
    # 2. Remove Edge packages
    Write-Log "Removing Microsoft Edge packages..."
    $edgePackages = @(
        "Microsoft.MicrosoftEdge",
        "Microsoft.MicrosoftEdge.Stable",
        "Microsoft.MicrosoftEdgeDevToolsClient"
    )
    foreach ($package in $edgePackages) {
        try {
            # Remove provisioned packages
            $provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$package*" } -ErrorAction SilentlyContinue
            if ($provisioned) {
                foreach ($p in $provisioned) {
                    try {
                        Write-Log ("Removing provisioned package: " + $p.PackageName)
                        Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop
                        Write-Log ("Successfully removed provisioned package: " + $p.PackageName)
                    } catch {
                        Write-Log ("Failed to remove provisioned package " + $p.PackageName + ": $_") -Level "ERROR"
                    }
                }
            }
            # Remove installed packages
            $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$package*" } -ErrorAction SilentlyContinue
            if ($installed) {
                foreach ($p in $installed) {
                    try {
                        Write-Log ("Removing installed package: " + $p.Name)
                        Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop
                        Write-Log ("Successfully removed installed package: " + $p.Name)
                    } catch {
                        Write-Log ("Failed to remove installed package " + $p.Name + ": $_") -Level "ERROR"
                    }
                }
            }
        } catch {
            Write-Log ("Error processing Microsoft Edge package ${package}: $_") -Level "ERROR"
        }
    }
    # 3. Remove Edge registry keys
    Write-Log "Removing Microsoft Edge registry keys..."
    Remove-EdgeRegistryKeys
    # 4. Remove Edge scheduled tasks
    Write-Log "Removing Microsoft Edge scheduled tasks..."
    Remove-EdgeTasks
    # 5. Remove Edge services
    Write-Log "Removing Microsoft Edge services..."
    Remove-EdgeServices
    # 6. Remove Edge folders
    Write-Log "Removing Microsoft Edge folders..."
    $edgeFolders = @(
        "$env:ProgramFiles (x86)\Microsoft\Edge",
        "$env:ProgramFiles\Microsoft\Edge",
        "$env:LocalAppData\Microsoft\Edge",
        "$env:LocalAppData\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe",
        "$env:LocalAppData\Packages\Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe"
    )
    foreach ($folder in $edgeFolders) {
        try {
            if (Test-Path $folder) {
                Write-Log ("Removing folder: $folder")
                Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                Write-Log ("Successfully removed folder: $folder")
            } else {
                Write-Log ("Folder not found: $folder") -Level "INFO"
            }
        } catch {
            Write-Log ("Failed to remove folder ${folder}: $_") -Level "ERROR"
        }
    }
    Write-Log "Microsoft Edge removal process completed."
}
# Main script execution
try {
    Write-Log "Script started."
    # First, remove Microsoft Edge completely
    Remove-MicrosoftEdge
    # List of apps to remove (Package Name Partial)
    $appsToRemove = @(
        @{Name="Mail and Calendar"; PackageNameFilter="WindowsCommunicationsApps"; IsCritical=$true},
        @{Name="Microsoft Sticky Notes"; PackageNameFilter="MicrosoftStickyNotes"; IsCritical=$false},
        @{Name="Calculator"; PackageNameFilter="WindowsCalculator"; IsCritical=$false},
        @{Name="Alarms & Clock"; PackageNameFilter="WindowsAlarms"; IsCritical=$false},
        @{Name="Voice Recorder"; PackageNameFilter="WindowsSoundRecorder"; IsCritical=$false},
        @{Name="Groove Music"; PackageNameFilter="ZuneMusic"; IsCritical=$false},
        @{Name="Camera"; PackageNameFilter="WindowsCamera"; IsCritical=$false},
        @{Name="Skype"; PackageNameFilter="SkypeApp"; IsCritical=$false},
        @{Name="OneNote"; PackageNameFilter="Office.OneNote"; IsCritical=$false},
        @{Name="People"; PackageNameFilter="People"; IsCritical=$false},
        @{Name="Feedback Hub"; PackageNameFilter="WindowsFeedbackHub"; IsCritical=$false},
        @{Name="Xbox TCUI"; PackageNameFilter="Xbox.TCUI"; IsCritical=$false},
        @{Name="Cortana"; PackageNameFilter="549981C3F5F10"; IsCritical=$true},
        @{Name="Maps"; PackageNameFilter="WindowsMaps"; IsCritical=$false},
        @{Name="Sports"; PackageNameFilter="BingSports"; IsCritical=$false},
        @{Name="Money"; PackageNameFilter="BingFinance"; IsCritical=$false},
        @{Name="Internet Explorer"; PackageNameFilter="InternetExplorer"; IsCritical=$false},
        @{Name="Get Help"; PackageNameFilter="GetHelp"; IsCritical=$false},
        @{Name="Get Started"; PackageNameFilter="Getstarted"; IsCritical=$false},
        @{Name="Office Hub"; PackageNameFilter="MicrosoftOfficeHub"; IsCritical=$false},
        @{Name="Solitaire Collection"; PackageNameFilter="MicrosoftSolitaireCollection"; IsCritical=$false},
        @{Name="Sway"; PackageNameFilter="Office.Sway"; IsCritical=$false},
        @{Name="OneConnect"; PackageNameFilter="OneConnect"; IsCritical=$false},
        @{Name="Power Automate"; PackageNameFilter="PowerAutomateDesktop"; IsCritical=$false},
        @{Name="Screen Sketch"; PackageNameFilter="ScreenSketch"; IsCritical=$false}
    )
    # Remove apps for all users
    foreach ($app in $appsToRemove) {
        Remove-App -AppName $app.Name -PackageNameFilter $app.PackageNameFilter -IsCritical $app.IsCritical
    }
    # Special handling for Microsoft News and Weather
    Remove-NewsAndWeather
    Write-Log "Script completed successfully." -Level "INFO"
    Write-Host "`nA system reboot is recommended to fully remove Microsoft Edge from memory." -ForegroundColor Yellow
} catch {
    $errorMsg = $_ | Out-String
    Write-Log ("Script terminated unexpectedly: " + $errorMsg) -Level "ERROR"
} finally {
    Write-Log "Script execution finished."
    Write-Host "`nScript completed. Log file saved to: $logFilePath" -ForegroundColor Green
    # Ensure the prompt appears even when run from a single command
    if ($Host.UI.RawUI.KeyAvailable) {
        $Host.UI.RawUI.FlushInputBuffer()
    }
    Write-Host "`nPress Enter to exit..."
    Read-Host
}
