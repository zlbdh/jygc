[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ChangeId,

    [Parameter(Mandatory = $true)]
    [string]$RepoId,

    [switch]$EnsureWorktrees,

    [switch]$PrintPacket,

    [switch]$Execute,

    [switch]$SkipDispatch,

    [string]$Model,

    [switch]$Ephemeral,

    [switch]$NoCodeChanges
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

function Normalize-WorkerResponse {
    param(
        [object]$ParsedResponse,
        [string]$RawResponse,
        [int]$ExitCode
    )

    if (($null -ne $ParsedResponse) -and ($ParsedResponse -is [pscustomobject])) {
        return [pscustomobject]@{
            status = [string]$ParsedResponse.status
            summary = [string]$ParsedResponse.summary
            changed_files = @($ParsedResponse.changed_files)
            commands = @($ParsedResponse.commands)
            risks = @($ParsedResponse.risks)
            handoff_note = [string]$ParsedResponse.handoff_note
            exit_code = $ExitCode
            raw_response = $RawResponse
        }
    }

    return [pscustomobject]@{
        status = if ($ExitCode -eq 0) { 'failed' } else { 'failed' }
        summary = 'worker 最终输出未能解析为结构化 JSON，请查看 raw_response。'
        changed_files = @()
        commands = @()
        risks = @('worker 输出格式不合法，需人工检查运行日志。')
        handoff_note = '请人工检查 raw_response 并决定是否重跑 worker。'
        exit_code = $ExitCode
        raw_response = $RawResponse
    }
}

function Test-HarnessBlockedMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return $Text -match 'blocked by policy|rejected: blocked by policy|受环境限制|环境策略|当前环境.*阻止|无法执行|沙箱策略|sandbox|权限限制|EACCES|未安装到本地可执行路径|缺少 .+ 可执行文件|is not recognized as an internal or external command'
}

function Test-HarnessUsageLimitMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return $Text -match 'usage limit|more access now|try again at|request to your admin'
}

function Invoke-WrapperVerifyCommands {
    param(
        [string]$WorkingDirectory,
        [string[]]$Commands,
        [pscustomobject]$CurrentResponse
    )

    $verifyCommands = @($Commands | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($verifyCommands).Count -eq 0) {
        return $CurrentResponse
    }

    $existingCommandMap = @{}
    foreach ($command in @($CurrentResponse.commands)) {
        $existingCommandMap[[string]$command.command] = $command
    }

    $updatedCommands = New-Object System.Collections.Generic.List[object]
    foreach ($command in @($CurrentResponse.commands)) {
        $updatedCommands.Add($command)
    }

    $wrapperRanAny = $false
    $wrapperHasFailure = $false
    foreach ($expected in $verifyCommands) {
        $shouldRun = $false
        if (-not $existingCommandMap.ContainsKey($expected)) {
            $shouldRun = $true
        } else {
            $existing = $existingCommandMap[$expected]
            $summary = [string]$existing.summary
            $exitCode = [int]$existing.exit_code
            if (($exitCode -ne 0) -or (Test-HarnessBlockedMessage -Text $summary)) {
                $shouldRun = $true
            }
        }

        if (-not $shouldRun) {
            continue
        }

        $wrapperRanAny = $true
        $result = Invoke-HarnessCommand -Command $expected -WorkingDirectory $WorkingDirectory
        $trimmedOutput = ($result.Output | Out-String).Trim()
        $summary = if ([string]::IsNullOrWhiteSpace($trimmedOutput)) {
            if ($result.ExitCode -eq 0) { 'wrapper 已执行，本仓验证命令通过。' } else { 'wrapper 已执行，但命令失败且未产生输出。' }
        } else {
            $normalized = $trimmedOutput -replace "`r", ' ' -replace "`n", ' '
            if ($normalized.Length -gt 300) {
                $normalized = $normalized.Substring(0, 300) + '...'
            }
            if ($result.ExitCode -eq 0) {
                "wrapper 已执行并通过：$normalized"
            } else {
                "wrapper 已执行但失败：$normalized"
            }
        }

        $wrapperEntry = [pscustomobject]@{
            command = $expected
            exit_code = $result.ExitCode
            summary = $summary
        }

        if ($existingCommandMap.ContainsKey($expected)) {
            for ($i = 0; $i -lt $updatedCommands.Count; $i++) {
                if ([string]$updatedCommands[$i].command -eq $expected) {
                    $updatedCommands[$i] = $wrapperEntry
                }
            }
        } else {
            $updatedCommands.Add($wrapperEntry)
        }

        if ($result.ExitCode -ne 0) {
            $wrapperHasFailure = $true
        }
    }

    if (-not $wrapperRanAny) {
        return $CurrentResponse
    }

    $CurrentResponse.commands = [object[]]$updatedCommands.ToArray()
    $existingRisks = @($CurrentResponse.risks)
    $existingRisks = @($existingRisks | Where-Object {
        ($_ -ne '本仓验证命令受环境/策略限制，当前应判定为 blocked。') -and
        ($_ -notmatch '当前环境禁止执行 Node/npm/npx 命令')
    })
    if ($wrapperHasFailure) {
        if ('wrapper 已重跑本仓验证命令，但仍存在失败项。' -notin $existingRisks) {
            $existingRisks += 'wrapper 已重跑本仓验证命令，但仍存在失败项。'
        }
        if ($CurrentResponse.status -eq 'blocked') {
            $CurrentResponse.status = 'failed'
        }
    } else {
        if ($CurrentResponse.status -eq 'blocked') {
            $CurrentResponse.status = 'completed'
        }
        if (-not [string]::IsNullOrWhiteSpace($CurrentResponse.summary)) {
            $CurrentResponse.summary = "wrapper 已补跑本仓最小验证命令并通过。原摘要：$($CurrentResponse.summary)"
        } else {
            $CurrentResponse.summary = 'wrapper 已补跑本仓最小验证命令并通过。'
        }
    }
    $CurrentResponse.risks = $existingRisks
    return $CurrentResponse
}

function Get-ScopedChangedFiles {
    param(
        [string]$WorkingDirectory,
        [string[]]$AllowedPaths
    )

    $pathList = @($AllowedPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($pathList).Count -eq 0) {
        return @()
    }

    $quotedPaths = $pathList | ForEach-Object { '"' + ($_ -replace '/', '\') + '"' }
    $command = ('git diff --name-only -- {0}' -f ($quotedPaths -join ' '))
    $result = Invoke-HarnessCommand -Command $command -WorkingDirectory $WorkingDirectory
    if ($result.ExitCode -ne 0) {
        return @()
    }

    return @(
        ($result.Output -replace "`r", '') -split "`n" |
            Where-Object {
                (-not [string]::IsNullOrWhiteSpace($_)) -and
                ($_.Trim() -notmatch '^warning:')
            } |
            ForEach-Object { $_.Trim() }
    )
}

function Normalize-HarnessScopePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return (($Path -replace '\\', '/').Trim())
}

function Test-HarnessPathMatchesAllowed {
    param(
        [string]$Candidate,
        [string[]]$AllowedPaths
    )

    $normalizedCandidate = Normalize-HarnessScopePath -Path $Candidate
    if ([string]::IsNullOrWhiteSpace($normalizedCandidate)) {
        return $false
    }

    foreach ($allowedPath in @($AllowedPaths)) {
        $normalizedAllowed = Normalize-HarnessScopePath -Path $allowedPath
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

function Get-HarnessPathMentionsFromSummary {
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

function Test-OutOfScopeRepoValidationDebt {
    param(
        [pscustomobject]$Response,
        [string[]]$AllowedPaths,
        [string[]]$ChangedFiles
    )

    $normalizedChangedFiles = @($ChangedFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($normalizedChangedFiles).Count -eq 0) {
        return $false
    }

    foreach ($changedFile in $normalizedChangedFiles) {
        if (-not (Test-HarnessPathMatchesAllowed -Candidate $changedFile -AllowedPaths $AllowedPaths)) {
            return $false
        }
    }

    $failedCommands = @($Response.commands | Where-Object { [int]$_.exit_code -ne 0 })
    if (@($failedCommands).Count -eq 0) {
        return $false
    }

    $mentionedOutsideScope = $false
    foreach ($command in $failedCommands) {
        $summary = [string]$command.summary
        if (Test-HarnessBlockedMessage -Text $summary) {
            return $false
        }

        $mentions = Get-HarnessPathMentionsFromSummary -Text $summary
        if (@($mentions).Count -eq 0) {
            return $false
        }

        foreach ($mention in $mentions) {
            if (-not (Test-HarnessPathMatchesAllowed -Candidate $mention -AllowedPaths $AllowedPaths)) {
                $mentionedOutsideScope = $true
                continue
            }

            return $false
        }
    }

    return $mentionedOutsideScope
}

function Test-HarnessDirtyWorktree {
    param([string]$WorkingDirectory)

    $result = Invoke-HarnessCommand -WorkingDirectory $WorkingDirectory -Command 'git status --porcelain'
    if ($result.ExitCode -ne 0) {
        return $true
    }

    return (-not [string]::IsNullOrWhiteSpace(($result.Output | Out-String).Trim()))
}

function Get-HarnessTrackedDirtyFiles {
    param([string]$WorkingDirectory)

    $result = Invoke-HarnessCommand -WorkingDirectory $WorkingDirectory -Command 'git diff --name-only'
    if ($result.ExitCode -ne 0) {
        return @()
    }

    return @(
        ($result.Output -replace "`r", '') -split "`n" |
            Where-Object {
                (-not [string]::IsNullOrWhiteSpace($_)) -and
                ($_.Trim() -notmatch '^warning:')
            } |
            ForEach-Object { $_.Trim() }
    )
}

function Get-HarnessUntrackedFiles {
    param([string]$WorkingDirectory)

    $result = Invoke-HarnessCommand -WorkingDirectory $WorkingDirectory -Command 'git ls-files --others --exclude-standard'
    if ($result.ExitCode -ne 0) {
        return @()
    }

    return @(
        ($result.Output -replace "`r", '') -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    )
}

function Get-HarnessDispatchRepoItem {
    param(
        [string]$ChangeDir,
        [string]$RepoId
    )

    $dispatchStatePath = Join-Path $ChangeDir 'runtime\dispatch-state.json'
    if (-not (Test-Path -LiteralPath $dispatchStatePath)) {
        return $null
    }

    $dispatchState = Get-Content -LiteralPath $dispatchStatePath -Raw | ConvertFrom-Json -ErrorAction Stop
    return @($dispatchState.repos | Where-Object { $_.repo_id -eq $RepoId } | Select-Object -First 1)[0]
}

function Get-HarnessScopedCandidateFiles {
    param(
        [string]$WorkingDirectory,
        [string[]]$AllowedPaths
    )

    $tracked = @(Get-HarnessTrackedDirtyFiles -WorkingDirectory $WorkingDirectory)
    $trackedAllResult = Invoke-HarnessCommand -WorkingDirectory $WorkingDirectory -Command 'git ls-files'
    $trackedAll = @()
    if ($trackedAllResult.ExitCode -eq 0) {
        $trackedAll = @(
            ($trackedAllResult.Output -replace "`r", '') -split "`n" |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_.Trim() }
        )
    }

    $untracked = @(Get-HarnessUntrackedFiles -WorkingDirectory $WorkingDirectory)
    return @(
        (@($trackedAll) + @($tracked) + @($untracked)) |
            Where-Object { Test-HarnessPathMatchesAllowed -Candidate $_ -AllowedPaths $AllowedPaths } |
            Select-Object -Unique
    )
}

function Get-HarnessFileHashSnapshot {
    param(
        [string]$WorkingDirectory,
        [string[]]$RelativeFiles
    )

    $snapshot = @{}
    foreach ($relativeFile in @($RelativeFiles | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($relativeFile)) {
            continue
        }

        $absolutePath = Join-Path $WorkingDirectory ($relativeFile -replace '/', '\')
        if (Test-Path -LiteralPath $absolutePath) {
            $snapshot[$relativeFile] = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash
        } else {
            $snapshot[$relativeFile] = '__MISSING__'
        }
    }

    return $snapshot
}

function Get-HarnessChangedFilesFromSnapshots {
    param(
        [hashtable]$Before,
        [hashtable]$After
    )

    $keys = @($Before.Keys + $After.Keys | Select-Object -Unique)
    $changed = New-Object System.Collections.Generic.List[string]
    foreach ($key in $keys) {
        $beforeValue = if ($Before.ContainsKey($key)) { [string]$Before[$key] } else { '__MISSING__' }
        $afterValue = if ($After.ContainsKey($key)) { [string]$After[$key] } else { '__MISSING__' }
        if ($beforeValue -ne $afterValue) {
            $changed.Add([string]$key)
        }
    }

    return @($changed.ToArray())
}

function Refine-WorkerResponse {
    param(
        [pscustomobject]$Response,
        [string[]]$ExpectedVerifyCommands
    )

    $commandList = @($Response.commands)
    $verifyCommands = @($ExpectedVerifyCommands | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($verifyCommands).Count -eq 0) {
        return $Response
    }

    $verificationBlocked = $false
    $verificationMissing = $false
    foreach ($expected in $verifyCommands) {
        $matched = @($commandList | Where-Object { ([string]$_.command) -eq $expected })
        if (@($matched).Count -eq 0) {
            $verificationMissing = $true
            continue
        }

        foreach ($command in $matched) {
            $summary = [string]$command.summary
            $exitCode = [int]$command.exit_code
            if (($exitCode -ne 0) -and (Test-HarnessBlockedMessage -Text $summary)) {
                $verificationBlocked = $true
            }
        }
    }

    if ($verificationBlocked) {
        $existingRisks = @($Response.risks)
        if ('本仓验证命令受环境/策略限制，当前应判定为 blocked。' -notin $existingRisks) {
            $existingRisks += '本仓验证命令受环境/策略限制，当前应判定为 blocked。'
        }
        $Response.status = 'blocked'
        $Response.risks = $existingRisks
        if (-not ([string]$Response.summary).Contains('受环境/策略限制')) {
            $Response.summary = "本仓验证命令受环境/策略限制，按运行协议改判为 blocked。原摘要：$($Response.summary)"
        }
        return $Response
    }

    if ($verificationMissing -and (($Response.status -eq 'completed') -or ($Response.status -eq 'no_changes'))) {
        $existingRisks = @($Response.risks)
        if ('本仓最小验证命令未完整回填，当前不能视为完成。' -notin $existingRisks) {
            $existingRisks += '本仓最小验证命令未完整回填，当前不能视为完成。'
        }
        $Response.status = 'blocked'
        $Response.risks = $existingRisks
        if (-not ([string]$Response.summary).Contains('最小验证命令')) {
            $Response.summary = "本仓最小验证命令未完整回填，按运行协议改判为 blocked。原摘要：$($Response.summary)"
        }
    }

    return $Response
}

function Convert-WorkerResponseToMarkdown {
    param(
        [string]$CurrentChangeId,
        [string]$RepoId,
        [string]$RepoName,
        [string]$RoleId,
        [string]$RuntimeType,
        [string]$Title,
        [pscustomobject]$Response,
        [string]$PacketPath,
        [string]$WorktreePath
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("# {0} / {1} Worker 执行结果" -f $CurrentChangeId, $RepoId))
    $lines.Add('')
    $lines.Add('## Runtime')
    $lines.Add('')
    $lines.Add(('- 变更标题：{0}' -f $Title))
    $lines.Add(('- 仓库：`{0}`' -f $RepoName))
    $lines.Add(('- 仓库 ID：`{0}`' -f $RepoId))
    $lines.Add(('- 角色：`{0}`' -f $RoleId))
    $lines.Add(('- runtime_type：`{0}`' -f $RuntimeType))
    $lines.Add(('- 当前状态：{0}' -f $Response.status))
    $lines.Add(('- worktree：`{0}`' -f $WorktreePath))
    $lines.Add(('- packet：`{0}`' -f $PacketPath))
    $lines.Add(('- worker exit code：`{0}`' -f $Response.exit_code))
    $lines.Add('')
    $lines.Add('## 执行摘要')
    $lines.Add('')
    $lines.Add(($Response.summary))
    $lines.Add('')
    $lines.Add('## 命令执行结果')
    $lines.Add('')
    $lines.Add('| 命令 | ExitCode | 摘要 |')
    $lines.Add('|------|----------|------|')
    foreach ($command in @($Response.commands)) {
        $cmd = [string]$command.command
        $cmdExitCode = [string]$command.exit_code
        $cmdSummary = [string]$command.summary
        $lines.Add(('| `{0}` | `{1}` | {2} |' -f $cmd, $cmdExitCode, $cmdSummary))
    }
    if (@($Response.commands).Count -eq 0) {
        $lines.Add('|  |  | 无 |')
    }
    $lines.Add('')
    $lines.Add('## 涉及文件')
    $lines.Add('')
    foreach ($file in @($Response.changed_files)) {
        $lines.Add(('- `{0}`' -f $file))
    }
    if (@($Response.changed_files).Count -eq 0) {
        $lines.Add('- `无`')
    }
    $lines.Add('')
    $lines.Add('## 遗留风险')
    $lines.Add('')
    foreach ($risk in @($Response.risks)) {
        $lines.Add(('- {0}' -f $risk))
    }
    if (@($Response.risks).Count -eq 0) {
        $lines.Add('- 暂无。')
    }
    $lines.Add('')
    $lines.Add('## 交接给 verification-agent')
    $lines.Add('')
    $lines.Add(($Response.handoff_note))

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

$repoRoot = Get-HarnessRepoRoot
$dispatchScript = Join-Path $repoRoot 'scripts\orchestrator\dispatch-change.ps1'
$executionPath = Join-Path $repoRoot ("changes\{0}\execution.yaml" -f $ChangeId)
$packetPath = Join-Path $repoRoot ("changes\{0}\runtime\packets\{1}-worker.md" -f $ChangeId, $RepoId)

if (-not $SkipDispatch) {
    $dispatchArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $dispatchScript,
        '-ChangeId', $ChangeId,
        '-RepoIds', $RepoId
    )
    if ($EnsureWorktrees) {
        $dispatchArgs += '-EnsureWorktrees'
    }

    & powershell @dispatchArgs
    if ($LASTEXITCODE -ne 0) {
        throw "为 $ChangeId/$RepoId 准备 worker packet 失败。"
    }
}

Write-Host ("已为 {0}/{1} 准备 worker packet：{2}" -f $ChangeId, $RepoId, $packetPath) -ForegroundColor Green

if ($PrintPacket) {
    Write-Host ''
    Get-Content -LiteralPath $packetPath
}

if (-not $Execute) {
    return
}

$execution = Parse-HarnessExecutionConfig -YamlPath $executionPath
$repoConfig = Get-HarnessRepoConfig | Where-Object { $_.id -eq $RepoId } | Select-Object -First 1
if ($null -eq $repoConfig) {
    throw "未找到仓库配置：$RepoId"
}

$registryMap = Get-HarnessAgentRegistryMap
$roleId = if ($execution.RegistryRef.ContainsKey($RepoId) -and -not [string]::IsNullOrWhiteSpace($execution.RegistryRef[$RepoId])) { $execution.RegistryRef[$RepoId] } else { $execution.RepoOwners[$RepoId] }
if (-not $registryMap.ContainsKey($roleId)) {
    throw "未找到角色配置：$roleId"
}
$roleMeta = $registryMap[$roleId]
$allowedPaths = if ($execution.WriteScopesBusiness.ContainsKey($RepoId)) { @($execution.WriteScopesBusiness[$RepoId]) } else { @() }

$changeDir = Join-Path $repoRoot ("changes\" + $ChangeId)
$runtimeDir = Join-Path $changeDir 'runtime'
$workerResponseDir = Join-Path $runtimeDir 'worker-responses'
Ensure-HarnessDirectory -Path $workerResponseDir | Out-Null

$worktreePath = if ($execution.Worktree.ContainsKey($RepoId) -and -not [string]::IsNullOrWhiteSpace($execution.Worktree[$RepoId])) { $execution.Worktree[$RepoId] } else { $repoConfig.local_path }
$workerResultRelative = if ($execution.WorkerResult.ContainsKey($RepoId)) { $execution.WorkerResult[$RepoId] } else { "verification/workers/$RepoId.md" }
$workerResultPath = Convert-ToHarnessAbsolutePath -BasePath $changeDir -RelativePath $workerResultRelative
$rawResponsePath = Join-Path $workerResponseDir ("{0}-raw.json" -f $RepoId)
$runtimeConsolePath = Join-Path $workerResponseDir ("{0}-console.log" -f $RepoId)
$normalizedResponsePath = Join-Path $workerResponseDir ("{0}.json" -f $RepoId)
$schemaPath = Join-Path $repoRoot 'schemas\worker-response.schema.json'
$repoRootPath = Unquote-HarnessScalar ([string]$repoConfig.local_path)
$resolvedWorktreePath = Unquote-HarnessScalar ([string]$worktreePath)
$dispatchRepoItem = Get-HarnessDispatchRepoItem -ChangeDir $changeDir -RepoId $RepoId
$snapshotPolicy = if (($null -ne $dispatchRepoItem) -and -not [string]::IsNullOrWhiteSpace([string]$dispatchRepoItem.snapshot_policy)) { [string]$dispatchRepoItem.snapshot_policy } else { '' }
$snapshotTrackedFiles = if (($null -ne $dispatchRepoItem) -and ($null -ne $dispatchRepoItem.snapshot_tracked_files)) { @($dispatchRepoItem.snapshot_tracked_files) } else { @() }
$dispatchBlockedReason = if (($null -ne $dispatchRepoItem) -and -not [string]::IsNullOrWhiteSpace([string]$dispatchRepoItem.blocked_reason)) { [string]$dispatchRepoItem.blocked_reason } else { '' }

if (-not $NoCodeChanges) {
    if (-not [string]::IsNullOrWhiteSpace($dispatchBlockedReason)) {
        throw "当前派工已被 dispatcher 标记为 blocked：$dispatchBlockedReason"
    }

    if ($resolvedWorktreePath -eq $repoRootPath) {
        throw "真实写代码模式禁止直接在主仓工作树执行：$RepoId。请先通过 dispatch-change/EnsureWorktrees 切到独立 worktree。"
    }

    if (-not (Test-Path -LiteralPath $resolvedWorktreePath)) {
        throw "未找到独立 worktree：$resolvedWorktreePath"
    }

    $trackedDirtyBeforeRun = @(Get-HarnessTrackedDirtyFiles -WorkingDirectory $resolvedWorktreePath)
    $untrackedBeforeRun = @(Get-HarnessUntrackedFiles -WorkingDirectory $resolvedWorktreePath)
    if ((@($trackedDirtyBeforeRun).Count -gt 0) -or (@($untrackedBeforeRun).Count -gt 0)) {
        $allowSnapshotDirty = ($snapshotPolicy -eq 'source_dirty_tracked')
        if (-not $allowSnapshotDirty) {
            throw "当前 worktree 非干净状态，禁止作为真实写代码执行入口：$resolvedWorktreePath"
        }

        if (@($untrackedBeforeRun).Count -gt 0) {
            throw "当前 worktree 存在未跟踪文件，不能作为 source_dirty_tracked 入口：$($untrackedBeforeRun -join '、')"
        }

        $unexpectedDirty = @($trackedDirtyBeforeRun | Where-Object { $_ -notin $snapshotTrackedFiles })
        if (@($unexpectedDirty).Count -gt 0) {
            throw "当前 worktree 存在未登记到 snapshot 的脏文件：$($unexpectedDirty -join '、')"
        }
    }
}

$scopedFilesBeforeRun = @(Get-HarnessScopedCandidateFiles -WorkingDirectory $worktreePath -AllowedPaths $allowedPaths)
$scopedHashesBeforeRun = Get-HarnessFileHashSnapshot -WorkingDirectory $worktreePath -RelativeFiles $scopedFilesBeforeRun

$packetContent = Get-Content -LiteralPath $packetPath -Raw
$promptLines = @(
    "你是示例产品项目中的 repo worker，当前扮演角色 `$roleId`。",
    "你正在本地 Harness Engineering V1 运行面中执行任务。",
    "本次唯一目标是：严格按照 worker packet 和任务卡，在 write scope 内完成真实代码修改与本仓验证。",
    "不要回答元问题、不要解释运行协议、不要复述规则；你必须优先查看目标文件并尝试完成任务卡定义的代码实现。",
    "必须严格遵守：",
    "1. 只允许在当前 worktree 内工作。",
    "2. 只允许修改 packet 中列出的 write scope。",
    "3. 不得修改控制仓文件，不得改写 verification/result.md。",
    "4. 完成后必须运行本仓最小验证命令。",
    "5. 最终只输出符合给定 JSON schema 的 JSON，不要附加额外解释。",
    "6. 如果任务信息不足、write scope 不足、验证失败无法收敛，返回 status=blocked 或 status=failed。",
    "7. 如果 packet 附带了最近 review 结果，且 review 指出了 write scope 内仍未修复的问题，这些 finding 就是本轮必修项。",
    "8. 不得仅因目标文件已经有未提交改动就返回 `no_changes`；必须以 review finding 是否已经被当前文件内容消除为准。",
    "9. 如果最近 review JSON 中存在 `needs_rework=true`，而对应 finding 仍落在当前 write scope 内，则本轮的默认目标就是修复这些 finding；除非你已经真的改完并能解释为什么当前文件内容已满足要求，否则不得返回 `no_changes`。",
    "10. 在真实写代码模式下，只有当本轮确实产生了 write scope 内的代码变更时，才允许返回 `completed`。",
    "11. 如果你返回的内容主要是在解释 harness、role、schema、packet 或执行规则，而没有进入目标文件修改与验证，这次执行视为失败。",
    ""
)

if ($NoCodeChanges) {
    $promptLines += @(
        "当前是执行链烟测模式：",
        "- 不允许修改任何仓库文件。",
        "- 只允许阅读 packet、检查工作区、必要时运行只读命令。",
        "- 最终返回 status=no_changes，并说明如果正式执行会怎么做。"
    )
    $sandboxMode = 'read-only'
} else {
    $sandboxMode = 'workspace-write'
}

$promptLines += @(
    "",
    "下面是本次 worker packet：",
    "",
    $packetContent
)

$prompt = (($promptLines -join [Environment]::NewLine).Trim()) + [Environment]::NewLine

$codexArgs = @(
    'exec',
    '-',
    '-C', $worktreePath,
    '-s', $sandboxMode,
    '--output-schema', $schemaPath,
    '-o', $rawResponsePath,
    '--color', 'never'
)
if ($Ephemeral) {
    $codexArgs += '--ephemeral'
}
if (-not [string]::IsNullOrWhiteSpace($Model)) {
    $codexArgs += @('-m', $Model)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$previousConsoleOutputEncoding = [Console]::OutputEncoding
$previousConsoleInputEncoding = [Console]::InputEncoding
$previousPsOutputEncoding = $OutputEncoding
$runtimeConsoleOutput = ''
$previousRunRoleErrorActionPreference = $ErrorActionPreference
$hasNativeErrorPreference = $false
$previousNativeErrorPreference = $null
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $hasNativeErrorPreference = $true
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
}
try {
    [Console]::OutputEncoding = $utf8NoBom
    [Console]::InputEncoding = $utf8NoBom
    $OutputEncoding = $utf8NoBom
    $ErrorActionPreference = 'Continue'
    if ($hasNativeErrorPreference) {
        $PSNativeCommandUseErrorActionPreference = $false
    }
    $runtimeOutputLines = @(
        $prompt |
            & codex @codexArgs 2>&1 |
            ForEach-Object { $_.ToString() }
    )
    $workerExitCode = $LASTEXITCODE
    $runtimeConsoleOutput = ($runtimeOutputLines -join [Environment]::NewLine).Trim()
} finally {
    [Console]::OutputEncoding = $previousConsoleOutputEncoding
    [Console]::InputEncoding = $previousConsoleInputEncoding
    $OutputEncoding = $previousPsOutputEncoding
    $ErrorActionPreference = $previousRunRoleErrorActionPreference
    if ($hasNativeErrorPreference) {
        $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    }
}

if (-not [string]::IsNullOrWhiteSpace($runtimeConsoleOutput)) {
    Write-Host $runtimeConsoleOutput
    Write-HarnessTextFile -Path $runtimeConsolePath -Content ($runtimeConsoleOutput + [Environment]::NewLine)
}

$rawResponse = if (Test-Path -LiteralPath $rawResponsePath) { Get-Content -LiteralPath $rawResponsePath -Raw } else { '' }
if ([string]::IsNullOrWhiteSpace($rawResponse) -and -not [string]::IsNullOrWhiteSpace($runtimeConsoleOutput)) {
    $rawResponse = $runtimeConsoleOutput
}
$parsedResponse = $null
if (-not [string]::IsNullOrWhiteSpace($rawResponse)) {
    try {
        $parsedResponse = $rawResponse | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $parsedResponse = $null
    }
}

$normalizedResponse = Normalize-WorkerResponse -ParsedResponse $parsedResponse -RawResponse $rawResponse -ExitCode $workerExitCode
$runtimeBlocked = $false
if (($workerExitCode -ne 0) -and ($null -eq $parsedResponse)) {
    $existingRisks = @($normalizedResponse.risks)
    $runtimeMessage = if (Test-HarnessUsageLimitMessage -Text $rawResponse) {
        'repo worker 未返回结构化结果，已捕获到外部 codex exec usage limit / 平台额度阻断。'
    } else {
        'repo worker 未返回结构化结果，疑似被外部 runtime / 平台执行层阻断。'
    }
    if ($runtimeMessage -notin $existingRisks) {
        $existingRisks += $runtimeMessage
    }
    $normalizedResponse.status = 'blocked'
    if (Test-HarnessUsageLimitMessage -Text $rawResponse) {
        $normalizedResponse.summary = 'repo worker 未返回结构化 JSON，当前按外部 codex exec usage limit 阻断处理。'
        $normalizedResponse.handoff_note = '请 verification-agent 将本轮记为外部 runtime 额度阻断；待额度/窗口恢复后重跑 repo worker。'
    } else {
        $normalizedResponse.summary = 'repo worker 未返回结构化 JSON，当前按外部 runtime 阻断处理。'
        $normalizedResponse.handoff_note = '请 verification-agent 将本轮记为外部运行资源阻断；待 runtime 恢复后重跑 repo worker。'
    }
    $normalizedResponse.risks = $existingRisks
    $runtimeBlocked = $true
}
$normalizedResponse = Refine-WorkerResponse -Response $normalizedResponse -ExpectedVerifyCommands @($roleMeta.verify_commands)
if ((-not $NoCodeChanges) -and (-not $runtimeBlocked)) {
    $normalizedResponse = Invoke-WrapperVerifyCommands -WorkingDirectory $worktreePath -Commands @($roleMeta.verify_commands) -CurrentResponse $normalizedResponse
    $normalizedResponse = Refine-WorkerResponse -Response $normalizedResponse -ExpectedVerifyCommands @($roleMeta.verify_commands)
}
$scopedFilesAfterRun = @(Get-HarnessScopedCandidateFiles -WorkingDirectory $worktreePath -AllowedPaths $allowedPaths)
$scopedHashesAfterRun = Get-HarnessFileHashSnapshot -WorkingDirectory $worktreePath -RelativeFiles (@($scopedFilesBeforeRun) + @($scopedFilesAfterRun))
$actualWorkerChangedFiles = @(Get-HarnessChangedFilesFromSnapshots -Before $scopedHashesBeforeRun -After $scopedHashesAfterRun)
$scopedChangedFiles = @(Get-ScopedChangedFiles -WorkingDirectory $worktreePath -AllowedPaths $allowedPaths)
if (@($actualWorkerChangedFiles).Count -gt 0) {
    $normalizedResponse.changed_files = [object[]]@($actualWorkerChangedFiles)
} elseif ((@($scopedChangedFiles).Count -gt 0) -and (@($normalizedResponse.changed_files).Count -eq 0)) {
    $normalizedResponse.changed_files = [object[]]$scopedChangedFiles
}
if (($normalizedResponse.status -eq 'failed') -and (Test-OutOfScopeRepoValidationDebt -Response $normalizedResponse -AllowedPaths $allowedPaths -ChangedFiles @($normalizedResponse.changed_files))) {
    $existingRisks = @($normalizedResponse.risks)
    if ('仓库级验证被 write scope 外历史债阻断，当前应判定为 blocked 而非 failed。' -notin $existingRisks) {
        $existingRisks += '仓库级验证被 write scope 外历史债阻断，当前应判定为 blocked 而非 failed。'
    }
    $normalizedResponse.status = 'blocked'
    $normalizedResponse.risks = $existingRisks
    $normalizedResponse.summary = "write scope 内实现与目标文件校验已完成，但仓库级验证仍被 write scope 外历史债阻断，按运行协议改判为 blocked。原摘要：$($normalizedResponse.summary)"
    $normalizedResponse.handoff_note = '请 verification-agent 区分 write scope 内通过与 scope 外历史债阻断；本轮不应按 worker 实现失败处理。'
}
if (($normalizedResponse.status -eq 'completed') -and (@($normalizedResponse.changed_files).Count -gt 0)) {
    $normalizedResponse.summary = "repo worker 已在 write scope 内完成实现收敛，wrapper 已补跑本仓最小验证命令并通过。当前核对到的变更文件：$((@($normalizedResponse.changed_files) -join '、'))。"
    $normalizedResponse.handoff_note = "请 verification-agent 基于当前 changed_files、命令结果和实际文件内容继续做结构化审查；本轮主结论以 wrapper 回填后的 worker result 为准，不再沿用原始 raw_response 中的旧状态判断。"
}
if (
    (-not $NoCodeChanges) -and
    ($normalizedResponse.status -eq 'completed') -and
    (@($actualWorkerChangedFiles).Count -eq 0)
) {
    $existingRisks = @($normalizedResponse.risks)
    if ('本轮未检测到 write scope 内新增代码变更，不能视为真实 no-hand-code 完成。' -notin $existingRisks) {
        $existingRisks += '本轮未检测到 write scope 内新增代码变更，不能视为真实 no-hand-code 完成。'
    }
    $normalizedResponse.status = 'blocked'
    $normalizedResponse.risks = $existingRisks
    $normalizedResponse.summary = "当前 worktree 已带有 snapshot 基线，但本轮未检测到 repo worker 在 write scope 内产生新的文件内容变化，按运行协议改判为 blocked。原摘要：$($normalizedResponse.summary)"
    $normalizedResponse.handoff_note = '请确认本轮是否真的需要代码变更；如果需要，则应继续退回 repo worker，而不是直接宣布完成。'
}
Write-HarnessJsonFile -Path $normalizedResponsePath -Data $normalizedResponse

$workerResultMarkdown = Convert-WorkerResponseToMarkdown -CurrentChangeId $ChangeId -RepoId $RepoId -RepoName $repoConfig.name -RoleId $roleId -RuntimeType $roleMeta.runtime_type -Title $execution.Title -Response $normalizedResponse -PacketPath $packetPath -WorktreePath $worktreePath
Write-HarnessTextFile -Path $workerResultPath -Content $workerResultMarkdown

Write-Host ("worker 已执行：{0}/{1} -> {2}" -f $ChangeId, $RepoId, $workerResultPath) -ForegroundColor Green
Write-Host ("worker response: {0}" -f $normalizedResponsePath) -ForegroundColor Cyan

if (($workerExitCode -ne 0) -and ($null -eq $parsedResponse) -and (-not $runtimeBlocked) -and ($normalizedResponse.status -eq 'failed')) {
    throw "worker 执行失败：$ChangeId/$RepoId（exit code=$workerExitCode）"
}
