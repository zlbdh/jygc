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
    $errors.Add('No repositories are defined in repos.yaml.')
}

foreach ($repo in $repos) {
    foreach ($field in $requiredFields) {
        $hasProperty = $repo.PSObject.Properties.Name -contains $field
        if (-not $hasProperty) {
            $errors.Add("Repository $($repo.name) is missing field: $field")
            continue
        }

        $value = $repo.$field
        if ($field -eq 'safe_check_commands') {
            $arrayValue = @($value)
            if ($arrayValue.Count -eq 0) {
                $errors.Add("Repository $($repo.name) must have nonempty safe_check_commands.")
            }
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$value)) {
            $errors.Add("Repository $($repo.name) has an empty field: $field")
        }
    }

    if ($seenIds.ContainsKey($repo.id)) {
        $errors.Add("Duplicate repository ID: $($repo.id)")
    } else {
        $seenIds[$repo.id] = $true
    }

    if ($seenPaths.ContainsKey($repo.local_path)) {
        $errors.Add("Duplicate local_path: $($repo.local_path)")
    } else {
        $seenPaths[$repo.local_path] = $true
    }

    if (-not ([string]$repo.remote).StartsWith('https://example.com/')) {
        $errors.Add("Repository $($repo.id) remote is not a sample Git HTTPS URL.")
    }

    if (-not ([string]$repo.local_path).StartsWith('D:\workspace\agent-harness\repos\')) {
        $errors.Add("Repository $($repo.id) local_path is not under D:\\workspace\\agent-harness\\repos\\.")
    }

    if ($allowedStatuses -notcontains [string]$repo.status) {
        $errors.Add("Repository $($repo.id) has an unsupported status: $($repo.status)")
    }

    if ($allowedCloneModes -notcontains [string]$repo.clone_mode) {
        $errors.Add("Repository $($repo.id) has an unsupported clone_mode: $($repo.clone_mode)")
    }

    if ($allowedProfiles -notcontains [string]$repo.validation_profile) {
        $errors.Add("Repository $($repo.id) has an unsupported validation_profile: $($repo.validation_profile)")
    }

    if ($allowedRoles -notcontains [string]$repo.role) {
        $errors.Add("Repository $($repo.id) has an unsupported role: $($repo.role)")
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Repository metadata validation failed: " -ForegroundColor Red
    foreach ($errorItem in $errors) {
        Write-Host "  - $errorItem" -ForegroundColor Red
    }
    throw "repos.yaml validation failed."
}

Write-Host "repos.yaml validation passed." -ForegroundColor Green
$repos | Select-Object id, role, validation_profile, stack, default_branch, status | Format-Table -AutoSize
