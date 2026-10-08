[CmdletBinding()]
param(
    [string]$ChangeId,
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

if ([string]::IsNullOrWhiteSpace($ChangeId) -and [string]::IsNullOrWhiteSpace($Path)) {
    throw "Provide -ChangeId or -Path."
}

$repoRoot = Get-HarnessRepoRoot

if (-not [string]::IsNullOrWhiteSpace($ChangeId)) {
    $targetDir = Join-Path $repoRoot ("changes\" + $ChangeId)
} else {
    $targetDir = (Resolve-Path -LiteralPath $Path).Path
}

if (-not (Test-Path -LiteralPath $targetDir)) {
    throw "Change directory not found: $targetDir"
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
        $errors.Add("Missing file: $relativePath")
        continue
    }

    $content = Get-Content -LiteralPath $fullPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        $errors.Add("Empty file: $relativePath")
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
            $errors.Add("execution.yaml is missing field: $key")
        }
    }

    if ([string]::IsNullOrWhiteSpace($execution.Stage)) {
        $errors.Add('execution.yaml is missing a valid field: stage')
    }

    if ([string]::IsNullOrWhiteSpace($execution.StageOwner)) {
        $errors.Add('execution.yaml is missing a valid field: stage_owner')
    }

    if (-not $execution.RuntimeType.ContainsKey('control_repo')) {
        $errors.Add('execution.yaml is missing runtime_type.control_repo')
    }

    if (-not $execution.RegistryRef.ContainsKey('control_repo')) {
        $errors.Add('execution.yaml is missing registry_ref.control_repo')
    }
}

$tasksDir = Join-Path $targetDir 'tasks'
if (-not (Test-Path -LiteralPath $tasksDir)) {
    $errors.Add('Missing directory: tasks')
} else {
    $taskFiles = @(Get-ChildItem -LiteralPath $tasksDir -Filter '*.md' -File -ErrorAction SilentlyContinue)
    if ($taskFiles.Count -eq 0) {
        $errors.Add('No task cards found: tasks/*.md')
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
            $errors.Add("A repository is listed in the impact analysis but its task card is missing: tasks\$repoId.md")
            continue
        }

        $taskContent = Get-Content -LiteralPath $taskPath -Raw
        if ([string]::IsNullOrWhiteSpace($taskContent)) {
            $errors.Add("Task card is empty: tasks\$repoId.md")
        }

        if ((Test-Path -LiteralPath $executionPath) -and ($executionContent -notmatch ("(?m)^\s*{0}\s*:" -f [regex]::Escape($repoId)))) {
            $errors.Add("Affected repository is not registered in execution.yaml: $repoId")
        }

        if (Test-Path -LiteralPath $executionPath) {
            if (-not $execution.RepoOwners.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing repo_owner: $repoId")
            }
            if (-not $execution.Branch.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing branch: $repoId")
            }
            if (-not $execution.Worktree.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing worktree: $repoId")
            }
            if (-not $execution.RuntimeType.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing runtime_type: $repoId")
            }
            if (-not $execution.RegistryRef.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing registry_ref: $repoId")
            }
            if ((-not $execution.WorkerResult.ContainsKey($repoId)) -or [string]::IsNullOrWhiteSpace($execution.WorkerResult[$repoId])) {
                $errors.Add("execution.yaml is missing worker_result: $repoId")
            }
            if ((-not $execution.ReviewResult.ContainsKey($repoId)) -or [string]::IsNullOrWhiteSpace($execution.ReviewResult[$repoId])) {
                $errors.Add("execution.yaml is missing review_result: $repoId")
            }
            if (-not $execution.WriteScopesBusiness.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing write_scope: $repoId")
            }
            if (-not $execution.LockStateBusiness.ContainsKey($repoId)) {
                $errors.Add("execution.yaml is missing lock_state: $repoId")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Change record validation failed: " -ForegroundColor Red
    foreach ($errorItem in $errors) {
        Write-Host "  - $errorItem" -ForegroundColor Red
    }
    throw "Change record structure validation failed."
}

Write-Host "Change record structure validation passed: $targetDir" -ForegroundColor Green
