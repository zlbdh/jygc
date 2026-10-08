[CmdletBinding()]
param(
    [string[]]$RepoIds,
    [switch]$SkipCommandExecution,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

function Test-DefaultBranchPresence {
    param(
        [string]$RepoPath,
        [string]$BranchName
    )

    $localResult = Invoke-HarnessCommand -WorkingDirectory $RepoPath -Command ("git show-ref --verify refs/heads/{0}" -f $BranchName)
    if ($localResult.ExitCode -eq 0) {
        return $true
    }

    $remoteResult = Invoke-HarnessCommand -WorkingDirectory $RepoPath -Command ("git show-ref --verify refs/remotes/origin/{0}" -f $BranchName)
    return ($remoteResult.ExitCode -eq 0)
}

function Get-ProfileManifestsPresent {
    param(
        [pscustomobject]$Repo,
        [string]$RepoPath
    )

    switch ([string]$Repo.validation_profile) {
        'backend-maven' {
            return (Test-Path -LiteralPath (Join-Path $RepoPath 'pom.xml'))
        }
        'web-vite' {
            return (Test-Path -LiteralPath (Join-Path $RepoPath 'package.json'))
        }
        'mobile-rn' {
            return (Test-Path -LiteralPath (Join-Path $RepoPath 'package.json'))
        }
        'miniapp' {
            return (
                (Test-Path -LiteralPath (Join-Path $RepoPath 'package.json')) -or
                (Test-Path -LiteralPath (Join-Path $RepoPath 'project.config.json')) -or
                (Test-Path -LiteralPath (Join-Path $RepoPath 'app.json'))
            )
        }
    }

    return $false
}

function Test-HarnessEnvironmentLimitedFailure {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    # Match English diagnostics and retain legacy Chinese diagnostics from external tools.
    return $Text -match 'environment restrictions|not installed locally|LocalRepositoryNotAccessibleException|Could not create local repository|spawn EPERM|blocked by policy|sandbox|权限限制|受环境限制|当前环境.*阻止|无法执行'
}

$validateReposScript = Join-Path (Get-HarnessRepoRoot) 'scripts\checks\validate-repos.ps1'
& $validateReposScript

$contracts = & (Join-Path $PSScriptRoot 'discover-contracts.ps1') -RepoIds $RepoIds -NoReport -PassThru
$repos = Get-HarnessRepoConfig
if ($RepoIds -and $RepoIds.Count -gt 0) {
    $repos = @($repos | Where-Object { $RepoIds -contains $_.id })
}

$toolAvailability = [ordered]@{
    git = (Test-HarnessCommandExists -Name 'git')
    mvn = (Test-HarnessCommandExists -Name 'mvn')
    node = (Test-HarnessCommandExists -Name 'node')
    npm = (Test-HarnessCommandExists -Name 'npm')
    npx = (Test-HarnessCommandExists -Name 'npx')
}

$matrix = @()
$blockers = New-Object System.Collections.Generic.List[string]
$recommendations = New-Object System.Collections.Generic.List[string]

foreach ($repo in $repos) {
    $contract = $contracts | Where-Object { $_.id -eq $repo.id } | Select-Object -First 1
    $repoPath = [string]$repo.local_path
    $l1Status = 'PASS'
    $l2Status = 'PASS'
    $findings = New-Object System.Collections.Generic.List[string]
    $commands = @()

    $localExists = Test-Path -LiteralPath $repoPath
    $gitExists = Test-Path -LiteralPath (Join-Path $repoPath '.git')
    $remoteOk = $false
    $branchOk = $false
    $dirty = $false
    $manifestOk = $false
    $envOk = $true
    $executedChecks = @()

    if (-not $localExists) {
        $l1Status = 'FAIL'
        $l2Status = 'SKIP'
        $findings.Add('The repository has not been cloned locally.')
        $blockers.Add("$($repo.id): Not cloned locally.")
        $recommendations.Add("$($repo.id): Run scripts/bootstrap/clone-repos.ps1 to synchronize repositories first.")
    } elseif (-not $gitExists) {
        $l1Status = 'FAIL'
        $l2Status = 'SKIP'
        $findings.Add('The directory exists but is not a Git repository.')
        $blockers.Add("$($repo.id): The directory exists but is not a Git repository.")
        $recommendations.Add("$($repo.id): Resolve the invalid directory, then clone the standard repository again.")
    } else {
        $remoteUrl = Get-HarnessGitOriginUrl -RepoPath $repoPath
        $remoteOk = (Normalize-HarnessText $remoteUrl) -eq (Normalize-HarnessText $repo.remote)
        $branchOk = Test-DefaultBranchPresence -RepoPath $repoPath -BranchName ([string]$repo.default_branch)
        $dirtyResult = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command 'git status --porcelain'
        $dirty = -not [string]::IsNullOrWhiteSpace((Normalize-HarnessText $dirtyResult.Output))
        $manifestOk = Get-ProfileManifestsPresent -Repo $repo -RepoPath $repoPath

        if (-not $remoteOk) {
            $l1Status = 'WARN'
            $findings.Add('The origin remote differs from repos.yaml.')
            $recommendations.Add("$($repo.id): Correct the origin remote URL.")
        }

        if (-not $branchOk) {
            $l1Status = 'WARN'
            $findings.Add("Default branch $($repo.default_branch) was not found locally or in origin.")
            $recommendations.Add("$($repo.id): Correct default_branch in repos.yaml or synchronize the remote default branch.")
        }

        if (-not $manifestOk) {
            $l1Status = 'FAIL'
            $findings.Add('A required manifest is missing; safe self-checks cannot start.')
            $blockers.Add("$($repo.id): A required manifest is missing.")
            $recommendations.Add("$($repo.id): Add the project entry point and required manifests before starting L2 safe self-checks.")
        }

        if ($dirty) {
            if ($l1Status -eq 'PASS') {
                $l1Status = 'WARN'
            }
            $findings.Add('The workspace has uncommitted changes.')
            $recommendations.Add("$($repo.id): Resolve workspace changes before rerunning the local baseline.")
        }
    }

    if ($l1Status -ne 'FAIL') {
        switch ([string]$repo.validation_profile) {
            'backend-maven' {
                if (-not $toolAvailability.mvn) {
                    $envOk = $false
                    $findings.Add('mvn is not installed locally.')
                }
            }
            'web-vite' {
                foreach ($tool in @('node', 'npm', 'npx')) {
                    if (-not $toolAvailability[$tool]) {
                        $envOk = $false
                        $findings.Add("$tool is not installed locally.")
                    }
                }
            }
            'mobile-rn' {
                foreach ($tool in @('node', 'npm', 'npx')) {
                    if (-not $toolAvailability[$tool]) {
                        $envOk = $false
                        $findings.Add("$tool is not installed locally.")
                    }
                }
            }
            'miniapp' {
                foreach ($tool in @('node', 'npm')) {
                    if (-not $toolAvailability[$tool]) {
                        $envOk = $false
                        $findings.Add("$tool is not installed locally.")
                    }
                }
            }
        }
    }

    if (-not $envOk) {
        if ($l2Status -eq 'PASS') {
            $l2Status = 'WARN'
        }
        if ([string]$repo.status -eq 'baseline-ready') {
            $recommendations.Add("$($repo.id): Set up the local runtime before running baseline commands.")
        }
    }

    if ($l1Status -eq 'FAIL') {
        $l2Status = 'SKIP'
    } else {
        if (($repo.status -in @('missing-contract', 'missing-local-env')) -or ($contract.suggested_status -in @('missing-contract', 'missing-local-env'))) {
            if ($l2Status -eq 'PASS') {
                $l2Status = 'WARN'
            }
            $findings.Add("The configured repository status is $($repo.status). Use it for discovery and inventory only, not as pre-release verification evidence yet.")
            if ($contract.suggested_status -eq 'missing-local-env') {
                $recommendations.Add("$($repo.id): Install local dependencies before including this repository in pre-release verification.")
            } else {
                $recommendations.Add("$($repo.id): Complete the command contract and project scaffolding before including this repository in pre-release verification.")
            }
        } elseif (-not $SkipCommandExecution -and $envOk) {
            $bootstrapCommand = [string]$repo.bootstrap_command
            if (-not [string]::IsNullOrWhiteSpace($bootstrapCommand)) {
                $bootstrapResult = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command $bootstrapCommand
                $executedChecks += [pscustomobject]@{
                    phase = 'bootstrap'
                    command = $bootstrapCommand
                    exit_code = $bootstrapResult.ExitCode
                }
                if ($bootstrapResult.ExitCode -ne 0) {
                    if (Test-HarnessEnvironmentLimitedFailure -Text $bootstrapResult.Output) {
                        $l2Status = 'BLOCKED'
                        $findings.Add("Environment restrictions prevent execution of bootstrap_command: $bootstrapCommand")
                        $recommendations.Add("$($repo.id): Rerun bootstrap_command in an environment that allows local dependencies and subprocesses.")
                    } else {
                        $l2Status = 'FAIL'
                        $findings.Add("bootstrap_command failed: $bootstrapCommand")
                        $recommendations.Add("$($repo.id): Fix bootstrap_command before rerunning L2.")
                    }
                    $findings.Add($bootstrapResult.Output)
                }
            }

            if ($l2Status -notin @('FAIL', 'BLOCKED')) {
                foreach ($command in @($repo.safe_check_commands)) {
                    if ([string]::IsNullOrWhiteSpace([string]$command)) {
                        continue
                    }

                    $result = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command ([string]$command)
                    $executedChecks += [pscustomobject]@{
                        phase = 'safe-check'
                        command = [string]$command
                        exit_code = $result.ExitCode
                    }

                    if ($result.ExitCode -ne 0) {
                        if (Test-HarnessEnvironmentLimitedFailure -Text $result.Output) {
                            $l2Status = 'BLOCKED'
                            $findings.Add("Environment restrictions prevent completion of the safe check: $command")
                            $recommendations.Add("$($repo.id): Rerun safe checks in an environment that allows local dependencies and subprocesses.")
                        } else {
                            $l2Status = 'FAIL'
                            $findings.Add("Safe check failed: $command")
                            $recommendations.Add("$($repo.id): Fix failing safe-check commands before restoring a passing pre-release status.")
                        }
                        if (-not [string]::IsNullOrWhiteSpace($result.Output)) {
                            $findings.Add($result.Output)
                        }
                        break
                    }
                }
            }
        } else {
            if ($SkipCommandExecution -and $l2Status -eq 'PASS') {
                $l2Status = 'WARN'
                $findings.Add('Actual command execution was skipped; only structural checks were completed.')
            }
        }
    }

    $overall = 'PASS'
    if ($l1Status -eq 'FAIL' -or $l2Status -eq 'FAIL') {
        $overall = 'FAIL'
    } elseif ($l2Status -eq 'BLOCKED') {
        $overall = 'WARN'
    } elseif ($l1Status -eq 'WARN' -or $l2Status -eq 'WARN') {
        $overall = 'WARN'
    }

    $matrix += [pscustomobject]@{
        id = $repo.id
        name = $repo.name
        role = $repo.role
        validation_profile = $repo.validation_profile
        configured_status = $repo.status
        contract_status = $contract.suggested_status
        l1_status = $l1Status
        l2_status = $l2Status
        overall_status = $overall
        local_exists = $localExists
        git_exists = $gitExists
        remote_ok = $remoteOk
        default_branch_ok = $branchOk
        worktree_dirty = $dirty
        manifest_ok = $manifestOk
        env_ok = $envOk
        executed_checks = $executedChecks
        findings = @($findings)
        missing_contract = ($contract.suggested_status -eq 'missing-contract')
        missing_local_env = ($contract.suggested_status -eq 'missing-local-env')
        environment_limited = ($l2Status -eq 'BLOCKED')
    }
}

$reportDir = Get-HarnessValidationReportDir
$timestamp = Get-HarnessTimestamp
$summaryPath = Join-Path $reportDir ($timestamp + '-summary.md')
$matrixPath = Join-Path $reportDir ($timestamp + '-matrix.json')

$summaryLines = @(
    '# Local baseline verification report',
    '',
    "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    '',
    '## Tool availability',
    ''
)

foreach ($tool in $toolAvailability.Keys) {
    $summaryLines += "- ${tool}: $($toolAvailability[$tool])"
}

$summaryLines += ''
$summaryLines += '## Repository matrix'
$summaryLines += ''
$summaryLines += '| Repository | L1 | L2 | Overall | Configured status | Contract discovery | Key findings |'
$summaryLines += '|------|----|----|------|----------|----------|----------|'

foreach ($item in $matrix) {
    $findingParts = @()
    foreach ($finding in @($item.findings | Select-Object -First 2)) {
        $firstLine = ((Normalize-HarnessText ([string]$finding)) -split "`n" | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($firstLine)) {
            if ($firstLine.Length -gt 120) {
                $firstLine = $firstLine.Substring(0, 120) + '...'
            }
            $findingParts += $firstLine
        }
    }

    $findingText = if ($findingParts.Count -gt 0) { ($findingParts -join '; ') } else { 'None' }
    $summaryLines += "| $($item.id) | $($item.l1_status) | $($item.l2_status) | $($item.overall_status) | $($item.configured_status) | $($item.contract_status) | $findingText |"
}

$summaryLines += ''
$summaryLines += '## Blockers'
$summaryLines += ''
if ($blockers.Count -eq 0) {
    $summaryLines += '- None'
} else {
    foreach ($blocker in ($blockers | Select-Object -Unique)) {
        $summaryLines += "- $blocker"
    }
}

$summaryLines += ''
$summaryLines += '## Recommended actions'
$summaryLines += ''
$uniqueRecommendations = @($recommendations | Select-Object -Unique)
if ($uniqueRecommendations.Count -eq 0) {
    $summaryLines += '- Maintain the current local baseline.'
} else {
    foreach ($recommendation in $uniqueRecommendations) {
        $summaryLines += "- $recommendation"
    }
}

Write-HarnessTextFile -Path $summaryPath -Content ($summaryLines -join [Environment]::NewLine)
Write-HarnessJsonFile -Path $matrixPath -Data $matrix

Write-Host "Generated local baseline verification reports: " -ForegroundColor Green
Write-Host "  - $summaryPath"
Write-Host "  - $matrixPath"

$matrix | Select-Object id, l1_status, l2_status, overall_status, configured_status, contract_status | Format-Table -AutoSize | Out-Host
if ($PassThru) {
    return $matrix
}
