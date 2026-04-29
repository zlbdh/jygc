[CmdletBinding()]
param(
    [string]$ChangeId,
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

if ([string]::IsNullOrWhiteSpace($ChangeId) -and [string]::IsNullOrWhiteSpace($Path)) {
    throw "请传入 -ChangeId 或 -Path。"
}

$repoRoot = Get-HarnessRepoRoot

if (-not [string]::IsNullOrWhiteSpace($ChangeId)) {
    $targetDir = Join-Path $repoRoot ("changes\" + $ChangeId)
} else {
    $targetDir = (Resolve-Path -LiteralPath $Path).Path
}

if (-not (Test-Path -LiteralPath $targetDir)) {
    throw "未找到变更目录：$targetDir"
}

$requiredFiles = @(
    'brief.md',
    'impact.yaml',
    'execution.yaml',
    'design.md',
    'acceptance.md',
    'verification\result.md'
)

$errors = New-Object System.Collections.Generic.List[string]

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $targetDir $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $errors.Add("缺少文件：$relativePath")
        continue
    }

    $content = Get-Content -LiteralPath $fullPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        $errors.Add("文件为空：$relativePath")
    }
}

$executionPath = Join-Path $targetDir 'execution.yaml'
if (Test-Path -LiteralPath $executionPath) {
    $executionContent = Get-Content -LiteralPath $executionPath -Raw
    $execution = Parse-HarnessExecutionConfig -YamlPath $executionPath
    $requiredExecutionKeys = @(
        'stage',
        'stage_owner',
        'repo_owners',
        'write_scopes',
        'depends_on',
        'branch',
        'worktree',
        'runtime_type',
        'registry_ref',
        'worker_result',
        'review_result',
        'lock_state',
        'snapshot_at'
    )

    foreach ($key in $requiredExecutionKeys) {
        if ($executionContent -notmatch ("(?m)^\s*{0}\s*:" -f [regex]::Escape($key))) {
            $errors.Add("execution.yaml 缺少字段：$key")
        }
    }

    if ([string]::IsNullOrWhiteSpace($execution.Stage)) {
        $errors.Add('execution.yaml 缺少有效字段：stage')
    }

    if ([string]::IsNullOrWhiteSpace($execution.StageOwner)) {
        $errors.Add('execution.yaml 缺少有效字段：stage_owner')
    }

    if (-not $execution.RuntimeType.ContainsKey('control_repo')) {
        $errors.Add('execution.yaml 缺少 runtime_type.control_repo')
    }

    if (-not $execution.RegistryRef.ContainsKey('control_repo')) {
        $errors.Add('execution.yaml 缺少 registry_ref.control_repo')
    }
}

$tasksDir = Join-Path $targetDir 'tasks'
if (-not (Test-Path -LiteralPath $tasksDir)) {
    $errors.Add('缺少目录：tasks')
} else {
    $taskFiles = @(Get-ChildItem -LiteralPath $tasksDir -Filter '*.md' -File -ErrorAction SilentlyContinue)
    if ($taskFiles.Count -eq 0) {
        $errors.Add('未发现任何任务卡：tasks/*.md')
    }
}

$impactPath = Join-Path $targetDir 'impact.yaml'
if (Test-Path -LiteralPath $impactPath) {
    $impactContent = Get-Content -LiteralPath $impactPath
    $impactRepoIds = @()

    foreach ($line in $impactContent) {
        if ($line -match '^\s*-\s+id:\s*([A-Za-z0-9_-]+)\s*$') {
            $impactRepoIds += $Matches[1]
        }
    }

    foreach ($repoId in ($impactRepoIds | Select-Object -Unique)) {
        $taskPath = Join-Path $targetDir ("tasks\" + $repoId + '.md')
        if (-not (Test-Path -LiteralPath $taskPath)) {
            $errors.Add("影响分析已声明仓库但缺少任务卡：tasks\$repoId.md")
            continue
        }

        $taskContent = Get-Content -LiteralPath $taskPath -Raw
        if ([string]::IsNullOrWhiteSpace($taskContent)) {
            $errors.Add("任务卡为空：tasks\$repoId.md")
        }

        if ((Test-Path -LiteralPath $executionPath) -and ($executionContent -notmatch ("(?m)^\s*{0}\s*:" -f [regex]::Escape($repoId)))) {
            $errors.Add("execution.yaml 未登记受影响仓：$repoId")
        }

        if (Test-Path -LiteralPath $executionPath) {
            if (-not $execution.RepoOwners.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 repo_owner：$repoId")
            }
            if (-not $execution.Branch.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 branch：$repoId")
            }
            if (-not $execution.Worktree.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 worktree：$repoId")
            }
            if (-not $execution.RuntimeType.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 runtime_type：$repoId")
            }
            if (-not $execution.RegistryRef.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 registry_ref：$repoId")
            }
            if ((-not $execution.WorkerResult.ContainsKey($repoId)) -or [string]::IsNullOrWhiteSpace($execution.WorkerResult[$repoId])) {
                $errors.Add("execution.yaml 缺少 worker_result：$repoId")
            }
            if ((-not $execution.ReviewResult.ContainsKey($repoId)) -or [string]::IsNullOrWhiteSpace($execution.ReviewResult[$repoId])) {
                $errors.Add("execution.yaml 缺少 review_result：$repoId")
            }
            if (-not $execution.WriteScopesBusiness.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 write_scope：$repoId")
            }
            if (-not $execution.LockStateBusiness.ContainsKey($repoId)) {
                $errors.Add("execution.yaml 缺少 lock_state：$repoId")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "变更单校验失败：" -ForegroundColor Red
    foreach ($errorItem in $errors) {
        Write-Host "  - $errorItem" -ForegroundColor Red
    }
    throw "变更单结构校验未通过。"
}

Write-Host "变更单结构校验通过：$targetDir" -ForegroundColor Green
