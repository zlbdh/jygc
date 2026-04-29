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

function Get-RemoteHeadBranch {
    param(
        [string]$RemoteUrl,
        [string]$WorkingDirectory
    )

    $result = Invoke-HarnessCommand -WorkingDirectory $WorkingDirectory -Command ("git ls-remote --symref {0} HEAD" -f $RemoteUrl)
    if ($result.ExitCode -ne 0) {
        return $null
    }

    foreach ($line in ($result.Output -split "`r?`n")) {
        if ($line -match '^ref:\s+refs/heads/(?<branch>\S+)\s+HEAD$') {
            return $Matches['branch']
        }
    }

    return $null
}

$repos = Get-HarnessRepoConfig
if ($RepoIds -and $RepoIds.Count -gt 0) {
    $repos = @($repos | Where-Object { $RepoIds -contains $_.id })
}

if ($repos.Count -eq 0) {
    throw "没有匹配到任何待克隆仓库。"
}

$results = @()

foreach ($repo in $repos) {
    $targetPath = [string]$repo.local_path
    $parentPath = Split-Path -Parent $targetPath
    $authUrl = Get-HarnessAuthenticatedRemoteUrl -Remote $repo.remote -AccessToken $AccessToken
    $action = ''
    $status = 'pending'
    $note = ''

    if (Test-Path -LiteralPath (Join-Path $targetPath '.git')) {
        $action = 'check-existing'
        $status = 'exists'
        $currentRemote = Get-HarnessGitOriginUrl -RepoPath $targetPath
        if ((Normalize-HarnessText $currentRemote) -ne (Normalize-HarnessText $repo.remote)) {
            $note = "现有 origin 与配置不一致：$currentRemote"
            $status = 'warning'
        } else {
            $note = '仓库已存在，未覆盖本地内容。'
        }
    } elseif (Test-Path -LiteralPath $targetPath) {
        $action = 'blocked'
        $status = 'blocked'
        $note = '目标目录已存在但不是 git 仓库，请人工处理后重试。'
    } else {
        $action = 'clone'
        if ($DryRun) {
            $status = 'dry-run'
            $note = "将克隆到 $targetPath"
        } else {
            Ensure-HarnessDirectory -Path $parentPath | Out-Null
            $targetBranch = [string]$repo.default_branch
            $cloneCommand = "git clone --branch {0} {1} ""{2}""" -f $targetBranch, $authUrl, $targetPath
            $cloneResult = Invoke-HarnessCommand -WorkingDirectory $parentPath -Command $cloneCommand

            if (($cloneResult.ExitCode -ne 0) -and ($cloneResult.Output -match 'Remote branch .* not found in upstream origin')) {
                $remoteHeadBranch = Get-RemoteHeadBranch -RemoteUrl $authUrl -WorkingDirectory $parentPath
                if (-not [string]::IsNullOrWhiteSpace($remoteHeadBranch) -and ($remoteHeadBranch -ne $targetBranch)) {
                    $targetBranch = $remoteHeadBranch
                    $cloneCommand = "git clone --branch {0} {1} ""{2}""" -f $targetBranch, $authUrl, $targetPath
                    $cloneResult = Invoke-HarnessCommand -WorkingDirectory $parentPath -Command $cloneCommand
                }
            }

            if ($cloneResult.ExitCode -eq 0) {
                $status = 'cloned'
                if ($targetBranch -eq [string]$repo.default_branch) {
                    $note = '克隆成功。'
                } else {
                    $note = "克隆成功，已自动回退到远端默认分支 $targetBranch。"
                }
                if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
                    $null = Invoke-HarnessCommand -WorkingDirectory $targetPath -Command ("git remote set-url origin {0}" -f $repo.remote)
                }
            } else {
                $status = 'failed'
                $note = $cloneResult.Output
            }
        }
    }

    $results += [pscustomobject]@{
        id = $repo.id
        name = $repo.name
        action = $action
        status = $status
        target = $targetPath
        note = $note
    }
}

$results | Format-Table -AutoSize | Out-Host
if ($PassThru) {
    return $results
}
