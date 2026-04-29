[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ChangeId,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

function Render-Template {
    param(
        [string]$TemplatePath,
        [hashtable]$Tokens
    )

    $content = Get-Content -LiteralPath $TemplatePath -Raw
    foreach ($key in $Tokens.Keys) {
        $content = $content.Replace($key, [string]$Tokens[$key])
    }
    return $content
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content,
        [switch]$AllowOverwrite
    )

    if ((Test-Path -LiteralPath $Path) -and -not $AllowOverwrite) {
        throw "文件已存在：$Path。若要覆盖，请使用 -Force。"
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function New-ImpactContent {
    param(
        [string]$CurrentChangeId,
        [string]$CurrentTitle,
        [object[]]$RepoEntries
    )

    $lines = @(
        ('change_id: "{0}"' -f $CurrentChangeId),
        ('title: "{0}"' -f $CurrentTitle),
        'is_cross_repo: true',
        'affected_repos:'
    )

    foreach ($repo in $RepoEntries) {
        $lines += "  - id: $($repo.id)"
        $lines += '    modules: []'
    }

    $lines += @(
        'affected_interfaces: []',
        'affected_tables: []',
        'affected_configs: []',
        'dependency_order:'
    )

    foreach ($repo in $RepoEntries) {
        $lines += "  - $($repo.id)"
    }

    $lines += @(
        'notes:',
        '  - ""'
    )

    return ($lines -join [Environment]::NewLine)
}

function Get-DefaultAgentOwner {
    param([object]$RepoEntry)

    switch ([string]$RepoEntry.id) {
        'backend' { return 'backend-exec-agent' }
        'web-portal' { return 'web-exec-agent' }
        'admin-web' { return 'admin-web-exec-agent' }
        'mobile-a' { return 'mobile-a-exec-agent' }
        'mobile-b' { return 'mobile-b-exec-agent' }
        'mobile-c' { return 'mobile-c-planning-agent' }
        'miniapp' { return 'miniapp-planning-agent' }
        default { return 'unassigned-agent' }
    }
}

function Get-DefaultRuntimeType {
    param([object]$RepoEntry)

    switch ([string]$RepoEntry.id) {
        'mobile-c' { return 'worker' }
        'miniapp' { return 'worker' }
        default { return 'worker' }
    }
}

function Get-DefaultSnapshotPolicy {
    param([object]$RepoEntry)

    switch ([string]$RepoEntry.id) {
        default { return 'source_dirty_tracked' }
    }
}

function New-ExecutionContent {
    param(
        [string]$CurrentChangeId,
        [string]$CurrentTitle,
        [object[]]$RepoEntries,
        [string]$TemplatePath
    )

    $repoOwnerLines = New-Object System.Collections.Generic.List[string]
    $writeScopeLines = New-Object System.Collections.Generic.List[string]
    $branchLines = New-Object System.Collections.Generic.List[string]
    $worktreeLines = New-Object System.Collections.Generic.List[string]
    $snapshotPolicyLines = New-Object System.Collections.Generic.List[string]
    $runtimeTypeLines = New-Object System.Collections.Generic.List[string]
    $registryRefLines = New-Object System.Collections.Generic.List[string]
    $workerResultLines = New-Object System.Collections.Generic.List[string]
    $reviewResultLines = New-Object System.Collections.Generic.List[string]
    $lockStateLines = New-Object System.Collections.Generic.List[string]

    foreach ($repo in $RepoEntries) {
        $owner = Get-DefaultAgentOwner -RepoEntry $repo
        $repoId = [string]$repo.id
        $repoOwnerLines.Add(("  {0}: {1}" -f $repo.id, $owner))
        $writeScopeLines.Add(("    {0}: []" -f $repo.id))
        $branchLines.Add(('  {0}: "codex/{1}-{0}"' -f $repo.id, $CurrentChangeId))
        $worktreeLines.Add(('  {0}: "{1}"' -f $repo.id, ("D:\workspace\agent-harness\worktrees\" + $CurrentChangeId + "\" + $repoId)))
        $snapshotPolicyLines.Add(('  {0}: {1}' -f $repo.id, (Get-DefaultSnapshotPolicy -RepoEntry $repo)))
        $runtimeTypeLines.Add(('  {0}: {1}' -f $repo.id, (Get-DefaultRuntimeType -RepoEntry $repo)))
        $registryRefLines.Add(('  {0}: {1}' -f $repo.id, $owner))
        $workerResultLines.Add(('  {0}: "verification/workers/{1}.md"' -f $repo.id, $repoId))
        $reviewResultLines.Add(('  {0}: "runtime/reviews/{1}-review.md"' -f $repo.id, $repoId))
        $lockStateLines.Add(("    {0}: unlocked" -f $repo.id))
    }

    $tokens = @{
        '{{CHANGE_ID}}' = $CurrentChangeId
        '{{TITLE}}' = $CurrentTitle
        '{{REPO_OWNERS}}' = ($repoOwnerLines -join [Environment]::NewLine)
        '{{WRITE_SCOPES}}' = ($writeScopeLines -join [Environment]::NewLine)
        '{{BRANCHES}}' = ($branchLines -join [Environment]::NewLine)
        '{{WORKTREES}}' = ($worktreeLines -join [Environment]::NewLine)
        '{{SNAPSHOT_POLICIES}}' = ("  control_repo: none{0}{1}" -f [Environment]::NewLine, ($snapshotPolicyLines -join [Environment]::NewLine))
        '{{RUNTIME_TYPES}}' = ("  control_repo: main-agent{0}{1}" -f [Environment]::NewLine, ($runtimeTypeLines -join [Environment]::NewLine))
        '{{REGISTRY_REFS}}' = ("  control_repo: change-intake-agent{0}{1}" -f [Environment]::NewLine, ($registryRefLines -join [Environment]::NewLine))
        '{{WORKER_RESULTS}}' = ("  control_repo: """"{0}{1}" -f [Environment]::NewLine, ($workerResultLines -join [Environment]::NewLine))
        '{{REVIEW_RESULTS}}' = ("  control_repo: """"{0}{1}" -f [Environment]::NewLine, ($reviewResultLines -join [Environment]::NewLine))
        '{{LOCK_STATES}}' = ($lockStateLines -join [Environment]::NewLine)
    }

    return Render-Template -TemplatePath $TemplatePath -Tokens $tokens
}

if ($ChangeId -notmatch '^CHG-\d{4}-\d{4}-[a-z0-9-]+$') {
    throw "ChangeId 格式不合法：$ChangeId。要求格式为 CHG-YYYY-NNNN-slug。"
}

$repoRoot = Get-HarnessRepoRoot
$changeDir = Join-Path $repoRoot ("changes\" + $ChangeId)

if ((Test-Path -LiteralPath $changeDir) -and -not $Force) {
    throw "变更目录已存在：$changeDir。若要重建，请使用 -Force。"
}

$templateDir = Join-Path $repoRoot 'templates'
$repoConfigPath = Join-Path $repoRoot 'repos\repos.yaml'
$repos = Parse-HarnessRepoConfig -YamlPath $repoConfigPath

$baseTokens = @{
    '{{CHANGE_ID}}' = $ChangeId
    '{{TITLE}}' = $Title
}

New-Item -ItemType Directory -Path (Join-Path $changeDir 'tasks') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $changeDir 'verification') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $changeDir 'verification\workers') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $changeDir 'runtime\packets') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $changeDir 'runtime\reviews') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $changeDir 'runtime\worker-responses') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $changeDir 'runtime\review-results') -Force | Out-Null

Write-Utf8File -Path (Join-Path $changeDir 'brief.md') -Content (Render-Template -TemplatePath (Join-Path $templateDir 'change-brief.md') -Tokens $baseTokens) -AllowOverwrite:$Force
Write-Utf8File -Path (Join-Path $changeDir 'impact.yaml') -Content (New-ImpactContent -CurrentChangeId $ChangeId -CurrentTitle $Title -RepoEntries $repos) -AllowOverwrite:$Force
Write-Utf8File -Path (Join-Path $changeDir 'execution.yaml') -Content (New-ExecutionContent -CurrentChangeId $ChangeId -CurrentTitle $Title -RepoEntries $repos -TemplatePath (Join-Path $templateDir 'execution.yaml')) -AllowOverwrite:$Force
Write-Utf8File -Path (Join-Path $changeDir 'acceptance.md') -Content (Render-Template -TemplatePath (Join-Path $templateDir 'acceptance.md') -Tokens $baseTokens) -AllowOverwrite:$Force
Write-Utf8File -Path (Join-Path $changeDir 'design.md') -Content (Render-Template -TemplatePath (Join-Path $templateDir 'design.md') -Tokens $baseTokens) -AllowOverwrite:$Force

foreach ($repo in $repos) {
    $owner = Get-DefaultAgentOwner -RepoEntry $repo
    $taskTokens = @{
        '{{CHANGE_ID}}' = $ChangeId
        '{{REPO_ID}}' = [string]$repo.id
        '{{REPO_NAME}}' = [string]$repo.name
        '{{STACK}}' = [string]$repo.stack
        '{{DEFAULT_OWNER}}' = $owner
    }

    $taskContent = Render-Template -TemplatePath (Join-Path $templateDir 'task-card.md') -Tokens $taskTokens
    $taskContent += @"

## 建议命令

- 构建：$($repo.build_command)
- 测试：$($repo.test_command)
- Smoke：$($repo.smoke_command)
"@

    Write-Utf8File -Path (Join-Path $changeDir ("tasks\" + $repo.id + '.md')) -Content $taskContent -AllowOverwrite:$Force

    $workerTokens = @{
        '{{CHANGE_ID}}' = $ChangeId
        '{{TITLE}}' = $Title
        '{{REPO_ID}}' = [string]$repo.id
        '{{REPO_NAME}}' = [string]$repo.name
        '{{ROLE_ID}}' = $owner
        '{{RUNTIME_TYPE}}' = (Get-DefaultRuntimeType -RepoEntry $repo)
    }

    Write-Utf8File -Path (Join-Path $changeDir ("verification\workers\" + $repo.id + '.md')) -Content (Render-Template -TemplatePath (Join-Path $templateDir 'worker-result.md') -Tokens $workerTokens) -AllowOverwrite:$Force
}
Write-Utf8File -Path (Join-Path $changeDir 'verification\result.md') -Content (Render-Template -TemplatePath (Join-Path $templateDir 'verification-result.md') -Tokens $baseTokens) -AllowOverwrite:$Force
Write-Utf8File -Path (Join-Path $changeDir 'postmortem.md') -Content (Render-Template -TemplatePath (Join-Path $templateDir 'postmortem.md') -Tokens $baseTokens) -AllowOverwrite:$Force

Write-Host "已创建变更单：$changeDir"
Write-Host "已生成 repo 级任务卡数量：$($repos.Count)"
