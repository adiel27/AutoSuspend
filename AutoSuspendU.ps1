# Path to PsSuspend executable
$PsSuspendPath = "C:\PsTools\PsSuspend.exe"

# Path untuk log file
$LogFilePath = "C:\SuspendLog.txt"

# Idle threshold in seconds
$IdleThreshold = 300 # 5 minutes

# Interval to check activity
$CheckInterval = 10 # seconds

# List of processes to exclude (important system, driver, and security processes)
$ExcludedProcesses = @("System", "svchost", "explorer", "wininit", "csrss", "services", "lsass", 
                       "igfx", "amddvr", "RadeonSoftware", "DolbyDAX2", "DolbyCPL", "MsMpEng")

# List to keep track of suspended processes
$SuspendedProcesses = @()

# Import module for Windows toast notifications
Import-Module BurntToast

# Display startup notification
New-BurntToastNotification -Text "Suspender script berjalan", "Skrip otomatis sedang aktif"

# Hide PowerShell window (run script in background)
$PSWindow = Get-Process -Id $PID
$PSWindow.CloseMainWindow()

while ($true) {
    # Get list of running processes with window titles
    $Processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" }

    foreach ($Process in $Processes) {
        try {
            # Skip excluded processes
            if ($ExcludedProcesses -contains $Process.ProcessName) {
                continue
            }

            # Check if process is already suspended
            if ($SuspendedProcesses -contains $Process.Id) {
                # Check if user interacts with the process
                $IsActive = $Process.MainWindowHandle -ne 0

                if ($IsActive) {
                    # Resume the process
                    Start-Process -FilePath $PsSuspendPath -ArgumentList "-r $Process.Id" -NoNewWindow -Wait
                    Write-Host "$($Process.Name) has been resumed."
                    
                    # Log resume status
                    "$($Process.Name) [PID: $($Process.Id)] has been resumed at $(Get-Date)" | Out-File -Append $LogFilePath
                    
                    # Show resume notification
                    New-BurntToastNotification -Text "$($Process.Name) telah dilanjutkan"

                    $SuspendedProcesses = $SuspendedProcesses | Where-Object { $_ -ne $Process.Id }
                }
                continue
            }

            # Check CPU usage to detect idle state
            $CPUUsage = $Process | Select-Object -ExpandProperty CPU

            if ($CPUUsage -eq 0 -and $Process.MainWindowHandle -ne 0) {
                # Suspend the process
                Start-Process -FilePath $PsSuspendPath -ArgumentList "$Process.Id" -NoNewWindow -Wait
                Write-Host "$($Process.Name) has been suspended."

                # Log suspend status
                "$($Process.Name) [PID: $($Process.Id)] has been suspended at $(Get-Date)" | Out-File -Append $LogFilePath

                # Show suspend notification
                New-BurntToastNotification -Text "$($Process.Name) telah dibekukan karena idle"

                $SuspendedProcesses += $Process.Id
            }
        } catch {
            Write-Warning "Cannot access data for $($Process.Name)"
        }
    }
    Start-Sleep -Seconds $CheckInterval
}
