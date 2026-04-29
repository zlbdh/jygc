[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

$repos = Get-HarnessRepoConfig

$requiredFields = @(
    'id',
    'name',
    'remote',
    'local_path',
    'default_branch',
    'stack',
    'role',
    'clone_mode',
    'validation_profile',
    'owner_scope',
    'bootstrap_command',
    'build_command',
    'test_command',
    'smoke_command',
    'safe_check_commands',
    'status',
    'notes'
)

$allowedStatuses = @('baseline-ready', 'missing-contract', 'missing-local-env')
$allowedCloneModes = @('git')
$allowedProfiles = @('backend-maven', 'web-vite', 'mobile-rn', 'miniapp')
$allowedRoles = @(
    'backend-service',
    'enterprise-web',
    'platform-web',
    'enterprise-mobile',
    'merchant-mobile',
    'staff-mobile',
    'consumer-miniapp'
)

$errors = New-Object System.Collections.Generic.List[string]
$seenIds = @{}
$seenPaths = @{}

if ($repos.Count -eq 0) {
    $errors.Add('repos.yaml 中没有任何仓库定义。')
}

foreach ($repo in $repos) {
    foreach ($field in $requiredFields) {
        $hasProperty = $repo.PSObject.Properties.Name -contains $field
        if (-not $hasProperty) {
            $errors.Add("仓库 $($repo.name) 缺少字段：$field")
            continue
        }

        $value = $repo.$field
        if ($field -eq 'safe_check_commands') {
            $arrayValue = @($value)
            if ($arrayValue.Count -eq 0) {
                $errors.Add("仓库 $($repo.name) 的 safe_check_commands 不能为空。")
            }
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$value)) {
            $errors.Add("仓库 $($repo.name) 的字段为空：$field")
        }
    }

    if ($seenIds.ContainsKey($repo.id)) {
        $errors.Add("存在重复的仓库 id：$($repo.id)")
    } else {
        $seenIds[$repo.id] = $true
    }

    if ($seenPaths.ContainsKey($repo.local_path)) {
        $errors.Add("存在重复的 local_path：$($repo.local_path)")
    } else {
        $seenPaths[$repo.local_path] = $true
    }

    if (-not ([string]$repo.remote).StartsWith('https://example.com/')) {
        $errors.Add("仓库 $($repo.id) 的 remote 不是示例 Git HTTPS 地址。")
    }

    if (-not ([string]$repo.local_path).StartsWith('D:\workspace\agent-harness\repos\')) {
        $errors.Add("仓库 $($repo.id) 的 local_path 未落在 D:\\workspace\\agent-harness\\repos\\ 下。")
    }

    if ($allowedStatuses -notcontains [string]$repo.status) {
        $errors.Add("仓库 $($repo.id) 的 status 不在允许范围：$($repo.status)")
    }

    if ($allowedCloneModes -notcontains [string]$repo.clone_mode) {
        $errors.Add("仓库 $($repo.id) 的 clone_mode 不在允许范围：$($repo.clone_mode)")
    }

    if ($allowedProfiles -notcontains [string]$repo.validation_profile) {
        $errors.Add("仓库 $($repo.id) 的 validation_profile 不在允许范围：$($repo.validation_profile)")
    }

    if ($allowedRoles -notcontains [string]$repo.role) {
        $errors.Add("仓库 $($repo.id) 的 role 不在允许范围：$($repo.role)")
    }
}

if ($errors.Count -gt 0) {
    Write-Host "仓库元数据校验失败：" -ForegroundColor Red
    foreach ($errorItem in $errors) {
        Write-Host "  - $errorItem" -ForegroundColor Red
    }
    throw "repos.yaml 校验未通过。"
}

Write-Host "repos.yaml 校验通过。" -ForegroundColor Green
$repos | Select-Object id, role, validation_profile, stack, default_branch, status | Format-Table -AutoSize
