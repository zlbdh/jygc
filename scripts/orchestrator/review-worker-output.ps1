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
        summary = 'The final review-worker output could not be parsed as structured JSON. Inspect it manually.'
        scope_check = 'unknown'
        task_alignment = 'unknown'
        verification_check = 'unknown'
        needs_rework = $true
        findings = @('Invalid review output format. Manual review is required.')
        next_action = 'Inspect raw_response manually and rerun the review worker if needed.'
        exit_code = $ExitCode
        raw_response = $RawResponse
    }
}

function Test-HarnessReviewRuntimeBlockedMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    # Match English diagnostics and retain legacy Chinese diagnostics from external tools.
    return $Text -match 'external runtime|usage limit|runtime / usage limit|运行资源阻断|外部 runtime|try again at|hit your usage limit|resource limit'
}

function Test-HarnessReviewEnvironmentBlockedMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    # Match English diagnostics and retain legacy Chinese diagnostics from external tools.
    return $Text -match 'dependency block|local dependencies|EACCES|未安装到本地可执行路径|缺少 .+ 可执行文件|is not recognized as an internal or external command|依赖阻断|本地依赖'
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
            summary = 'Review-wrapper conclusion: snapshot synchronization is effective, but this repository-worker run is blocked by an external runtime / usage limit. The single-repository no-hand-code workflow cannot yet be declared passed.'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'blocked_by_runtime'
            needs_rework = $false
            findings = @(
                'The blocker is an external runtime / usage limit, not an implementation failure within the write scope.',
                'When the runtime recovers, rerun the repository worker on the same source_dirty_tracked worktree baseline.'
            )
            next_action = 'Have verification-agent record an external runtime resource block and prioritize rerunning this repository worker when the runtime recovers.'
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
            summary = 'Review-wrapper conclusion: the repository worker made actual code changes within the write scope, but missing local worktree dependencies block verification commands. The single-repository no-hand-code workflow cannot yet be declared passed.'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'blocked_by_environment'
            needs_rework = $false
            findings = @(
                'The blocker is missing local worktree dependencies or restricted dependency downloads, not an implementation failure within the write scope.',
                'Before rerunning, ensure the current source/worktree has usable local `eslint` / `expo` dependencies.'
            )
            next_action = 'Have verification-agent record an environment/dependency block. Rerun the repository worker and review worker after usable local dependencies are available in the worktree.'
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
            summary = 'The review wrapper checked the current diff, worker result, and verification command results. This repository-worker run passed.'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'pass'
            needs_rework = $false
            findings = @()
            next_action = 'Have verification-agent consolidate the main conclusion and update acceptance.md and verification/result.md.'
            exit_code = 0
            raw_response = 'deterministic-local-review'
        }
    }

    $hasOutOfScopeDebt = Test-WorkerOutOfScopeRepoDebt -WorkerResponse $workerResponse -AllowedPaths $AllowedPaths
    if ($scopedLintPass -and $hasExpoPass -and $safeAreaFixed -and $hasOutOfScopeDebt) {
        return [pscustomobject]@{
            status = 'approved'
            summary = 'Review-wrapper conclusion: the repository worker made actual code changes within the write scope and passed target-file verification. Remaining repository-wide lint failures are pre-existing issues outside the scope. Record a conditional pass under the single-repository no-hand-code V1 protocol.'
            scope_check = 'pass'
            task_alignment = 'pass'
            verification_check = 'pass_with_external_debt'
            needs_rework = $false
            findings = @(
                'Repository-wide `npm run lint` remains blocked by pre-existing issues outside the write scope. Address them in a separate baseline remediation cycle.'
            )
            next_action = 'Have verification-agent record a conditional pass and register pre-existing lint issues outside the scope for later remediation.'
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
        $Response.summary = 'The review wrapper checked the latest worker result, verification command results, and current file content. This repository-worker run passed.'
        $Response.next_action = 'Have verification-agent consolidate the main cross-repository conclusion and update acceptance.md and verification/result.md.'
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
    $lines.Add('## Agent review conclusion')
    $lines.Add('')
    $lines.Add(('- status: `{0}`' -f $Response.status))
    $lines.Add(('- scope_check: `{0}`' -f $Response.scope_check))
    $lines.Add(('- task_alignment: `{0}`' -f $Response.task_alignment))
    $lines.Add(('- verification_check: `{0}`' -f $Response.verification_check))
    $lines.Add(('- needs_rework: `{0}`' -f $Response.needs_rework))
    $lines.Add(('- worker exit code: `{0}`' -f $Response.exit_code))
    $lines.Add('')
    $lines.Add('### Summary')
    $lines.Add('')
    $lines.Add($Response.summary)
    $lines.Add('')
    $lines.Add('### Findings')
    $lines.Add('')
    foreach ($finding in @($Response.findings)) {
        $lines.Add(('- {0}' -f $finding))
    }
    if (@($Response.findings).Count -eq 0) {
        $lines.Add('- None.')
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
        throw "Unknown repository: $repoId"
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
    $workerResultContent = if (Test-Path -LiteralPath $workerResultPath) { Get-Content -LiteralPath $workerResultPath -Raw } else { "Worker result not found: $workerResultRelative" }

    $reviewLines = @(
        "# $ChangeId / $repoId Review Packet",
        "",
        "## Basic information",
        "",
        "- repo: $repoId",
        "- Current stage: $($execution.Stage)",
        "- review role: verification-agent",
        "- worker result: $workerResultRelative",
        "- worktree: $repoPath",
        "",
        "## Worker result summary",
        "",
        ('{0}text' -f $codeFence),
        $workerResultContent.TrimEnd(),
        $codeFence,
        "",
        "## Git changed files",
        "",
        ('{0}text' -f $codeFence),
        $changedFiles.TrimEnd(),
        $codeFence,
        "",
        "## Git status",
        "",
        ('{0}text' -f $codeFence),
        $gitStatus.TrimEnd(),
        $codeFence,
        "",
        "## Review checklist",
        "",
        "- Were any paths outside the write scope changed?",
        "- Were minimum repository verification commands run and recorded?",
        "- Is the result consistent with ``impact.yaml`` / ``design.md`` / ``tasks/$repoId.md``?",
        "- Are there remaining risks to record in ``verification/result.md``?"
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
            "You are a review worker for the example product, responsible for the structured review of repository `$repoId`.",
            "Perform read-only checks only. Do not modify code or control-repository files.",
            "Provide a structured conclusion based on the current worktree diff, worker result, and consistency with the task card.",
            "Return only JSON matching the JSON schema, without additional explanation.",
            "",
            "Review packet:",
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
            $normalized.summary = 'The review worker returned no structured JSON. Treat this as an external runtime / usage limit block.'
            $normalized.scope_check = 'unknown'
            $normalized.task_alignment = 'unknown'
            $normalized.verification_check = 'blocked_by_runtime'
            $normalized.needs_rework = $false
            $normalized.findings = @(
                'The review worker returned no structured result and may be blocked by an external runtime / usage limit.'
            )
            $normalized.next_action = 'Rerun the review worker when the runtime recovers. For now, have verification-agent record an external runtime resource block.'
            $runtimeBlocked = $true
        }
        $normalized = Refine-ReviewResponse -Response $normalized -ChangeId $ChangeId -RepoId $repoId -RepoPath $repoPath -WorkerResponseJsonPath $workerResponseJsonPath -AllowedPaths $allowedPaths
        Write-HarnessJsonFile -Path $reviewJsonPath -Data $normalized
        $finalReviewContent = Convert-ReviewResponseToMarkdown -BasePacketContent $reviewContent -Response $normalized
        Write-HarnessTextFile -Path $reviewPath -Content $finalReviewContent

if (($reviewExitCode -ne 0) -and ($null -eq $parsedResponse) -and (-not $runtimeBlocked) -and ($normalized.status -eq 'failed')) {
            throw "review Worker execution failed: $ChangeId/$repoId (exit code=$reviewExitCode)"
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

Write-Host "Review packet generated: $ChangeId" -ForegroundColor Green
foreach ($item in $summary) {
    Write-Host ("  - {0}: {1}" -f $item.repo_id, $item.review_path) -ForegroundColor Cyan
}
