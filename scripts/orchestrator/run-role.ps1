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
        summary = 'The final worker output could not be parsed as structured JSON. See raw_response.'
        changed_files = @()
        commands = @()
        risks = @('Invalid worker output format. Manually inspect the runtime logs.')
        handoff_note = 'Inspect raw_response manually and decide whether to rerun the worker.'
        exit_code = $ExitCode
        raw_response = $RawResponse
    }
}

function Test-HarnessBlockedMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    # Match English diagnostics and retain legacy Chinese diagnostics from external tools.
    return $Text -match 'environment restrictions|restricted by the environment or policy|not installed locally|blocked by policy|rejected: blocked by policy|受环境限制|环境策略|当前环境.*阻止|无法执行|沙箱策略|sandbox|权限限制|EACCES|未安装到本地可执行路径|缺少 .+ 可执行文件|is not recognized as an internal or external command'
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
            if ($result.ExitCode -eq 0) { 'The wrapper ran and repository verification commands passed.' } else { 'The wrapper ran, but the command failed without output.' }
        } else {
            $normalized = $trimmedOutput -replace "`r", ' ' -replace "`n", ' '
            if ($normalized.Length -gt 300) {
                $normalized = $normalized.Substring(0, 300) + '...'
            }
            if ($result.ExitCode -eq 0) {
                "The wrapper ran successfully: $normalized"
            } else {
                "The wrapper ran but failed: $normalized"
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
        ($_ -ne 'Repository verification commands are restricted by the environment or policy; classify this run as blocked.') -and
        ($_ -notmatch 'the current environment prohibits Node/npm/npx commands|当前环境禁止执行 Node/npm/npx 命令')
    })
    if ($wrapperHasFailure) {
        if ('The wrapper reran repository verification commands, but failures remain.' -notin $existingRisks) {
            $existingRisks += 'The wrapper reran repository verification commands, but failures remain.'
        }
        if ($CurrentResponse.status -eq 'blocked') {
            $CurrentResponse.status = 'failed'
        }
    } else {
        if ($CurrentResponse.status -eq 'blocked') {
            $CurrentResponse.status = 'completed'
        }
        if (-not [string]::IsNullOrWhiteSpace($CurrentResponse.summary)) {
            $CurrentResponse.summary = "The wrapper ran the missing minimum repository verification commands successfully. Original summary: $($CurrentResponse.summary)"
        } else {
            $CurrentResponse.summary = 'The wrapper ran the missing minimum repository verification commands successfully.'
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
        if ('Repository verification commands are restricted by the environment or policy; classify this run as blocked.' -notin $existingRisks) {
            $existingRisks += 'Repository verification commands are restricted by the environment or policy; classify this run as blocked.'
        }
        $Response.status = 'blocked'
        $Response.risks = $existingRisks
        if (-not ([string]$Response.summary).Contains('restricted by the environment or policy')) {
            $Response.summary = "Repository verification commands are restricted by the environment or policy. Reclassified as blocked under the runtime protocol. Original summary: $($Response.summary)"
        }
        return $Response
    }

    if ($verificationMissing -and (($Response.status -eq 'completed') -or ($Response.status -eq 'no_changes'))) {
        $existingRisks = @($Response.risks)
        if ('Minimum repository verification results are incomplete; this run cannot be considered complete.' -notin $existingRisks) {
            $existingRisks += 'Minimum repository verification results are incomplete; this run cannot be considered complete.'
        }
        $Response.status = 'blocked'
        $Response.risks = $existingRisks
        if (-not ([string]$Response.summary).Contains('Minimum repository verification')) {
            $Response.summary = "Minimum repository verification results are incomplete. Reclassified as blocked under the runtime protocol. Original summary: $($Response.summary)"
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
    $lines.Add(("# {0} / {1} Worker execution results" -f $CurrentChangeId, $RepoId))
    $lines.Add('')
    $lines.Add('## Runtime')
    $lines.Add('')
    $lines.Add(('- Change title: {0}' -f $Title))
    $lines.Add(('- Repository: `{0}`' -f $RepoName))
    $lines.Add(('- Repository ID: `{0}`' -f $RepoId))
    $lines.Add(('- Role: `{0}`' -f $RoleId))
    $lines.Add(('- runtime_type: `{0}`' -f $RuntimeType))
    $lines.Add(('- Current status: {0}' -f $Response.status))
    $lines.Add(('- worktree: `{0}`' -f $WorktreePath))
    $lines.Add(('- packet: `{0}`' -f $PacketPath))
    $lines.Add(('- worker exit code: `{0}`' -f $Response.exit_code))
    $lines.Add('')
    $lines.Add('## Execution summary')
    $lines.Add('')
    $lines.Add(($Response.summary))
    $lines.Add('')
    $lines.Add('## Command execution results')
    $lines.Add('')
    $lines.Add('| Command | ExitCode | Summary |')
    $lines.Add('|------|----------|------|')
    foreach ($command in @($Response.commands)) {
        $cmd = [string]$command.command
        $cmdExitCode = [string]$command.exit_code
        $cmdSummary = [string]$command.summary
        $lines.Add(('| `{0}` | `{1}` | {2} |' -f $cmd, $cmdExitCode, $cmdSummary))
    }
    if (@($Response.commands).Count -eq 0) {
        $lines.Add('|  |  | None |')
    }
    $lines.Add('')
    $lines.Add('## Affected files')
    $lines.Add('')
    foreach ($file in @($Response.changed_files)) {
        $lines.Add(('- `{0}`' -f $file))
    }
    if (@($Response.changed_files).Count -eq 0) {
        $lines.Add('- `None`')
    }
    $lines.Add('')
    $lines.Add('## Remaining risks')
    $lines.Add('')
    foreach ($risk in @($Response.risks)) {
        $lines.Add(('- {0}' -f $risk))
    }
    if (@($Response.risks).Count -eq 0) {
        $lines.Add('- None.')
    }
    $lines.Add('')
    $lines.Add('## Handoff to verification-agent')
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
        throw "Failed to prepare worker packet for $ChangeId/$RepoId."
    }
}

Write-Host ("Prepared worker packet for {0}/{1}: {2}" -f $ChangeId, $RepoId, $packetPath) -ForegroundColor Green

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
    throw "Repository configuration not found: $RepoId"
}

$registryMap = Get-HarnessAgentRegistryMap
$roleId = if ($execution.RegistryRef.ContainsKey($RepoId) -and -not [string]::IsNullOrWhiteSpace($execution.RegistryRef[$RepoId])) { $execution.RegistryRef[$RepoId] } else { $execution.RepoOwners[$RepoId] }
if (-not $registryMap.ContainsKey($roleId)) {
    throw "Role configuration not found: $roleId"
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
        throw "The dispatcher has marked this assignment as blocked: $dispatchBlockedReason"
    }

    if ($resolvedWorktreePath -eq $repoRootPath) {
        throw "Actual code-editing mode cannot run directly in the main repository working tree: $RepoId. Use dispatch-change/EnsureWorktrees to switch to an isolated worktree first."
    }

    if (-not (Test-Path -LiteralPath $resolvedWorktreePath)) {
        throw "Isolated worktree not found: $resolvedWorktreePath"
    }

    $trackedDirtyBeforeRun = @(Get-HarnessTrackedDirtyFiles -WorkingDirectory $resolvedWorktreePath)
    $untrackedBeforeRun = @(Get-HarnessUntrackedFiles -WorkingDirectory $resolvedWorktreePath)
    if ((@($trackedDirtyBeforeRun).Count -gt 0) -or (@($untrackedBeforeRun).Count -gt 0)) {
        $allowSnapshotDirty = ($snapshotPolicy -eq 'source_dirty_tracked')
        if (-not $allowSnapshotDirty) {
            throw "The current worktree is dirty and cannot be used for actual code-editing execution: $resolvedWorktreePath"
        }

        if (@($untrackedBeforeRun).Count -gt 0) {
            throw "The current worktree contains untracked files and cannot be used for source_dirty_tracked: $($untrackedBeforeRun -join ', ')"
        }

        $unexpectedDirty = @($trackedDirtyBeforeRun | Where-Object { $_ -notin $snapshotTrackedFiles })
        if (@($unexpectedDirty).Count -gt 0) {
            throw "The current worktree contains dirty files not registered in the snapshot: $($unexpectedDirty -join ', ')"
        }
    }
}

$scopedFilesBeforeRun = @(Get-HarnessScopedCandidateFiles -WorkingDirectory $worktreePath -AllowedPaths $allowedPaths)
$scopedHashesBeforeRun = Get-HarnessFileHashSnapshot -WorkingDirectory $worktreePath -RelativeFiles $scopedFilesBeforeRun

$packetContent = Get-Content -LiteralPath $packetPath -Raw
$promptLines = @(
    "You are a repository worker for the example product, acting as `$roleId`.",
    "You are executing a task in the local Harness Engineering V1 runtime.",
    "Your sole objective is to implement actual code changes and verify this repository within the write scope, following the worker packet and task card exactly.",
    "Inspect the target files and attempt the implementation defined in the task card first. Do not answer meta-questions, explain the runtime protocol, or repeat the rules.",
    "Follow these requirements strictly:",
    "1. Work only in the current worktree.",
    "2. Modify only the write scope listed in the packet.",
    "3. Do not modify control-repository files or rewrite verification/result.md.",
    "4. Run the repository's minimum verification commands when finished.",
    "5. Return only JSON matching the provided JSON schema, without additional explanation.",
    "6. If task information or write scope is insufficient, or verification failures cannot be resolved, return status=blocked or status=failed.",
    "7. If the packet includes recent review results with unresolved findings inside the write scope, those findings must be fixed in this run.",
    "8. Do not return `no_changes` merely because target files already have uncommitted edits. Check whether current file content resolves the review findings.",
    "9. If the latest review JSON has `needs_rework=true` and the findings fall within the current write scope, fix those findings in this run. Do not return `no_changes` unless they have actually been resolved and you can explain why the current file content meets the requirements.",
    "10. In actual code-editing mode, return `completed` only if this run produced code changes within the write scope.",
    "11. This run fails if the response mainly explains the harness, role, schema, packet, or execution rules without modifying and verifying the target files.",
    ""
)

if ($NoCodeChanges) {
    $promptLines += @(
        "This is an execution-workflow smoke test:",
        "- Do not modify any repository files.",
        "- Only read the packet, inspect the workspace, and run read-only commands if needed.",
        "- Return status=no_changes and explain what a full execution would do."
    )
    $sandboxMode = 'read-only'
} else {
    $sandboxMode = 'workspace-write'
}

$promptLines += @(
    "",
    "Worker packet for this run:",
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
        'The repository worker returned no structured result. An external codex exec usage limit or platform quota block was detected.'
    } else {
        'The repository worker returned no structured result and may be blocked by the external runtime or platform execution layer.'
    }
    if ($runtimeMessage -notin $existingRisks) {
        $existingRisks += $runtimeMessage
    }
    $normalizedResponse.status = 'blocked'
    if (Test-HarnessUsageLimitMessage -Text $rawResponse) {
        $normalizedResponse.summary = 'The repository worker returned no structured JSON. Treat this as an external codex exec usage limit block.'
        $normalizedResponse.handoff_note = 'Have verification-agent record an external runtime quota block. Rerun the repository worker when the quota or execution window is available again.'
    } else {
        $normalizedResponse.summary = 'The repository worker returned no structured JSON. Treat this as an external runtime block.'
        $normalizedResponse.handoff_note = 'Have verification-agent record an external runtime resource block. Rerun the repository worker when the runtime recovers.'
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
    if ('Repository verification is blocked by pre-existing issues outside the write scope. Classify this run as blocked rather than failed.' -notin $existingRisks) {
        $existingRisks += 'Repository verification is blocked by pre-existing issues outside the write scope. Classify this run as blocked rather than failed.'
    }
    $normalizedResponse.status = 'blocked'
    $normalizedResponse.risks = $existingRisks
    $normalizedResponse.summary = "Implementation and target-file checks within the write scope are complete, but repository verification is blocked by pre-existing issues outside that scope. Reclassified as blocked under the runtime protocol. Original summary: $($normalizedResponse.summary)"
    $normalizedResponse.handoff_note = 'Have verification-agent distinguish passing checks within the write scope from pre-existing blockers outside it. This run should not be classified as a worker implementation failure.'
}
if (($normalizedResponse.status -eq 'completed') -and (@($normalizedResponse.changed_files).Count -gt 0)) {
    $normalizedResponse.summary = "The repository worker completed implementation within the write scope, and the wrapper ran the missing minimum repository verification commands successfully. Confirmed changed files: $((@($normalizedResponse.changed_files) -join ', '))."
    $normalizedResponse.handoff_note = "Have verification-agent continue the structured review using current changed_files, command results, and actual file content. Use the worker result updated by the wrapper as the authoritative conclusion, rather than the outdated status in the original raw_response."
}
if (
    (-not $NoCodeChanges) -and
    ($normalizedResponse.status -eq 'completed') -and
    (@($actualWorkerChangedFiles).Count -eq 0)
) {
    $existingRisks = @($normalizedResponse.risks)
    if ('No new code changes were detected within the write scope in this run. It cannot count as an actual no-hand-code completion.' -notin $existingRisks) {
        $existingRisks += 'No new code changes were detected within the write scope in this run. It cannot count as an actual no-hand-code completion.'
    }
    $normalizedResponse.status = 'blocked'
    $normalizedResponse.risks = $existingRisks
    $normalizedResponse.summary = "The worktree contains the snapshot baseline, but no new file-content changes by the repository worker were detected within the write scope in this run. Reclassified as blocked under the runtime protocol. Original summary: $($normalizedResponse.summary)"
    $normalizedResponse.handoff_note = 'Confirm whether this run actually requires code changes. If so, return it to the repository worker rather than declaring it complete.'
}
Write-HarnessJsonFile -Path $normalizedResponsePath -Data $normalizedResponse

$workerResultMarkdown = Convert-WorkerResponseToMarkdown -CurrentChangeId $ChangeId -RepoId $RepoId -RepoName $repoConfig.name -RoleId $roleId -RuntimeType $roleMeta.runtime_type -Title $execution.Title -Response $normalizedResponse -PacketPath $packetPath -WorktreePath $worktreePath
Write-HarnessTextFile -Path $workerResultPath -Content $workerResultMarkdown

Write-Host ("Worker executed: {0}/{1} -> {2}" -f $ChangeId, $RepoId, $workerResultPath) -ForegroundColor Green
Write-Host ("worker response: {0}" -f $normalizedResponsePath) -ForegroundColor Cyan

if (($workerExitCode -ne 0) -and ($null -eq $parsedResponse) -and (-not $runtimeBlocked) -and ($normalizedResponse.status -eq 'failed')) {
    throw "Worker execution failed: $ChangeId/$RepoId (exit code=$workerExitCode)"
}
