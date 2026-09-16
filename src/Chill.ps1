# Chill.ps1
# Closes every running instance of the Work-mode apps, shuts down WSL,
# then opens Brave. Run with -Preview to inspect the targets safely.

param([switch]$Preview)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ProjectRoot 'config.psd1'
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Configuration not found: $ConfigPath" }
$Config = Import-PowerShellDataFile -LiteralPath $ConfigPath

# ----------------------------- SETTINGS ------------------------------
$ProcessNames = @($Config.CloseProcesses)
$BravePath = [Environment]::ExpandEnvironmentVariables($Config.Apps.Brave)
$LogPath   = Join-Path $ProjectRoot 'Chill.log'
# ---------------------------------------------------------------------

if ($Preview) {
    Write-Host '[Preview] Chill Mode will force-close every instance of:' -ForegroundColor Cyan
    foreach ($processName in $ProcessNames) {
        $count = @(Get-Process -Name $processName -ErrorAction SilentlyContinue).Count
        Write-Host ("  {0}: {1} running process(es)" -f $processName, $count) -ForegroundColor Cyan
    }
    Write-Host '[Preview] Shut down every running WSL distribution.' -ForegroundColor Cyan
    Write-Host "[Preview] Open Brave: $BravePath" -ForegroundColor Cyan
    exit 0
}

$transcriptStarted = $false
try {
    try {
        Start-Transcript -Path $LogPath -Force | Out-Null
        $transcriptStarted = $true
    }
    catch {
        # Logging must never prevent Chill Mode from running.
    }

    foreach ($processName in $ProcessNames) {
        $targets = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
        if ($targets.Count -eq 0) {
            Write-Host "$processName was not running."
            continue
        }

        foreach ($target in $targets) {
            try {
                if ($processName -eq 'WindowsTerminal') {
                    # /T also closes the PowerShell tabs and their CLI children
                    # (Mimo, Claude, Codex, and Toofan), not only the window shell.
                    & "$env:SystemRoot\System32\taskkill.exe" /PID $target.Id /T /F 2>$null | Out-Null
                }
                else {
                    Stop-Process -Id $target.Id -Force -ErrorAction Stop
                }
            }
            catch {
                Write-Warning "Could not stop $processName (PID $($target.Id)): $($_.Exception.Message)"
            }
        }
        Write-Host "Closed every $processName process." -ForegroundColor Green
    }

    # This terminates WSL, Feynman, and any remaining Linux-side processes.
    try {
        & "$env:SystemRoot\System32\wsl.exe" --shutdown
        Write-Host 'Shut down WSL.' -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not shut down WSL: $($_.Exception.Message)"
    }

    Start-Sleep -Milliseconds 500

    if (Test-Path -LiteralPath $BravePath) {
        Start-Process -FilePath $BravePath
        Write-Host 'Brave opened for chill time.' -ForegroundColor Green
    }
    else {
        Write-Warning "Brave was not found at: $BravePath"
    }
}
finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}
