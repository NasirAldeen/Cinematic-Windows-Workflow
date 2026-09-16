param(
    [string]$WorkShortcutName = 'Start Cinematic Work',
    [string]$ChillShortcutName = 'Chill Mode'
)

$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$desktopDirectory = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell

function Install-WorkflowShortcut {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Launcher,
        [Parameter(Mandatory)] [string]$Description,
        [Parameter(Mandatory)] [string]$IconPath
    )

    $shortcutPath = Join-Path $desktopDirectory "$Name.lnk"
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $shortcut.Arguments = '"' + (Join-Path $projectDirectory $Launcher) + '"'
    $shortcut.WorkingDirectory = $projectDirectory
    $shortcut.IconLocation = "$IconPath,0"
    $shortcut.Description = $Description
    $shortcut.Save()
    Write-Host "Installed: $shortcutPath" -ForegroundColor Green
}

Install-WorkflowShortcut `
    -Name $WorkShortcutName `
    -Launcher 'Start-Work-Hidden.vbs' `
    -Description 'Start the cinematic Windows work environment' `
    -IconPath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')

$braveIcon = Join-Path $env:ProgramFiles 'BraveSoftware\Brave-Browser\Application\brave.exe'
if (-not (Test-Path -LiteralPath $braveIcon)) {
    $braveIcon = Join-Path $env:SystemRoot 'System32\shell32.dll'
}

Install-WorkflowShortcut `
    -Name $ChillShortcutName `
    -Launcher 'Start-Chill-Hidden.vbs' `
    -Description 'Close the work environment and open Brave' `
    -IconPath $braveIcon
