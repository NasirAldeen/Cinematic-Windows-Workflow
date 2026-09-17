# Update-DailyLearningLog.ps1
# Records one genuine Work Mode session per day, commits it, and pushes it.

param([switch]$Validate)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ProjectRoot 'config.psd1'
$UpdateLogPath = Join-Path $ProjectRoot 'GitHub-Update.log'

function Write-UpdateLog {
    param([Parameter(Mandatory)] [string]$Message)

    $singleLineMessage = $Message -replace '[\r\n]+', ' | '
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'), $singleLineMessage
    Add-Content -LiteralPath $UpdateLogPath -Value $line -Encoding UTF8
}

try {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Configuration not found: $ConfigPath"
    }

    $config = Import-PowerShellDataFile -LiteralPath $ConfigPath
    $settings = $config.DailyLearningLog
    if (-not $settings -or -not $settings.Enabled) {
        if ($Validate) {
            Write-Host 'Daily learning-log updates are disabled in config.psd1.' -ForegroundColor Yellow
        }
        exit 0
    }

    $repositoryPath = [Environment]::ExpandEnvironmentVariables([string]$settings.RepositoryPath)
    $logFileName = [string]$settings.LogFileName
    $remoteName = [string]$settings.RemoteName
    $branchName = [string]$settings.BranchName
    $activityMessage = [string]$settings.ActivityMessage

    function Invoke-Git {
        param([Parameter(Mandatory)] [string[]]$Arguments)

        # Trust only the configured repository for this command. This also
        # supports folders created by a Windows sandbox or automation account.
        $previousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @(& git.exe -c "safe.directory=$repositoryPath" -C $repositoryPath @Arguments 2>&1)
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorPreference
        }
        if ($exitCode -ne 0) {
            $details = ($output | Out-String).Trim()
            throw "git $($Arguments -join ' ') failed with exit code ${exitCode}: $details"
        }
        return ($output | Out-String).Trim()
    }

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw 'Git was not found in PATH.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryPath '.git'))) {
        throw "The learning-log repository was not found at: $repositoryPath"
    }

    $logFilePath = Join-Path $repositoryPath $logFileName
    if (-not (Test-Path -LiteralPath $logFilePath)) {
        throw "The learning-log file was not found at: $logFilePath"
    }

    $currentBranch = Invoke-Git -Arguments @('branch', '--show-current')
    if ($currentBranch -ne $branchName) {
        throw "Expected branch '$branchName', but '$currentBranch' is checked out."
    }

    $dirtyState = Invoke-Git -Arguments @('status', '--porcelain')
    if ($dirtyState) {
        throw 'The learning-log repository has uncommitted changes. Nothing was changed or committed.'
    }

    if ($Validate) {
        Write-Host "Validation passed: $repositoryPath is clean and ready on $branchName." -ForegroundColor Green
        exit 0
    }

    Invoke-Git -Arguments @('pull', '--ff-only', $remoteName, $branchName) | Out-Null

    $today = Get-Date -Format 'yyyy-MM-dd'
    $existingContent = Get-Content -LiteralPath $logFilePath -Raw
    if ($existingContent -match "(?m)^## $([Regex]::Escape($today))\r?$") {
        Invoke-Git -Arguments @('push', $remoteName, $branchName) | Out-Null
        Write-UpdateLog "Already recorded today's work session; repository is synchronized."
        exit 0
    }

    $time = Get-Date -Format 'HH:mm zzz'
    $entry = "`r`n## $today`r`n- $time - $activityMessage`r`n"
    Add-Content -LiteralPath $logFilePath -Value $entry -Encoding UTF8

    Invoke-Git -Arguments @('add', '--', $logFileName) | Out-Null
    $stagedChanges = Invoke-Git -Arguments @('diff', '--cached', '--name-only', '--', $logFileName)
    if (-not $stagedChanges) {
        Write-UpdateLog 'No learning-log change was available to commit.'
        exit 0
    }

    Invoke-Git -Arguments @('commit', '-m', "Log work session for $today", '--', $logFileName) | Out-Null
    Invoke-Git -Arguments @('push', $remoteName, $branchName) | Out-Null
    $commit = Invoke-Git -Arguments @('rev-parse', '--short', 'HEAD')
    Write-UpdateLog "Success: committed and pushed today's work session ($commit)."
}
catch {
    try {
        Write-UpdateLog "FAILED: $($_.Exception.Message)"
    }
    catch {
        # This optional background feature must never block Work Mode.
    }
    exit 1
}
