[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ChangeId,

    [string[]]$RepoIds,

    [switch]$EnsureWorktrees,

    [switch]$DryRun,

    [switch]$ExecuteWorkers,

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

function Get-DefaultDispatchWorktree {
    param(
        [string]$RepoRoot,
        [string]$CurrentChangeId,
        [string]$RepoId
    )

    return Join-Path $RepoRoot ("worktrees\" + $CurrentChangeId + "\" + $RepoId)
}

function Resolve-DispatchWorktreePath {
    param(
        [string]$RepoRoot,
        [string]$CurrentChangeId,
        [pscustomobject]$RepoMeta,
        [string]$ConfiguredWorktree,
        [bool]$RequireIsolatedWorktree
    )

    $defaultWorktree = Get-DefaultDispatchWorktree -RepoRoot $RepoRoot -CurrentChangeId $CurrentChangeId -RepoId ([string]$RepoMeta.id)
    if ([string]::IsNullOrWhiteSpace($ConfiguredWorktree)) {
        return $defaultWorktree
    }

    $normalizedConfigured = Unquote-HarnessScalar $ConfiguredWorktree
    $normalizedRepoPath = Unquote-HarnessScalar ([string]$RepoMeta.local_path)
    if ($RequireIsolatedWorktree -and ($normalizedConfigured -eq $normalizedRepoPath)) {
        return $defaultWorktree
    }

    return $normalizedConfigured
}

function Get-ArrayOrEmpty {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value)
    }

    return @($Value)
}

function Normalize-HarnessDispatchPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return (($Path -replace '\\', '/').Trim())
}

function Test-HarnessDispatchPathMatchesAllowed {
    param(
        [string]$Candidate,
        [string[]]$AllowedPaths
    )

    $normalizedCandidate = Normalize-HarnessDispatchPath -Path $Candidate
    if ([string]::IsNullOrWhiteSpace($normalizedCandidate)) {
        return $false
    }

    foreach ($allowedPath in @($AllowedPaths)) {
        $normalizedAllowed = Normalize-HarnessDispatchPath -Path $allowedPath
        if ([string]::IsNullOrWhiteSpace($normalizedAllowed)) {
            continue
        }

        $wildcard = $normalizedAllowed.Replace('**', '*')
        if (
            ($normalizedCandidate -eq $normalizedAllowed) -or
            ($normalizedCandidate -like $wildcard) -or
            $normalizedCandidate.EndsWith("/$normalizedAllowed") -or
            $normalizedCandidate.EndsWith($normalizedAllowed)
        ) {
            return $true
        }
    }

    return $false
}

function Get-HarnessTrackedDirtyFiles {
    param([string]$RepoPath)

    $result = Invoke-HarnessCommand -Command 'git diff --name-only 2>nul' -WorkingDirectory $RepoPath
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

function Get-HarnessTrackedDirtyEntries {
    param([string]$RepoPath)

    $result = Invoke-HarnessCommand -Command 'git diff --name-status HEAD 2>nul' -WorkingDirectory $RepoPath
    if ($result.ExitCode -ne 0) {
        return @()
    }

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($line in (($result.Output -replace "`r", '') -split "`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed -match '^warning:') {
            continue
        }

        $parts = $trimmed -split "`t"
        if ($parts.Count -lt 2) {
            continue
        }

        $entries.Add([pscustomobject]@{
            status = [string]$parts[0]
            path = [string]$parts[1]
        })
    }

    return @($entries.ToArray())
}

function Get-HarnessUntrackedFiles {
    param([string]$RepoPath)

    $result = Invoke-HarnessCommand -Command 'git ls-files --others --exclude-standard' -WorkingDirectory $RepoPath
    if ($result.ExitCode -ne 0) {
        return @()
    }

    return @(
        ($result.Output -replace "`r", '') -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    )
}

function Test-HarnessDispatchWorktreeClean {
    param([string]$RepoPath)

    $trackedDirty = @(Get-HarnessTrackedDirtyFiles -RepoPath $RepoPath)
    if ($trackedDirty.Count -gt 0) {
        return $false
    }

    $untracked = @(Get-HarnessUntrackedFiles -RepoPath $RepoPath)
    return ($untracked.Count -eq 0)
}

function Get-HarnessHeadCommit {
    param([string]$RepoPath)

    $result = Invoke-HarnessCommand -Command 'git rev-parse HEAD' -WorkingDirectory $RepoPath
    if ($result.ExitCode -ne 0) {
        return ''
    }

    return ($result.Output | Out-String).Trim()
}

function Get-HarnessFilesMatchingAllowedPaths {
    param(
        [string[]]$Files,
        [string[]]$AllowedPaths
    )

    return @(
        @($Files) |
            Where-Object { Test-HarnessDispatchPathMatchesAllowed -Candidate $_ -AllowedPaths $AllowedPaths } |
            Select-Object -Unique
    )
}

function Get-HarnessEntriesMatchingAllowedPaths {
    param(
        [object[]]$Entries,
        [string[]]$AllowedPaths
    )

    return @(
        @($Entries) |
            Where-Object { Test-HarnessDispatchPathMatchesAllowed -Candidate ([string]$_.path) -AllowedPaths $AllowedPaths }
    )
}

function Get-DispatchSnapshotPolicy {
    param(
        [pscustomobject]$ExecutionConfig,
        [string]$RepoId
    )

    if ($ExecutionConfig.SnapshotPolicy.ContainsKey($RepoId) -and -not [string]::IsNullOrWhiteSpace($ExecutionConfig.SnapshotPolicy[$RepoId])) {
        return [string]$ExecutionConfig.SnapshotPolicy[$RepoId]
    }

    return 'source_dirty_tracked'
}

function Read-HarnessTextOrEmpty {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    return (Get-Content -LiteralPath $Path -Raw).Trim()
}

function Get-RepoRulePath {
    param(
        [string]$RepoRoot,
        [string]$RepoId
    )

    $candidateMap = @{
        'backend'    = 'standards\backend\backend-rules.md'
        'web-portal'    = 'standards\web\web-portal-rules.md'
        'admin-web'  = 'standards\web\admin-web-rules.md'
        'mobile-a' = 'standards\mobile\mobile-a-rules.md'
    }

    if (-not $candidateMap.ContainsKey($RepoId)) {
        return $null
    }

    $candidate = Join-Path $RepoRoot $candidateMap[$RepoId]
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    return $null
}

function Get-LatestBaselineSummary {
    param([string]$RepoRoot)

    $reportDir = Join-Path $RepoRoot 'reports\local-validation'
    if (-not (Test-Path -LiteralPath $reportDir)) {
        return $null
    }

    $latest = Get-ChildItem -LiteralPath $reportDir -Filter '*-summary.md' |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    return $latest
}

function Add-ContentSection {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Heading,
        [string]$Body
    )

    $codeFence = '```'
    $Lines.Add(("### {0}" -f $Heading))
    $Lines.Add('')
    if ([string]::IsNullOrWhiteSpace($Body)) {
        $Lines.Add('None')
        $Lines.Add('')
        return
    }

    $Lines.Add(('{0}text' -f $codeFence))
    foreach ($line in (($Body -replace "`r", '') -split "`n")) {
        $Lines.Add($line)
    }
    $Lines.Add($codeFence)
    $Lines.Add('')
}

function Resolve-ExistingRelativeFile {
    param(
        [string]$BasePath,
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        $resolved = Convert-ToHarnessAbsolutePath -BasePath $BasePath -RelativePath $candidate
        if (Test-Path -LiteralPath $resolved) {
            return $resolved
        }
    }

    return $null
}

function New-WorkerPacketContent {
    param(
        [string]$CurrentChangeId,
        [string]$ChangeTitle,
        [pscustomobject]$RepoMeta,
        [pscustomobject]$RoleMeta,
        [pscustomobject]$ExecutionConfig,
        [string]$ResolvedWorktree,
        [string]$SnapshotPolicy,
        [string]$SnapshotSource,
        [string[]]$SnapshotTrackedFiles,
        [string[]]$SnapshotActions,
        [string]$SnapshotBlockedReason,
        [string]$WorkerResultRelative,
        [string]$ReviewResultRelative,
        [string[]]$AllowedPaths,
        [string]$BriefContent,
        [string]$ImpactContent,
        [string]$ExecutionContent,
        [string]$TaskContent,
        [string]$RuleContent,
        [string]$BaselineSummary,
        [string]$BaselineSummaryPath,
        [string]$LatestReviewContent,
        [string]$LatestReviewHeading,
        [string]$LatestReviewJsonContent,
        [string]$LatestReviewJsonHeading
    )

    $roleSkills = Get-ArrayOrEmpty -Value $RoleMeta.default_skills
    $roleVerifyCommands = Get-ArrayOrEmpty -Value $RoleMeta.verify_commands
    $safeCheckCommands = Get-ArrayOrEmpty -Value $RepoMeta.safe_check_commands

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("# Worker Packet / {0} / {1}" -f $CurrentChangeId, $RepoMeta.id))
    $lines.Add('')
    $lines.Add('## Role binding')
    $lines.Add('')
    $lines.Add(('- change-id: `{0}`' -f $CurrentChangeId))
    $lines.Add(('- Title: {0}' -f $ChangeTitle))
    $lines.Add(('- repo: `{0}`' -f $RepoMeta.id))
    $lines.Add(('- role: `{0}`' -f $RoleMeta.id))
    $lines.Add(('- runtime_type: `{0}`' -f $RoleMeta.runtime_type))
    $lines.Add(('- workflow: `{0}`' -f $RoleMeta.default_workflow))
    $lines.Add(('- branch: `{0}`' -f $ExecutionConfig.Branch[$RepoMeta.id]))
    $lines.Add(('- worktree: `{0}`' -f $ResolvedWorktree))
    $lines.Add(('- snapshot_policy: `{0}`' -f $SnapshotPolicy))
    if (-not [string]::IsNullOrWhiteSpace($SnapshotSource)) {
        $lines.Add(('- snapshot_source: `{0}`' -f $SnapshotSource))
    }
    $lines.Add(('- worker result: `{0}`' -f $WorkerResultRelative))
    $lines.Add(('- review result: `{0}`' -f $ReviewResultRelative))
    $lines.Add('')
    $lines.Add('## Execution boundaries')
    $lines.Add('')
    $lines.Add('- Execute only in the current worktree.')
    $lines.Add('- For actual code-editing tasks, use an isolated, clean worktree. Do not execute directly in a dirty main-repository working tree.')
    $lines.Add('- If `source_dirty_tracked` is enabled, this worktree already contains the tracked dirty snapshot from the source repository.')
    $lines.Add('- Modify only the following write scope: ')
    foreach ($pathPattern in $AllowedPaths) {
        $lines.Add(('  - `{0}`' -f $pathPattern))
    }
    if ($AllowedPaths.Count -eq 0) {
        $lines.Add('  - `[]`')
    }
    if ($SnapshotTrackedFiles.Count -gt 0) {
        $lines.Add('- Source tracked dirty files synchronized into this worktree: ')
        foreach ($snapshotFile in $SnapshotTrackedFiles) {
            $lines.Add(('  - `{0}`' -f $snapshotFile))
        }
    }
    if ($SnapshotActions.Count -gt 0) {
        $lines.Add('- Snapshot actions for this run: ')
        foreach ($snapshotAction in $SnapshotActions) {
            $lines.Add(('  - `{0}`' -f $snapshotAction))
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($SnapshotBlockedReason)) {
        $lines.Add(('- snapshot blocked reason: {0}' -f $SnapshotBlockedReason))
    }
    $lines.Add('- Do not directly rewrite `verification/result.md`.')
    $lines.Add('- Run repository verification commands after implementation and return the results in the worker result.')
    $lines.Add('')
    $lines.Add('## Default skills')
    $lines.Add('')
    foreach ($skill in $roleSkills) {
        $lines.Add(('- `{0}`' -f $skill))
    }
    if ($roleSkills.Count -eq 0) {
        $lines.Add('- `None`')
    }
    $lines.Add('')
    $lines.Add('## Recommended verification commands')
    $lines.Add('')
    foreach ($command in $roleVerifyCommands) {
        $lines.Add(('- `{0}`' -f $command))
    }
    foreach ($command in $safeCheckCommands) {
        if ($command -notin $roleVerifyCommands) {
            $lines.Add(('- `{0}`' -f $command))
        }
    }
    $lines.Add('')
    $lines.Add('## Context snapshots')
    $lines.Add('')
    $taskHeading = 'tasks/{0}.md' -f $RepoMeta.id

    Add-ContentSection -Lines $lines -Heading 'brief.md' -Body $BriefContent
    Add-ContentSection -Lines $lines -Heading 'impact.yaml' -Body $ImpactContent
    Add-ContentSection -Lines $lines -Heading 'execution.yaml' -Body $ExecutionContent
    Add-ContentSection -Lines $lines -Heading $taskHeading -Body $TaskContent

    if (-not [string]::IsNullOrWhiteSpace($RuleContent)) {
        Add-ContentSection -Lines $lines -Heading 'repo rule' -Body $RuleContent
    }

    if (-not [string]::IsNullOrWhiteSpace($BaselineSummary)) {
        $baselineHeading = '### Latest baseline summary ({0})' -f $BaselineSummaryPath
        $lines.Add($baselineHeading)
        $lines.Add('')
        $codeFence = '```'
        $lines.Add(('{0}text' -f $codeFence))
        foreach ($line in (($BaselineSummary -replace "`r", '') -split "`n")) {
            $lines.Add($line)
        }
        $lines.Add($codeFence)
        $lines.Add('')
    }

    if (-not [string]::IsNullOrWhiteSpace($LatestReviewContent)) {
        Add-ContentSection -Lines $lines -Heading $LatestReviewHeading -Body $LatestReviewContent
    }

    if (-not [string]::IsNullOrWhiteSpace($LatestReviewJsonContent)) {
        Add-ContentSection -Lines $lines -Heading $LatestReviewJsonHeading -Body $LatestReviewJsonContent
    }

    $lines.Add('## Worker execution requirements')
    $lines.Add('')
    $lines.Add('1. Read all context snapshots before deciding whether to proceed.')
    $lines.Add('2. Modify code, tests, configuration, or SQL scripts only within permitted paths.')
    $lines.Add('3. Run minimum verification commands after making changes.')
    $lines.Add('4. The outer wrapper writes results to `verification/workers/<repo>.md`. Return only structured results in the final message.')
    $lines.Add('5. If task-card information or write scope is insufficient, or verification failures cannot be resolved, return a blocked result. Do not change files outside the scope.')
    if ((-not [string]::IsNullOrWhiteSpace($LatestReviewContent)) -or (-not [string]::IsNullOrWhiteSpace($LatestReviewJsonContent))) {
        $lines.Add('6. If the packet includes recent review results with unresolved findings inside the write scope, those findings must be fixed in this run.')
        $lines.Add('7. Do not return `no_changes` merely because target files already contain uncommitted edits. Determine whether the current file content resolves the review findings.')
    }

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Export-HarnessTrackedDirtyPatch {
    param(
        [string]$SourceRepoPath,
        [string]$PatchPath
    )

    $parent = Split-Path -Parent $PatchPath
    if ($parent) {
        Ensure-HarnessDirectory -Path $parent | Out-Null
    }

    $result = Invoke-HarnessCommand -Command 'git diff --binary --no-ext-diff 2>nul' -WorkingDirectory $SourceRepoPath
    if ($result.ExitCode -ne 0) {
        throw "Failed to export the tracked dirty patch: $($result.Output)"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($PatchPath, $result.Output, $utf8NoBom)
    return $PatchPath
}

function Apply-HarnessTrackedDirtyPatch {
    param(
        [string]$TargetRepoPath,
        [string]$PatchPath
    )

    $lastOutput = ''
    foreach ($attempt in 1..5) {
        $result = Invoke-HarnessCommand -Command ('git apply --whitespace=nowarn "{0}" 2>nul' -f $PatchPath) -WorkingDirectory $TargetRepoPath
        $lastOutput = $result.Output
        if ($result.ExitCode -eq 0) {
            return 'applied-tracked-dirty-patch'
        }

        if ($attempt -lt 5) {
            Start-Sleep -Milliseconds (200 * $attempt)
        }
    }

    throw "Failed to apply the tracked dirty patch: $lastOutput"
}

function Sync-HarnessTrackedDirtySnapshot {
    param(
        [string]$SourceRepoPath,
        [string]$TargetRepoPath,
        [object[]]$Entries
    )

    $actions = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($Entries)) {
        $status = [string]$entry.status
        $relativePath = [string]$entry.path

        switch ($status) {
            'M' {
                $sourcePath = Convert-ToHarnessAbsolutePath -BasePath $SourceRepoPath -RelativePath $relativePath
                $targetPath = Convert-ToHarnessAbsolutePath -BasePath $TargetRepoPath -RelativePath $relativePath
                $targetParent = Split-Path -Parent $targetPath
                if ($targetParent) {
                    Ensure-HarnessDirectory -Path $targetParent | Out-Null
                }
                Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
                $actions.Add(("synced-modified:{0}" -f $relativePath))
            }
            'D' {
                $targetPath = Convert-ToHarnessAbsolutePath -BasePath $TargetRepoPath -RelativePath $relativePath
                if (Test-Path -LiteralPath $targetPath) {
                    Remove-Item -LiteralPath $targetPath -Force
                }
                $actions.Add(("synced-deleted:{0}" -f $relativePath))
            }
            default {
                throw "source_dirty_tracked does not currently support status `$status`: $relativePath"
            }
        }
    }

    return @($actions.ToArray())
}

function Ensure-RepositoryWorktree {
    param(
        [pscustomobject]$RepoMeta,
        [string]$TargetPath,
        [string]$BranchName
    )

    if (Test-Path -LiteralPath $TargetPath) {
        return 'reused'
    }

    $parent = Split-Path -Parent $TargetPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $existingBranch = Invoke-HarnessCommand -Command ("git branch --list {0}" -f $BranchName) -WorkingDirectory $RepoMeta.local_path
    if ([string]::IsNullOrWhiteSpace($existingBranch.Output)) {
        $command = ('git worktree add "{0}" -b "{1}" {2}' -f $TargetPath, $BranchName, $RepoMeta.default_branch)
    } else {
        $command = ('git worktree add "{0}" "{1}"' -f $TargetPath, $BranchName)
    }

    $result = Invoke-HarnessCommand -Command $command -WorkingDirectory $RepoMeta.local_path
    if ($result.ExitCode -ne 0) {
        throw "Failed to create worktree: $($RepoMeta.id) -> $($result.Output)"
    }

    return 'created'
}

function Ensure-RepositoryWorktreeDependencies {
    param(
        [pscustomobject]$RepoMeta,
        [string]$TargetPath
    )

    $sourceRepoPath = Unquote-HarnessScalar ([string]$RepoMeta.local_path)
    $sourceNodeModules = Join-Path $sourceRepoPath 'node_modules'
    $targetNodeModules = Join-Path $TargetPath 'node_modules'

    if (-not (Test-Path -LiteralPath $sourceNodeModules)) {
        return @()
    }

    if (Test-Path -LiteralPath $targetNodeModules) {
        return @()
    }

    New-Item -ItemType Junction -Path $targetNodeModules -Target $sourceNodeModules -Force | Out-Null
    return @('linked-node_modules')
}

$repoRoot = Get-HarnessRepoRoot
$changeDir = Join-Path $repoRoot ("changes\" + $ChangeId)
$executionPath = Join-Path $changeDir 'execution.yaml'
$validateChangeScript = Join-Path $repoRoot 'scripts\checks\validate-change.ps1'

& $validateChangeScript -ChangeId $ChangeId

$execution = Parse-HarnessExecutionConfig -YamlPath $executionPath
$registryMap = Get-HarnessAgentRegistryMap
$repos = Get-HarnessRepoConfig
$repoMap = @{}
foreach ($repo in $repos) {
    $repoMap[[string]$repo.id] = $repo
}

$targetRepoIds = @()
if (($null -ne $RepoIds) -and ($RepoIds.Count -gt 0)) {
    $targetRepoIds = @($RepoIds)
} else {
    $targetRepoIds = @($execution.RepoOwners.Keys | Where-Object { $_ -ne 'control_repo' })
}

$runtimeDir = Join-Path $changeDir 'runtime'
$packetDir = Join-Path $runtimeDir 'packets'
$reviewDir = Join-Path $runtimeDir 'reviews'
$workerResultDir = Join-Path $changeDir 'verification\workers'
$snapshotDir = Join-Path $runtimeDir 'snapshots'

Ensure-HarnessDirectory -Path $runtimeDir | Out-Null
Ensure-HarnessDirectory -Path $packetDir | Out-Null
Ensure-HarnessDirectory -Path $reviewDir | Out-Null
Ensure-HarnessDirectory -Path $workerResultDir | Out-Null
Ensure-HarnessDirectory -Path $snapshotDir | Out-Null

$briefContent = Read-HarnessTextOrEmpty -Path (Join-Path $changeDir 'brief.md')
$impactContent = Read-HarnessTextOrEmpty -Path (Join-Path $changeDir 'impact.yaml')
$executionContent = Read-HarnessTextOrEmpty -Path $executionPath
$baselineSummaryFile = Get-LatestBaselineSummary -RepoRoot $repoRoot
$baselineSummary = if ($null -ne $baselineSummaryFile) { Read-HarnessTextOrEmpty -Path $baselineSummaryFile.FullName } else { '' }
$baselineSummaryPath = if ($null -ne $baselineSummaryFile) { $baselineSummaryFile.FullName } else { '' }

$dispatchItems = @()
$effectiveEnsureWorktrees = [bool]($EnsureWorktrees -or $ExecuteWorkers)

foreach ($repoId in $targetRepoIds) {
    if (-not $execution.RepoOwners.ContainsKey($repoId)) {
        throw "repo_owner is not registered in execution.yaml: $repoId"
    }

    if (-not $repoMap.ContainsKey($repoId)) {
        throw "Repository is not registered in repos.yaml: $repoId"
    }

    $repoMeta = $repoMap[$repoId]
    $roleId = if ($execution.RegistryRef.ContainsKey($repoId) -and -not [string]::IsNullOrWhiteSpace($execution.RegistryRef[$repoId])) { $execution.RegistryRef[$repoId] } else { $execution.RepoOwners[$repoId] }
    if (-not $registryMap.ContainsKey($roleId)) {
        throw "Role not found in agent-registry: $roleId"
    }

    $roleMeta = $registryMap[$roleId]
    $configuredWorktree = $execution.Worktree[$repoId]
    $resolvedWorktree = Resolve-DispatchWorktreePath -RepoRoot $repoRoot -CurrentChangeId $ChangeId -RepoMeta $repoMeta -ConfiguredWorktree $configuredWorktree -RequireIsolatedWorktree $effectiveEnsureWorktrees
    $branchName = if ([string]::IsNullOrWhiteSpace($execution.Branch[$repoId])) { "codex/$ChangeId-$repoId" } else { $execution.Branch[$repoId] }
    $workerResultRelative = if ([string]::IsNullOrWhiteSpace($execution.WorkerResult[$repoId])) { "verification/workers/$repoId.md" } else { $execution.WorkerResult[$repoId] }
    $reviewResultRelative = if ([string]::IsNullOrWhiteSpace($execution.ReviewResult[$repoId])) { "runtime/reviews/$repoId-review.md" } else { $execution.ReviewResult[$repoId] }
    $allowedPaths = @()
    if ($execution.WriteScopesBusiness.ContainsKey($repoId) -and ($execution.WriteScopesBusiness[$repoId].Count -gt 0)) {
        $allowedPaths = @($execution.WriteScopesBusiness[$repoId])
    } else {
        $allowedPaths = Get-ArrayOrEmpty -Value $roleMeta.allowed_paths
    }
    $snapshotPolicy = Get-DispatchSnapshotPolicy -ExecutionConfig $execution -RepoId $repoId
    $snapshotSource = ''
    $snapshotTrackedFiles = @()
    $snapshotActions = @()
    $snapshotBlockedReason = ''

    $taskPath = Join-Path $changeDir ("tasks\{0}.md" -f $repoId)
    $taskContent = Read-HarnessTextOrEmpty -Path $taskPath
    $rulePath = Get-RepoRulePath -RepoRoot $repoRoot -RepoId $repoId
    $ruleContent = if ($rulePath) { Read-HarnessTextOrEmpty -Path $rulePath } else { '' }
    $reviewMarkdownPath = Resolve-ExistingRelativeFile -BasePath $changeDir -Candidates @(
        $execution.ReviewResult[$repoId],
        ("runtime/reviews/{0}-review.md" -f $repoId)
    )
    $reviewJsonPath = Resolve-ExistingRelativeFile -BasePath $changeDir -Candidates @(
        ("runtime/review-results/{0}.json" -f $repoId)
    )
    $latestReviewContent = if ($null -ne $reviewMarkdownPath) { Read-HarnessTextOrEmpty -Path $reviewMarkdownPath } else { '' }
    $latestReviewHeading = if ($null -ne $reviewMarkdownPath) { "Latest review result ($reviewMarkdownPath)" } else { '' }
    $latestReviewJsonContent = if ($null -ne $reviewJsonPath) { Read-HarnessTextOrEmpty -Path $reviewJsonPath } else { '' }
    $latestReviewJsonHeading = if ($null -ne $reviewJsonPath) { "Latest review JSON ($reviewJsonPath)" } else { '' }

    $packetPath = Join-Path $packetDir ("{0}-worker.md" -f $repoId)
    $packetContent = New-WorkerPacketContent -CurrentChangeId $ChangeId -ChangeTitle $execution.Title -RepoMeta $repoMeta -RoleMeta $roleMeta -ExecutionConfig $execution -ResolvedWorktree $resolvedWorktree -SnapshotPolicy $snapshotPolicy -SnapshotSource $snapshotSource -SnapshotTrackedFiles @($snapshotTrackedFiles) -SnapshotActions @($snapshotActions) -SnapshotBlockedReason $snapshotBlockedReason -WorkerResultRelative $workerResultRelative -ReviewResultRelative $reviewResultRelative -AllowedPaths $allowedPaths -BriefContent $briefContent -ImpactContent $impactContent -ExecutionContent $executionContent -TaskContent $taskContent -RuleContent $ruleContent -BaselineSummary $baselineSummary -BaselineSummaryPath $baselineSummaryPath -LatestReviewContent $latestReviewContent -LatestReviewHeading $latestReviewHeading -LatestReviewJsonContent $latestReviewJsonContent -LatestReviewJsonHeading $latestReviewJsonHeading

    $worktreeStatus = 'planned'
    $bootstrapActions = @()
    if ($effectiveEnsureWorktrees -and -not $DryRun) {
        $worktreeStatus = Ensure-RepositoryWorktree -RepoMeta $repoMeta -TargetPath $resolvedWorktree -BranchName $branchName
        $bootstrapActions = @(Ensure-RepositoryWorktreeDependencies -RepoMeta $repoMeta -TargetPath $resolvedWorktree)
    } elseif (Test-Path -LiteralPath $resolvedWorktree) {
        $worktreeStatus = 'reused'
        $bootstrapActions = @(Ensure-RepositoryWorktreeDependencies -RepoMeta $repoMeta -TargetPath $resolvedWorktree)
    }

    if (($snapshotPolicy -eq 'source_dirty_tracked') -and -not $DryRun) {
        $sourceRepoPath = Unquote-HarnessScalar ([string]$repoMeta.local_path)
        $snapshotSource = $sourceRepoPath
        $allSnapshotEntries = @(Get-HarnessTrackedDirtyEntries -RepoPath $sourceRepoPath)
        $snapshotEntries = if ($allowedPaths.Count -gt 0) {
            @(Get-HarnessEntriesMatchingAllowedPaths -Entries $allSnapshotEntries -AllowedPaths $allowedPaths)
        } else {
            @()
        }
        $snapshotTrackedFiles = @(
            @($snapshotEntries | ForEach-Object { [string]$_.path }) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $ignoredOutOfScopeTrackedFiles = @(
            @($allSnapshotEntries | ForEach-Object { [string]$_.path }) |
                Where-Object {
                    (-not [string]::IsNullOrWhiteSpace($_)) -and
                    (-not (Test-HarnessDispatchPathMatchesAllowed -Candidate $_ -AllowedPaths $allowedPaths))
                } |
                Select-Object -Unique
        )
        $sourceUntrackedFiles = @(Get-HarnessUntrackedFiles -RepoPath $sourceRepoPath)
        $matchingUntrackedFiles = @(Get-HarnessFilesMatchingAllowedPaths -Files $sourceUntrackedFiles -AllowedPaths $allowedPaths)
        $sourceHeadCommit = Get-HarnessHeadCommit -RepoPath $sourceRepoPath
        $targetHeadCommit = if (Test-Path -LiteralPath $resolvedWorktree) { Get-HarnessHeadCommit -RepoPath $resolvedWorktree } else { '' }

        if ($matchingUntrackedFiles.Count -gt 0) {
            $snapshotBlockedReason = "The source repository contains untracked files within the write scope: $($matchingUntrackedFiles -join ', ')"
            $snapshotActions += 'blocked-untracked-in-scope'
        } elseif (-not (Test-HarnessDispatchWorktreeClean -RepoPath $resolvedWorktree)) {
            $snapshotBlockedReason = "The target worktree has uncommitted changes: $resolvedWorktree"
            $snapshotActions += 'blocked-target-worktree-dirty'
        } elseif (
            (-not [string]::IsNullOrWhiteSpace($sourceHeadCommit)) -and
            (-not [string]::IsNullOrWhiteSpace($targetHeadCommit)) -and
            ($sourceHeadCommit -ne $targetHeadCommit)
        ) {
            $snapshotBlockedReason = "Source repository and target worktree HEADs differ: $sourceHeadCommit != $targetHeadCommit"
            $snapshotActions += 'blocked-anchor-mismatch'
        } elseif ($snapshotTrackedFiles.Count -gt 0) {
            try {
                $snapshotActions += @(Sync-HarnessTrackedDirtySnapshot -SourceRepoPath $sourceRepoPath -TargetRepoPath $resolvedWorktree -Entries $snapshotEntries)
                if ($ignoredOutOfScopeTrackedFiles.Count -gt 0) {
                    $snapshotActions += ("ignored-out-of-scope-tracked:{0}" -f $ignoredOutOfScopeTrackedFiles.Count)
                }
                $snapshotActions += 'captured-source-dirty-tracked'
            } catch {
                $snapshotBlockedReason = $_.Exception.Message
                $snapshotActions += 'blocked-snapshot-sync-failed'
            }
        } else {
            if ($ignoredOutOfScopeTrackedFiles.Count -gt 0) {
                $snapshotActions += ("source-dirty-none-in-scope:{0}" -f $ignoredOutOfScopeTrackedFiles.Count)
            } else {
                $snapshotActions += 'source-dirty-none'
            }
        }
    }

    if (-not $DryRun) {
        $packetContent = New-WorkerPacketContent -CurrentChangeId $ChangeId -ChangeTitle $execution.Title -RepoMeta $repoMeta -RoleMeta $roleMeta -ExecutionConfig $execution -ResolvedWorktree $resolvedWorktree -SnapshotPolicy $snapshotPolicy -SnapshotSource $snapshotSource -SnapshotTrackedFiles @($snapshotTrackedFiles) -SnapshotActions @($snapshotActions) -SnapshotBlockedReason $snapshotBlockedReason -WorkerResultRelative $workerResultRelative -ReviewResultRelative $reviewResultRelative -AllowedPaths $allowedPaths -BriefContent $briefContent -ImpactContent $impactContent -ExecutionContent $executionContent -TaskContent $taskContent -RuleContent $ruleContent -BaselineSummary $baselineSummary -BaselineSummaryPath $baselineSummaryPath -LatestReviewContent $latestReviewContent -LatestReviewHeading $latestReviewHeading -LatestReviewJsonContent $latestReviewJsonContent -LatestReviewJsonHeading $latestReviewJsonHeading
        Write-HarnessTextFile -Path $packetPath -Content $packetContent
        $workerResultPath = Convert-ToHarnessAbsolutePath -BasePath $changeDir -RelativePath $workerResultRelative
        if (-not (Test-Path -LiteralPath $workerResultPath)) {
            Write-HarnessTextFile -Path $workerResultPath -Content ("# {0} / {1}`r`n`r`n- Current status: Pending execution`r`n" -f $ChangeId, $repoId)
        }
    }

    $dispatchItems += [pscustomobject]@{
        repo_id = $repoId
        role_id = $roleId
        runtime_type = $roleMeta.runtime_type
        branch = $branchName
        worktree = $resolvedWorktree
        worktree_status = $worktreeStatus
        snapshot_policy = $snapshotPolicy
        snapshot_source = $snapshotSource
        snapshot_tracked_files = @($snapshotTrackedFiles)
        snapshot_actions = @($snapshotActions)
        blocked_reason = $snapshotBlockedReason
        bootstrap_actions = @($bootstrapActions)
        packet_path = $packetPath
        worker_result = $workerResultRelative
        review_result = $reviewResultRelative
        allowed_paths = @($allowedPaths)
    }
}

$dispatchState = [pscustomobject]@{
    change_id = $ChangeId
    stage = $execution.Stage
    stage_owner = $execution.StageOwner
    generated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    dry_run = [bool]$DryRun
    ensure_worktrees = [bool]$effectiveEnsureWorktrees
    repos = $dispatchItems
}

$dispatchStatePath = Join-Path $runtimeDir 'dispatch-state.json'
if (-not $DryRun) {
    Write-HarnessJsonFile -Path $dispatchStatePath -Data $dispatchState
}

Write-Host "Worker dispatch prepared: $ChangeId" -ForegroundColor Green
foreach ($item in $dispatchItems) {
    Write-Host ("  - {0}: {1} / {2}" -f $item.repo_id, $item.role_id, $item.worktree_status) -ForegroundColor Cyan
}
if (-not $DryRun) {
    Write-Host ("dispatch-state: {0}" -f $dispatchStatePath) -ForegroundColor Green
}

if ($ExecuteWorkers -and -not $DryRun) {
    $runRoleScript = Join-Path $repoRoot 'scripts\orchestrator\run-role.ps1'
    foreach ($item in $dispatchItems) {
        if (-not [string]::IsNullOrWhiteSpace([string]$item.blocked_reason)) {
            throw "Worker dispatch blocked: $($item.repo_id) -> $($item.blocked_reason)"
        }

        $invokeArgs = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $runRoleScript,
            '-ChangeId', $ChangeId,
            '-RepoId', $item.repo_id,
            '-SkipDispatch',
            '-Execute'
        )

        if ($effectiveEnsureWorktrees) {
            $invokeArgs += '-EnsureWorktrees'
        }
        if ($Ephemeral) {
            $invokeArgs += '-Ephemeral'
        }
        if ($NoCodeChanges) {
            $invokeArgs += '-NoCodeChanges'
        }
        if (-not [string]::IsNullOrWhiteSpace($Model)) {
            $invokeArgs += @('-Model', $Model)
        }

        & powershell @invokeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Worker execution failed: $($item.repo_id)"
        }
    }
}
