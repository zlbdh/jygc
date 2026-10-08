[CmdletBinding()]
param(
    [string[]]$RepoIds,
    [switch]$DryRun,
    [string]$AccessToken,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

$repos = Get-HarnessRepoConfig
if ($RepoIds -and $RepoIds.Count -gt 0) {
    $repos = @($repos | Where-Object { $RepoIds -contains $_.id })
}

if ($repos.Count -eq 0) {
    throw "No repositories matched the synchronization request."
}

$results = @()

foreach ($repo in $repos) {
    $repoPath = [string]$repo.local_path
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
        $results += [pscustomobject]@{
            id = $repo.id
            status = 'missing'
            branch = ''
            dirty = ''
            remote_ok = $false
            note = 'The local repository does not exist and cannot be synchronized.'
        }
        continue
    }

    $remoteUrl = Get-HarnessGitOriginUrl -RepoPath $repoPath
    $remoteOk = (Normalize-HarnessText $remoteUrl) -eq (Normalize-HarnessText $repo.remote)
    $branchResult = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command 'git branch --show-current'
    $dirtyResult = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command 'git status --porcelain'
    $branch = Normalize-HarnessText $branchResult.Output
    $dirty = -not [string]::IsNullOrWhiteSpace((Normalize-HarnessText $dirtyResult.Output))
    $note = ''
    $status = 'checked'

    if (-not $DryRun) {
        $fetchRemoteWasChanged = $false
        try {
            if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
                $authUrl = Get-HarnessAuthenticatedRemoteUrl -Remote $repo.remote -AccessToken $AccessToken
                if ((Normalize-HarnessText $remoteUrl) -ne (Normalize-HarnessText $authUrl)) {
                    $null = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command ("git remote set-url origin {0}" -f $authUrl)
                    $fetchRemoteWasChanged = $true
                }
            }

            $fetchResult = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command 'git fetch --all --prune'
            if ($fetchResult.ExitCode -ne 0) {
                $status = 'fetch-failed'
                $note = $fetchResult.Output
            } else {
                $status = 'fetched'
                $note = 'Completed fetch --all --prune.'
            }
        } finally {
            if ($fetchRemoteWasChanged) {
                $null = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command ("git remote set-url origin {0}" -f $repo.remote)
            }
        }
    } else {
        $status = 'dry-run'
        $note = 'Will run git fetch --all --prune.'
    }

    $results += [pscustomobject]@{
        id = $repo.id
        status = $status
        branch = $branch
        dirty = $dirty
        remote_ok = $remoteOk
        note = $note
    }
}

$results | Format-Table -AutoSize | Out-Host
if ($PassThru) {
    return $results
}
