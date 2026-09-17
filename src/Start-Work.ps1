# Start-Work.ps1
# Opens one Windows Terminal window and adds six PowerShell tabs one at a time.

param(
    [switch]$Preview,
    [switch]$Validate,
    [switch]$Cinematic
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ProjectRoot 'config.psd1'
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Configuration not found: $ConfigPath" }
$Config = Import-PowerShellDataFile -LiteralPath $ConfigPath

function Expand-ConfiguredPath {
    param([Parameter(Mandatory)] [string]$Path)
    [Environment]::ExpandEnvironmentVariables($Path)
}

# ----------------------------- SETTINGS ------------------------------
$WindowsTerminalPath = Expand-ConfiguredPath $Config.Apps.WindowsTerminal
$TerminalWindowName  = "AI-Work-$PID"
$WslDistribution     = $Config.WslDistribution
$MimoCommand         = $Config.MimoCommand
$FeynmanCommand      = "wsl.exe -d $WslDistribution -- $($Config.FeynmanLinuxCommand)"
$ClaudeCommand       = $Config.ClaudeCommand
$CodexCommand        = $Config.CodexCommand
$ToofanPath          = Expand-ConfiguredPath $Config.ToofanPath

$VsCodeCommand       = Expand-ConfiguredPath $Config.Apps.VSCode
$KeyboardSoundsPath  = Expand-ConfiguredPath $Config.Apps.KeyboardSounds
$HandyPath            = Expand-ConfiguredPath $Config.Apps.Handy
$RovylPath            = Expand-ConfiguredPath $Config.Apps.Rovyl
$OperaGxPath          = Expand-ConfiguredPath $Config.Apps.OperaGX
$WhatsAppUrl          = $Config.Urls.WhatsApp
$YouTubeUrl           = $Config.Urls.Music
$CinematicMarkerPath  = Join-Path $ProjectRoot 'cinematic-intro.active'
$DailyLearningUpdater = Join-Path $PSScriptRoot 'Update-DailyLearningLog.ps1'
# ---------------------------------------------------------------------

if ($Preview) {
    Write-Host '[Preview] One Windows Terminal window with six PowerShell tabs:' -ForegroundColor Cyan
    Write-Host '  1. mimo  2. wsl  3. feynman after 10 seconds  4. claude  5. codex  6. toofan' -ForegroundColor Cyan
    Write-Host '  Terminal on the right; VS Code on the left.' -ForegroundColor Cyan
    Write-Host '  Plus Keyboard Sounds, Handy, Rovyl, and Opera GX with WhatsApp + YouTube.' -ForegroundColor Cyan
    if ($Config.DailyLearningLog.Enabled) {
        Write-Host '  Updates the configured daily learning-log repository in the background.' -ForegroundColor Cyan
    }
    if ($Cinematic) { Write-Host '  Cinematic overlay enabled; Opera waits until the overlay closes.' -ForegroundColor Cyan }
    exit 0
}

if (-not $Validate -and -not (Test-Path -LiteralPath $WindowsTerminalPath)) {
    throw "Windows Terminal was not found at: $WindowsTerminalPath"
}

$transcriptStarted = $false
if (-not $Validate) {
    try {
        Start-Transcript -Path (Join-Path $ProjectRoot 'Start-Work.log') -Force | Out-Null
        $transcriptStarted = $true
    }
    catch {
        # Logging must never prevent the workflow from starting.
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class WindowLayout {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    public static IntPtr[] GetVisibleWindowsForProcess(int processId) {
        var handles = new List<IntPtr>();
        EnumWindows((hWnd, lParam) => {
            uint ownerProcessId;
            GetWindowThreadProcessId(hWnd, out ownerProcessId);
            if (ownerProcessId == processId && IsWindowVisible(hWnd)) {
                handles.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return handles.ToArray();
    }

    public static long GetWindowArea(IntPtr hWnd) {
        RECT rect;
        if (!GetWindowRect(hWnd, out rect)) return 0;
        return Math.Max(0, rect.Right - rect.Left) * (long)Math.Max(0, rect.Bottom - rect.Top);
    }
}
"@

function Get-AppWindowHandles {
    param([Parameter(Mandatory)] [string[]]$ProcessNames)

    $seenHandles = @{}
    foreach ($processName in $ProcessNames) {
        foreach ($process in @(Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
            try {
                foreach ($handle in [WindowLayout]::GetVisibleWindowsForProcess($process.Id)) {
                    $handleNumber = $handle.ToInt64()
                    if ($handleNumber -ne 0 -and -not $seenHandles.ContainsKey($handleNumber)) {
                        $seenHandles[$handleNumber] = $true
                        Write-Output $handle
                    }
                }
            }
            catch {
                # A short-lived launcher may exit while its windows are being inspected.
            }
        }
    }
}

function Minimize-AppWindows {
    param(
        [Parameter(Mandatory)] [string[]]$ProcessNames,
        [int]$DurationMilliseconds = 2000
    )

    $foundNames = @{}
    $deadline = [DateTime]::UtcNow.AddMilliseconds($DurationMilliseconds)
    do {
        foreach ($processName in $ProcessNames) {
            $handles = @(Get-AppWindowHandles -ProcessNames @($processName))
            if ($handles.Count -gt 0) { $foundNames[$processName] = $true }
            foreach ($handle in $handles) {
                [WindowLayout]::ShowWindowAsync([IntPtr]$handle, 6) | Out-Null
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    foreach ($processName in $ProcessNames) {
        if ($foundNames.ContainsKey($processName)) {
            Write-Host "Minimized $processName." -ForegroundColor Green
        }
        else {
            Write-Host "$processName started without a visible top-level window (usually a tray app)." -ForegroundColor Yellow
        }
    }
}

function Set-WindowHalf {
    param(
        [Parameter(Mandatory)] [string[]]$ProcessNames,
        [Parameter(Mandatory)] [ValidateSet('Left','Right')] [string]$Side,
        [long[]]$ExcludeHandles = @(),
        [int]$TimeoutMilliseconds = 2500
    )

    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $halfWidth = [int]($area.Width / 2)
    $x = if ($Side -eq 'Left') { $area.Left } else { $area.Left + $halfWidth }
    $width = if ($Side -eq 'Left') { $halfWidth } else { $area.Width - $halfWidth }

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $candidateHandles = @(Get-AppWindowHandles -ProcessNames $ProcessNames |
            Where-Object { $ExcludeHandles -notcontains $_.ToInt64() } |
            Sort-Object { [WindowLayout]::GetWindowArea([IntPtr]$_) } -Descending)

        foreach ($handle in $candidateHandles) {
            # Ignore tiny splash/helper windows and wait for the real app window.
            if ([WindowLayout]::GetWindowArea([IntPtr]$handle) -lt 150000) { continue }

            [WindowLayout]::ShowWindowAsync([IntPtr]$handle, 9) | Out-Null
            Start-Sleep -Milliseconds 50
            [WindowLayout]::SetWindowPos([IntPtr]$handle, [IntPtr]::Zero, $x, $area.Top, $width, $area.Height, 0x0044) | Out-Null
            Write-Host "Placed $($ProcessNames -join ', ') on the $Side side." -ForegroundColor Green
            return $true
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    Write-Host "Could not find a full app window for $($ProcessNames -join ', ') to place on the $Side side." -ForegroundColor Yellow
    return $false
}

function Add-PowerShellTab {
    param([Parameter(Mandatory)] [string]$Command)

    # Every tab targets this run's unique named window. Never use -w 0 here:
    # 0 means "most recently used window" and can split tabs across old windows.
    Start-Process -FilePath $WindowsTerminalPath -ArgumentList @('-w', $TerminalWindowName, 'new-tab', 'powershell.exe', '-NoExit', '-Command', $Command)
}

if ($Validate) {
    Write-Host 'Validation passed: PowerShell and Windows window-control code loaded successfully.' -ForegroundColor Green
    if ($Config.DailyLearningLog.Enabled -and -not (Test-Path -LiteralPath $DailyLearningUpdater)) {
        throw "Daily learning-log updater was not found at: $DailyLearningUpdater"
    }
    foreach ($validationName in @('WindowsTerminal', 'Code', 'Keyboard Sounds', 'handy', 'Rovyl', 'opera')) {
        $validationHandles = @(Get-AppWindowHandles -ProcessNames @($validationName))
        Write-Host ("  {0}: {1} visible top-level window(s)" -f $validationName, $validationHandles.Count)
    }
    exit 0
}

# Keep Git network work outside the startup path. The optional updater runs in
# a separate hidden process and writes its result to GitHub-Update.log.
if ($Config.DailyLearningLog.Enabled) {
    if (Test-Path -LiteralPath $DailyLearningUpdater) {
        $updaterArguments = @(
            '-NoProfile',
            '-NonInteractive',
            '-WindowStyle', 'Hidden',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $DailyLearningUpdater)
        )
        Start-Process -FilePath 'powershell.exe' -ArgumentList $updaterArguments -WindowStyle Hidden
        Write-Host 'Started the daily learning-log update in the background.' -ForegroundColor Green
    }
    else {
        Write-Warning "Daily learning-log updater was not found at: $DailyLearningUpdater"
    }
}

# First tab creates the one terminal window. The layout helper waits only
# until Windows exposes the window; there is no intentional startup pause.
$terminalHandlesBefore = @(
    Get-AppWindowHandles -ProcessNames @('WindowsTerminal') |
        ForEach-Object { $_.ToInt64() }
)
Start-Process -FilePath $WindowsTerminalPath -ArgumentList @('-w', $TerminalWindowName, 'new-tab', 'powershell.exe', '-NoExit', '-Command', $MimoCommand)

# Add WSL immediately. Feynman is deliberately delayed by ten seconds after it.
$wslLaunchTime = [DateTime]::UtcNow
Add-PowerShellTab -Command "wsl.exe -d $WslDistribution"

# Position the terminal while the WSL tab is starting, before the requested delay.
Set-WindowHalf -ProcessNames @('WindowsTerminal') -Side Right -ExcludeHandles $terminalHandlesBefore | Out-Null

# Launch the Windows programs during the WSL-to-Feynman delay.
foreach ($program in @(
    @{ Name = 'VS Code'; Path = $VsCodeCommand; Minimized = $false },
    @{ Name = 'Keyboard Sounds'; Path = $KeyboardSoundsPath; Minimized = $true },
    @{ Name = 'Handy'; Path = $HandyPath; Minimized = $true },
    @{ Name = 'Rovyl'; Path = $RovylPath; Minimized = $true }
)) {
    if (Test-Path -LiteralPath $program.Path) {
        $workingDirectory = Split-Path -Parent $program.Path
        $launchStyle = if ($program.Minimized) { 'Minimized' } else { 'Normal' }
        Start-Process -FilePath $program.Path -WorkingDirectory $workingDirectory -WindowStyle $launchStyle
        Write-Host "Opened $($program.Name)" -ForegroundColor Green
    }
    else {
        Write-Warning "$($program.Name) was not found at: $($program.Path)"
    }
}

# Electron apps often hand Start-Process a short-lived launcher rather than the
# real window. Enumerate their actual top-level windows and minimize those.
Minimize-AppWindows -ProcessNames @('Keyboard Sounds', 'handy', 'Rovyl')

# Keep VS Code beside the terminal on the left half of the screen.
Set-WindowHalf -ProcessNames @('Code') -Side Left | Out-Null

# This preserves exactly one intentional delay: WSL -> Feynman is at least 10 seconds.
$elapsedMilliseconds = ([DateTime]::UtcNow - $wslLaunchTime).TotalMilliseconds
$remainingMilliseconds = [Math]::Max(0, [int](10000 - $elapsedMilliseconds))
if ($remainingMilliseconds -gt 0) {
    Start-Sleep -Milliseconds $remainingMilliseconds
}

# Finish the terminal tabs after the WSL delay.
Add-PowerShellTab -Command $FeynmanCommand
Add-PowerShellTab -Command $ClaudeCommand
Add-PowerShellTab -Command $CodexCommand
Add-PowerShellTab -Command "& '$ToofanPath'"

Write-Host 'Opened six PowerShell tabs: Mimo, WSL, Feynman, Claude, Toofan, Codex.' -ForegroundColor Green

# Keep YouTube from competing with the cinematic soundtrack. Esc removes the
# marker immediately, so skipping the intro also skips this wait.
if ($Cinematic) {
    $cinematicDeadline = [DateTime]::UtcNow.AddSeconds(9)
    while ((Test-Path -LiteralPath $CinematicMarkerPath) -and [DateTime]::UtcNow -lt $cinematicDeadline) {
        Start-Sleep -Milliseconds 100
    }
}

# Open both requested pages in Opera GX after the intro has cleared.
if (Test-Path -LiteralPath $OperaGxPath) {
    Start-Process -FilePath $OperaGxPath -ArgumentList @($WhatsAppUrl, $YouTubeUrl) -WorkingDirectory (Split-Path -Parent $OperaGxPath) -WindowStyle Minimized
    # Final settle pass: Keyboard Sounds and Rovyl can create their real Electron
    # windows long after their launcher processes start. Catch every late window,
    # together with Opera, after the cinematic overlay has finished.
    Minimize-AppWindows -ProcessNames @('Keyboard Sounds', 'handy', 'Rovyl', 'opera') -DurationMilliseconds 3500
    Write-Host 'Opened WhatsApp and YouTube in Opera GX.' -ForegroundColor Green
}
else {
    Write-Warning "Opera GX was not found at: $OperaGxPath"
}

if ($transcriptStarted) {
    Stop-Transcript | Out-Null
}
