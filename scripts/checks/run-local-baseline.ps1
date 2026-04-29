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

    return $Text -match 'LocalRepositoryNotAccessibleException|Could not create local repository|spawn EPERM|blocked by policy|sandbox|权限限制|受环境限制|当前环境.*阻止|无法执行'
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
        $findings.Add('本地仓库未克隆。')
        $blockers.Add("$($repo.id)：未克隆到本地。")
        $recommendations.Add("$($repo.id)：先执行 scripts/bootstrap/clone-repos.ps1 拉齐仓库。")
    } elseif (-not $gitExists) {
        $l1Status = 'FAIL'
        $l2Status = 'SKIP'
        $findings.Add('目录存在但不是 git 仓库。')
        $blockers.Add("$($repo.id)：目录存在但不是 git 仓库。")
        $recommendations.Add("$($repo.id)：清理异常目录后重新克隆标准仓库。")
    } else {
        $remoteUrl = Get-HarnessGitOriginUrl -RepoPath $repoPath
        $remoteOk = (Normalize-HarnessText $remoteUrl) -eq (Normalize-HarnessText $repo.remote)
        $branchOk = Test-DefaultBranchPresence -RepoPath $repoPath -BranchName ([string]$repo.default_branch)
        $dirtyResult = Invoke-HarnessCommand -WorkingDirectory $repoPath -Command 'git status --porcelain'
        $dirty = -not [string]::IsNullOrWhiteSpace((Normalize-HarnessText $dirtyResult.Output))
        $manifestOk = Get-ProfileManifestsPresent -Repo $repo -RepoPath $repoPath

        if (-not $remoteOk) {
            $l1Status = 'WARN'
            $findings.Add('origin 远端与 repos.yaml 不一致。')
            $recommendations.Add("$($repo.id)：修正 origin 远端地址。")
        }

        if (-not $branchOk) {
            $l1Status = 'WARN'
            $findings.Add("默认分支 $($repo.default_branch) 未在本地或 origin 中发现。")
            $recommendations.Add("$($repo.id)：校正 repos.yaml 中的 default_branch 或同步远端默认分支。")
        }

        if (-not $manifestOk) {
            $l1Status = 'FAIL'
            $findings.Add('缺少关键 manifest，无法进入安全自检。')
            $blockers.Add("$($repo.id)：关键 manifest 缺失。")
            $recommendations.Add("$($repo.id)：先补齐工程入口和关键 manifest，再进入 L2 安全自检。")
        }

        if ($dirty) {
            if ($l1Status -eq 'PASS') {
                $l1Status = 'WARN'
            }
            $findings.Add('工作区非干净状态。')
            $recommendations.Add("$($repo.id)：清理工作区改动后再重跑本地基线。")
        }
    }

    if ($l1Status -ne 'FAIL') {
        switch ([string]$repo.validation_profile) {
            'backend-maven' {
                if (-not $toolAvailability.mvn) {
                    $envOk = $false
                    $findings.Add('本机缺少 mvn。')
                }
            }
            'web-vite' {
                foreach ($tool in @('node', 'npm', 'npx')) {
                    if (-not $toolAvailability[$tool]) {
                        $envOk = $false
                        $findings.Add("本机缺少 $tool。")
                    }
                }
            }
            'mobile-rn' {
                foreach ($tool in @('node', 'npm', 'npx')) {
                    if (-not $toolAvailability[$tool]) {
                        $envOk = $false
                        $findings.Add("本机缺少 $tool。")
                    }
                }
            }
            'miniapp' {
                foreach ($tool in @('node', 'npm')) {
                    if (-not $toolAvailability[$tool]) {
                        $envOk = $false
                        $findings.Add("本机缺少 $tool。")
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
            $recommendations.Add("$($repo.id)：补齐本地运行环境后再执行基线命令。")
        }
    }

    if ($l1Status -eq 'FAIL') {
        $l2Status = 'SKIP'
    } else {
        if (($repo.status -in @('missing-contract', 'missing-local-env')) -or ($contract.suggested_status -in @('missing-contract', 'missing-local-env'))) {
            if ($l2Status -eq 'PASS') {
                $l2Status = 'WARN'
            }
            $findings.Add("当前仓配置状态为 $($repo.status)，以发现和清单为主，暂不作为可发布前置验证依据。")
            if ($contract.suggested_status -eq 'missing-local-env') {
                $recommendations.Add("$($repo.id)：先补齐本地依赖环境，再纳入发布前置验证。")
            } else {
                $recommendations.Add("$($repo.id)：先补齐命令契约和工程脚手架，再纳入发布前置验证。")
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
                        $findings.Add("环境受限，无法执行 bootstrap_command：$bootstrapCommand")
                        $recommendations.Add("$($repo.id)：在允许访问本地依赖与子进程的环境中重跑 bootstrap_command。")
                    } else {
                        $l2Status = 'FAIL'
                        $findings.Add("bootstrap_command 执行失败：$bootstrapCommand")
                        $recommendations.Add("$($repo.id)：修复 bootstrap_command 后再重跑 L2。")
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
                            $findings.Add("环境受限，无法完成安全检查：$command")
                            $recommendations.Add("$($repo.id)：在允许访问本地依赖与子进程的环境中重跑安全检查。")
                        } else {
                            $l2Status = 'FAIL'
                            $findings.Add("安全检查失败：$command")
                            $recommendations.Add("$($repo.id)：修复失败的安全检查命令后再恢复为发布前置绿灯。")
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
                $findings.Add('本次跳过了实际命令执行，仅完成结构检查。')
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
    '# 本地基线验证报告',
    '',
    "生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    '',
    '## 工具可用性',
    ''
)

foreach ($tool in $toolAvailability.Keys) {
    $summaryLines += "- ${tool}: $($toolAvailability[$tool])"
}

$summaryLines += ''
$summaryLines += '## 仓库矩阵'
$summaryLines += ''
$summaryLines += '| 仓库 | L1 | L2 | 总体 | 配置状态 | 契约发现 | 关键发现 |'
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

    $findingText = if ($findingParts.Count -gt 0) { ($findingParts -join '；') } else { '无' }
    $summaryLines += "| $($item.id) | $($item.l1_status) | $($item.l2_status) | $($item.overall_status) | $($item.configured_status) | $($item.contract_status) | $findingText |"
}

$summaryLines += ''
$summaryLines += '## 阻断项'
$summaryLines += ''
if ($blockers.Count -eq 0) {
    $summaryLines += '- 无'
} else {
    foreach ($blocker in ($blockers | Select-Object -Unique)) {
        $summaryLines += "- $blocker"
    }
}

$summaryLines += ''
$summaryLines += '## 建议动作'
$summaryLines += ''
$uniqueRecommendations = @($recommendations | Select-Object -Unique)
if ($uniqueRecommendations.Count -eq 0) {
    $summaryLines += '- 继续保持当前本地基线。'
} else {
    foreach ($recommendation in $uniqueRecommendations) {
        $summaryLines += "- $recommendation"
    }
}

Write-HarnessTextFile -Path $summaryPath -Content ($summaryLines -join [Environment]::NewLine)
Write-HarnessJsonFile -Path $matrixPath -Data $matrix

Write-Host "已输出本地基线验证报告：" -ForegroundColor Green
Write-Host "  - $summaryPath"
Write-Host "  - $matrixPath"

$matrix | Select-Object id, l1_status, l2_status, overall_status, configured_status, contract_status | Format-Table -AutoSize | Out-Host
if ($PassThru) {
    return $matrix
}
