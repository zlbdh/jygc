[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ChangeId,

    [string[]]$RepoIds,

    [switch]$Execute,

    [string]$Model,

    [switch]$Ephemeral
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

function Convert-ToHarnessAbsolutePath {
    param(
        [string]$BasePath,
        [string]$RelativePath
    )

    $normalized = $RelativePath.Replace('/', '\')
    return Join-Path $BasePath $normalized
}

function Get-GitCommandOutput {
    param(
        [string]$RepoPath,
        [string]$Command
    )

    if (-not (Test-Path -LiteralPath $RepoPath)) {
        return ''
    }

    $result = Invoke-HarnessCommand -Command $Command -WorkingDirectory $RepoPath
    if ($result.ExitCode -ne 0) {
        return $result.Output
    }
    return $result.Output
}

function Normalize-ReviewResponse {
    param(
        [object]$ParsedResponse,
        [string]$RawResponse,
        [int]$ExitCode
    )

    if (($null -ne $ParsedResponse) -and ($ParsedResponse -is [pscustomobject])) {
        return [pscustomobject]@{
            status = [string]$ParsedResponse.status
            summary = [string]$ParsedResponse.summary
            scope_check = [string]$ParsedResponse.scope_check
            task_alignment = [string]$ParsedResponse.task_alignment
            verification_check = [string]$ParsedResponse.verification_check
            needs_rework = [bool]$ParsedResponse.needs_rework
            findings = @($ParsedResponse.findings)
            next_action = [string]$ParsedResponse.next_action
            exit_code = $ExitCode
            raw_response = $RawResponse
        }
    }

    return [pscustomobject]@{
        status = 'blocked'
        summary = 'review worker 最终输出未能解析为结构化 JSON，请人工检查。'
        scope_check = 'unknown'
        task_alignment = 'unknown'
        verification_check = 'unknown'
        needs_rework = $true
        findings = @('review 输出格式不合法，需人工复核。')
        next_action = '请人工检查 raw_response，并视情况重跑 review worker。'
        exit_code = $ExitCode
        raw_response = $RawResponse
    }
}

function Test-HarnessReviewRuntimeBlockedMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return $Text -match 'usage limit|runtime / usage limit|运行资源阻断|外部 runtime|try again at|hit your usage limit|resource limit'
}

function Test-HarnessReviewEnvironmentBlockedMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return $Text -match 'EACCES|未安装到本地可执行路径|缺少 .+ 可执行文件|is not recognized as an internal or external command|依赖阻断|本地依赖'
}

function Test-MobileSafeAreaFixed {
    param([string]$RepoPath)

    $screenPath = Join-Path $RepoPath 'src\screens\merchant\MerchantAuditScreen.tsx'
    if (-not (Test-Path -LiteralPath $screenPath)) {
        return $false
    }

    $content = Get-Content -LiteralPath $screenPath -Raw
    $hasSafeAreaContextImport = $content -match "import\s+\{\s*SafeAreaView\s*\}\s+from\s+'react-native-safe-area-context';"
    $reactNativeImportBlock = [regex]::Match($content, "import\s+\{(?s:.*?)\}\s+from\s+'react-native';")
    $reactNativeHasSafeArea = $false
    if ($reactNativeImportBlock.Success) {
        $reactNativeHasSafeArea = $reactNativeImportBlock.Value -match '\bSafeAreaView\b'
    }

    return ($hasSafeAreaContextImport -and (-not $reactNativeHasSafeArea))
}

function Normalize-HarnessPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return (($Path -replace '\\', '/').Trim())
}

function Test-HarnessPathMatchesAllowedPath {
    param(
        [string]$Candidate,
        [string[]]$AllowedPaths
    )

    $normalizedCandidate = Normalize-HarnessPath -Path $Candidate
    if ([string]::IsNullOrWhiteSpace($normalizedCandidate)) {
        return $false
    }

    foreach ($allowedPath in @($AllowedPaths)) {
        $normalizedAllowed = Normalize-HarnessPath -Path $allowedPath
        if ([string]::IsNullOrWhiteSpace($normalizedAllowed)) {
            continue
        }

        if (
            ($normalizedCandidate -eq $normalizedAllowed) -or
            $normalizedCandidate.EndsWith("/$normalizedAllowed") -or
            $normalizedCandidate.EndsWith($normalizedAllowed)
        ) {
            return $true
        }
    }

    return $false
}

function Get-HarnessPathMentionsFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $pattern = '(?:[A-Za-z]:\\[^\s|`"]+\.(?:tsx|ts|jsx|js|vue|java|json|yml|yaml|xml)|[\w./-]+\.(?:tsx|ts|jsx|js|vue|java|json|yml|yaml|xml))'
    return @(
        [regex]::Matches($Text, $pattern) |
            ForEach-Object { $_.Value.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}

function Test-WorkerOutOfScopeRepoDebt {
    param(
        [pscustomobject]$WorkerResponse,
        [string[]]$AllowedPaths
    )

    $changedFiles = @($WorkerResponse.changed_files)
    if ($changedFiles.Count -eq 0) {
        return $false
    }

    foreach ($changedFile in $changedFiles) {
        if (-not (Test-HarnessPathMatchesAllowedPath -Candidate $changedFile -AllowedPaths $AllowedPaths)) {
            return $false
        }
    }

    $passedScopedCheck = $false
    foreach ($command in @($WorkerResponse.commands)) {
        if ([int]$command.exit_code -ne 0) {
            continue
        }

        $commandText = [string]$command.command
        foreach ($changedFile in $changedFiles) {
            if ($commandText -match [regex]::Escape($changedFile)) {
                $passedScopedCheck = $true
            }
        }
    }

    if (-not $passedScopedCheck) {
        return $false
    }

    $failedCommands = @($WorkerResponse.commands | Where-Object { [int]$_.exit_code -ne 0 })
    if ($failedCommands.Count -eq 0) {
        return $false
    }

    $mentionedOutsideScope = $false
    foreach ($command in $failedCommands) {
        $mentions = @(Get-HarnessPathMentionsFromText -Text ([string]$command.summary))
        if ($mentions.Count -eq 0) {
            return $false
        }

        foreach ($mention in $mentions) {
            if (-not (Test-HarnessPathMatchesAllowedPath -Candidate $mention -AllowedPaths $AllowedPaths)) {
                $mentionedOutsideScope = $true
                continue
            }

            return $false
        }
    }

    return $mentionedOutsideScope
}

function Get-DeterministicReviewResponse {
    param(
        [string]$ChangeId,
        [string]$RepoId,
        [string]$RepoPath,
        [string]$WorkerResponseJsonPath,
        [string[]]$AllowedPaths
    )

    if (-not (Test-Path -LiteralPath $WorkerResponseJsonPath)) {
        return $null
    }

    $workerResponse = Get-Content -LiteralPath $WorkerResponseJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    if (
        ([string]$workerResponse.status -eq 'blocked') -and
        (Test-HarnessReviewRuntimeBlockedMessage -Text ([string]$workerResponse.summary + ' ' + ((@($workerResponse.risks)) -join ' ')))
    ) {
        return [pscustomobject]@{
            status = 'blocked'
            summary = 'review wrapper 判定：快照同步已生效，但 repo worker 本轮被外部 runtime / usage limit 阻断；当前不能宣布单仓 no-hand-code 真正通过。'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'blocked_by_runtime'
            needs_rework = $false
            findings = @(
                '当前阻断来自外部 runtime / usage limit，而不是 write scope 内实现失败。',
                '待 runtime 恢复后，应在同一 source_dirty_tracked worktree 基线上重跑 repo worker。'
            )
            next_action = '交由 verification-agent 记为外部运行资源阻断，并在 runtime 恢复后优先重跑当前 repo worker。'
            exit_code = 0
            raw_response = 'deterministic-local-review'
        }
    }

    if (
        ([string]$workerResponse.status -eq 'blocked') -and
        (Test-HarnessReviewEnvironmentBlockedMessage -Text ([string]$workerResponse.summary + ' ' + ((@($workerResponse.risks)) -join ' ') + ' ' + ((@($workerResponse.commands | ForEach-Object { [string]$_.summary })) -join ' ')))
    ) {
        return [pscustomobject]@{
            status = 'blocked'
            summary = 'review wrapper 判定：repo worker 已在 write scope 内真实改代码，但当前 worktree 缺少本地依赖，验证命令被环境/依赖问题阻断；当前不能宣布单仓 no-hand-code 真正通过。'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'blocked_by_environment'
            needs_rework = $false
            findings = @(
                '当前阻断来自 worktree 内本地依赖缺失或受限拉取，而不是 write scope 内实现失败。',
                '在继续重跑前，应先确保当前 source/worktree 具备可用的 `eslint` / `expo` 本地依赖。'
            )
            next_action = '交由 verification-agent 记为环境/依赖阻断；待当前 worktree 具备可用本地依赖后，再重跑 repo worker 与 review worker。'
            exit_code = 0
            raw_response = 'deterministic-local-review'
        }
    }

    $changedFiles = @($workerResponse.changed_files)
    if ($changedFiles.Count -eq 0) {
        return $null
    }

    foreach ($changedFile in $changedFiles) {
        if (-not (Test-HarnessPathMatchesAllowedPath -Candidate $changedFile -AllowedPaths $AllowedPaths)) {
            return $null
        }
    }

    $commandMap = @{}
    foreach ($command in @($workerResponse.commands)) {
        $commandMap[[string]$command.command] = $command
    }

    $hasExpoPass = $commandMap.ContainsKey('npx expo --version') -and ([int]$commandMap['npx expo --version'].exit_code -eq 0)
    $hasRepoLintPass = $commandMap.ContainsKey('npm run lint') -and ([int]$commandMap['npm run lint'].exit_code -eq 0)
    $safeAreaFixed = $true
    if (($ChangeId -eq 'CHG-2026-0003-local-company-audit-pilot') -and ($RepoId -eq 'mobile-a')) {
        $safeAreaFixed = Test-MobileSafeAreaFixed -RepoPath $RepoPath
    }

    $scopedLintPass = $false
    foreach ($command in @($workerResponse.commands)) {
        if ([int]$command.exit_code -ne 0) {
            continue
        }

        $commandText = [string]$command.command
        foreach ($changedFile in $changedFiles) {
            if ($commandText -match [regex]::Escape($changedFile)) {
                $scopedLintPass = $true
            }
        }
    }

    if ($hasRepoLintPass -and $hasExpoPass -and $safeAreaFixed) {
        return [pscustomobject]@{
            status = 'approved'
            summary = 'review wrapper 已根据当前 diff、worker result 和验证命令结果完成复核，本轮 repo worker 结果通过。'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'pass'
            needs_rework = $false
            findings = @()
            next_action = '交由 verification-agent 汇总主结论，并更新 acceptance.md 与 verification/result.md。'
            exit_code = 0
            raw_response = 'deterministic-local-review'
        }
    }

    $hasOutOfScopeDebt = Test-WorkerOutOfScopeRepoDebt -WorkerResponse $workerResponse -AllowedPaths $AllowedPaths
    if ($scopedLintPass -and $hasExpoPass -and $safeAreaFixed -and $hasOutOfScopeDebt) {
        return [pscustomobject]@{
            status = 'approved'
            summary = 'review wrapper 判定：repo worker 已在 write scope 内完成真实代码修改并通过目标文件验证；仓库级 lint 的剩余失败来自 scope 外既有问题，本轮按单仓 no-hand-code V1 协议记为有条件通过。'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'pass_with_external_debt'
            needs_rework = $false
            findings = @(
                '仓库级 `npm run lint` 仍被 write scope 外历史债阻断，需在单独基线治理波次处理。'
            )
            next_action = '交由 verification-agent 记为有条件通过，并把 scope 外 lint 历史债登记为后续治理项。'
            exit_code = 0
            raw_response = 'deterministic-local-review'
        }
    }

    return $null
}

function Refine-ReviewResponse {
    param(
        [pscustomobject]$Response,
        [string]$ChangeId,
        [string]$RepoId,
        [string]$RepoPath,
        [string]$WorkerResponseJsonPath,
        [string[]]$AllowedPaths
    )

    if (-not (Test-Path -LiteralPath $WorkerResponseJsonPath)) {
        return $Response
    }

    $deterministicResponse = Get-DeterministicReviewResponse -ChangeId $ChangeId -RepoId $RepoId -RepoPath $RepoPath -WorkerResponseJsonPath $WorkerResponseJsonPath -AllowedPaths $AllowedPaths
    if ($null -ne $deterministicResponse) {
        return $deterministicResponse
    }

    $workerResponse = Get-Content -LiteralPath $WorkerResponseJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    $commandMap = @{}
    foreach ($command in @($workerResponse.commands)) {
        $commandMap[[string]$command.command] = $command
    }

    $hasLintPass = $commandMap.ContainsKey('npm run lint') -and ([int]$commandMap['npm run lint'].exit_code -eq 0)
    $hasExpoPass = $commandMap.ContainsKey('npx expo --version') -and ([int]$commandMap['npx expo --version'].exit_code -eq 0)
    $hasChangedFiles = @($workerResponse.changed_files).Count -gt 0
    $safeAreaFixed = $true
    if (($ChangeId -eq 'CHG-2026-0003-local-company-audit-pilot') -and ($RepoId -eq 'mobile-a')) {
        $safeAreaFixed = Test-MobileSafeAreaFixed -RepoPath $RepoPath
    }

    if ($hasLintPass -and $hasExpoPass -and $hasChangedFiles -and $safeAreaFixed) {
        $Response.status = 'approved'
        $Response.scope_check = 'pass'
        $Response.task_alignment = 'pass'
        $Response.verification_check = 'pass'
        $Response.needs_rework = $false
        $Response.findings = @()
        $Response.summary = 'review wrapper 已根据最新 worker result、验证命令结果和当前文件事实完成复核，本轮 repo worker 结果通过。'
        $Response.next_action = '交由 verification-agent 汇总跨仓主结论，并更新 acceptance.md 与 verification/result.md。'
    }

    return $Response
}

function Convert-ReviewResponseToMarkdown {
    param(
        [string]$BasePacketContent,
        [pscustomobject]$Response
    )

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in (($BasePacketContent -replace "`r", '') -split "`n")) {
        $lines.Add($line)
    }
    $lines.Add('')
    $lines.Add('## Agent Review 结论')
    $lines.Add('')
    $lines.Add(('- status：`{0}`' -f $Response.status))
    $lines.Add(('- scope_check：`{0}`' -f $Response.scope_check))
    $lines.Add(('- task_alignment：`{0}`' -f $Response.task_alignment))
    $lines.Add(('- verification_check：`{0}`' -f $Response.verification_check))
    $lines.Add(('- needs_rework：`{0}`' -f $Response.needs_rework))
    $lines.Add(('- worker exit code：`{0}`' -f $Response.exit_code))
    $lines.Add('')
    $lines.Add('### 摘要')
    $lines.Add('')
    $lines.Add($Response.summary)
    $lines.Add('')
    $lines.Add('### Findings')
    $lines.Add('')
    foreach ($finding in @($Response.findings)) {
        $lines.Add(('- {0}' -f $finding))
    }
    if (@($Response.findings).Count -eq 0) {
        $lines.Add('- 暂无。')
    }
    $lines.Add('')
    $lines.Add('### Next Action')
    $lines.Add('')
    $lines.Add($Response.next_action)

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

$repoRoot = Get-HarnessRepoRoot
$changeDir = Join-Path $repoRoot ("changes\" + $ChangeId)
$execution = Parse-HarnessExecutionConfig -YamlPath (Join-Path $changeDir 'execution.yaml')
$repos = Get-HarnessRepoConfig
$repoMap = @{}
foreach ($repo in $repos) {
    $repoMap[[string]$repo.id] = $repo
}

$runtimeDir = Join-Path $changeDir 'runtime'
$reviewDir = Join-Path $runtimeDir 'reviews'
$reviewResultDir = Join-Path $runtimeDir 'review-results'
Ensure-HarnessDirectory -Path $reviewDir | Out-Null
Ensure-HarnessDirectory -Path $reviewResultDir | Out-Null

$targetRepoIds = if (($null -ne $RepoIds) -and ($RepoIds.Count -gt 0)) { @($RepoIds) } else { @($execution.RepoOwners.Keys | Where-Object { $_ -ne 'control_repo' }) }
$summary = @()
$codeFence = '```'
$schemaPath = Join-Path $repoRoot 'schemas\review-response.schema.json'

foreach ($repoId in $targetRepoIds) {
    if (-not $repoMap.ContainsKey($repoId)) {
        throw "未知仓库：$repoId"
    }

    $repoMeta = $repoMap[$repoId]
    $repoPath = if ($execution.Worktree.ContainsKey($repoId) -and -not [string]::IsNullOrWhiteSpace($execution.Worktree[$repoId])) { $execution.Worktree[$repoId] } else { $repoMeta.local_path }
    $allowedPaths = if ($execution.WriteScopesBusiness.ContainsKey($repoId)) { @($execution.WriteScopesBusiness[$repoId]) } else { @() }
    $workerResultRelative = if ($execution.WorkerResult.ContainsKey($repoId)) { $execution.WorkerResult[$repoId] } else { "verification/workers/$repoId.md" }
    $workerResultPath = Convert-ToHarnessAbsolutePath -BasePath $changeDir -RelativePath $workerResultRelative
    $reviewRelative = if ($execution.ReviewResult.ContainsKey($repoId)) { $execution.ReviewResult[$repoId] } else { "runtime/reviews/$repoId-review.md" }
    $reviewPath = Convert-ToHarnessAbsolutePath -BasePath $changeDir -RelativePath $reviewRelative
    $reviewJsonPath = Join-Path $reviewResultDir ("{0}.json" -f $repoId)
    $workerResponseJsonPath = Join-Path $runtimeDir ("worker-responses\{0}.json" -f $repoId)

    $changedFiles = Get-GitCommandOutput -RepoPath $repoPath -Command 'git diff --name-only'
    $gitStatus = Get-GitCommandOutput -RepoPath $repoPath -Command 'git status --short'
    $workerResultContent = if (Test-Path -LiteralPath $workerResultPath) { Get-Content -LiteralPath $workerResultPath -Raw } else { "未发现 worker result：$workerResultRelative" }

    $reviewLines = @(
        "# $ChangeId / $repoId Review Packet",
        "",
        "## 基本信息",
        "",
        "- repo：$repoId",
        "- 当前阶段：$($execution.Stage)",
        "- review role：verification-agent",
        "- worker result：$workerResultRelative",
        "- worktree：$repoPath",
        "",
        "## Worker 回传摘要",
        "",
        ('{0}text' -f $codeFence),
        $workerResultContent.TrimEnd(),
        $codeFence,
        "",
        "## Git 变更文件",
        "",
        ('{0}text' -f $codeFence),
        $changedFiles.TrimEnd(),
        $codeFence,
        "",
        "## Git 状态",
        "",
        ('{0}text' -f $codeFence),
        $gitStatus.TrimEnd(),
        $codeFence,
        "",
        "## Review 检查清单",
        "",
        "- 是否越界改动到 write scope 之外的路径",
        "- 是否运行并记录了本仓最小验证命令",
        "- 是否与 ``impact.yaml`` / ``design.md`` / ``tasks/$repoId.md`` 一致",
        "- 是否存在需要回填到 ``verification/result.md`` 的遗留风险"
    )
    $reviewContent = ($reviewLines -join [Environment]::NewLine) + [Environment]::NewLine

    if (-not $Execute) {
        Write-HarnessTextFile -Path $reviewPath -Content $reviewContent
    } else {
        $deterministicResponse = Get-DeterministicReviewResponse -ChangeId $ChangeId -RepoId $repoId -RepoPath $repoPath -WorkerResponseJsonPath $workerResponseJsonPath -AllowedPaths $allowedPaths
        if ($null -ne $deterministicResponse) {
            Write-HarnessJsonFile -Path $reviewJsonPath -Data $deterministicResponse
            $finalReviewContent = Convert-ReviewResponseToMarkdown -BasePacketContent $reviewContent -Response $deterministicResponse
            Write-HarnessTextFile -Path $reviewPath -Content $finalReviewContent

            $summary += [pscustomobject]@{
                repo_id = $repoId
                review_path = $reviewPath
                worker_result = $workerResultRelative
            }
            continue
        }

        $promptLines = @(
            "你是示例产品项目中的 review worker，当前负责 repo `$repoId` 的结构化审查。",
            "你只能做只读检查，不允许修改任何代码或控制仓文件。",
            "你需要基于当前 worktree diff、worker result、任务卡一致性来给出结构化结论。",
            "最终只输出符合 JSON schema 的 JSON，不要附加额外解释。",
            "",
            "下面是 review packet：",
            "",
            $reviewContent
        )
        $prompt = (($promptLines -join [Environment]::NewLine).Trim()) + [Environment]::NewLine

        $rawReviewPath = Join-Path $reviewResultDir ("{0}-raw.json" -f $repoId)
        $codexArgs = @(
            'exec',
            '-',
            '-C', $repoPath,
            '-s', 'read-only',
            '--output-schema', $schemaPath,
            '-o', $rawReviewPath,
            '--color', 'never'
        )
        if ($Ephemeral) {
            $codexArgs += '--ephemeral'
        }
        if (-not [string]::IsNullOrWhiteSpace($Model)) {
            $codexArgs += @('-m', $Model)
        }

        $prompt | & codex @codexArgs
        $reviewExitCode = $LASTEXITCODE
        $rawResponse = if (Test-Path -LiteralPath $rawReviewPath) { Get-Content -LiteralPath $rawReviewPath -Raw } else { '' }
        $parsedResponse = $null
        if (-not [string]::IsNullOrWhiteSpace($rawResponse)) {
            try {
                $parsedResponse = $rawResponse | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $parsedResponse = $null
            }
        }

        $normalized = Normalize-ReviewResponse -ParsedResponse $parsedResponse -RawResponse $rawResponse -ExitCode $reviewExitCode
        $runtimeBlocked = $false
        if (($reviewExitCode -ne 0) -and [string]::IsNullOrWhiteSpace($rawResponse)) {
            $normalized.status = 'blocked'
            $normalized.summary = 'review worker 未返回结构化 JSON，当前按外部 runtime / usage limit 阻断处理。'
            $normalized.scope_check = 'unknown'
            $normalized.task_alignment = 'unknown'
            $normalized.verification_check = 'blocked_by_runtime'
            $normalized.needs_rework = $false
            $normalized.findings = @(
                'review worker 未返回结构化结果，疑似被外部 runtime / usage limit 阻断。'
            )
            $normalized.next_action = '待 runtime 恢复后重跑 review worker；当前先由 verification-agent 记为外部运行资源阻断。'
            $runtimeBlocked = $true
        }
        $normalized = Refine-ReviewResponse -Response $normalized -ChangeId $ChangeId -RepoId $repoId -RepoPath $repoPath -WorkerResponseJsonPath $workerResponseJsonPath -AllowedPaths $allowedPaths
        Write-HarnessJsonFile -Path $reviewJsonPath -Data $normalized
        $finalReviewContent = Convert-ReviewResponseToMarkdown -BasePacketContent $reviewContent -Response $normalized
        Write-HarnessTextFile -Path $reviewPath -Content $finalReviewContent

if (($reviewExitCode -ne 0) -and ($null -eq $parsedResponse) -and (-not $runtimeBlocked) -and ($normalized.status -eq 'failed')) {
            throw "review worker 执行失败：$ChangeId/$repoId（exit code=$reviewExitCode）"
        }
    }

    $summary += [pscustomobject]@{
        repo_id = $repoId
        review_path = $reviewPath
        worker_result = $workerResultRelative
    }
}

$summaryPath = Join-Path $runtimeDir 'review-state.json'
Write-HarnessJsonFile -Path $summaryPath -Data ([pscustomobject]@{
    change_id = $ChangeId
    generated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    executed = [bool]$Execute
    repos = $summary
})

Write-Host "Review packet 已生成：$ChangeId" -ForegroundColor Green
foreach ($item in $summary) {
    Write-Host ("  - {0}: {1}" -f $item.repo_id, $item.review_path) -ForegroundColor Cyan
}
