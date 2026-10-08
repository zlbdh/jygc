[CmdletBinding()]
param(
    [switch]$RequireLocalRepos
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

$repoRoot = Get-HarnessRepoRoot
$validateReposScript = Join-Path $repoRoot 'scripts\checks\validate-repos.ps1'

& $validateReposScript

try {
    $null = git --version
} catch {
    throw "Git was not found. Install it and add it to PATH."
}

$requiredPaths = @(
    'README.md',
    'AGENTS.md',
    'repos\repos.yaml',
    'config',
    'config\agent-registry.yaml',
    'schemas',
    'schemas\worker-response.schema.json',
    'schemas\review-response.schema.json',
    'docs',
    'docs\harness-engineering.md',
    'docs\agent-workflow-skill-mcp.md',
    'docs\worker-harness-v1.md',
    'docs\memory-governance.md',
    'docs\rule-precedence.md',
    'docs\cross-repo',
    'docs\cross-repo\README.md',
    'docs\cross-repo\business-chain-index.md',
    'docs\cross-repo\dependency-map.md',
    'docs\cross-repo\contract-index.md',
    'standards',
    'standards\global\agent-governance.md',
    'standards\global\mcp-safety.md',
    'templates',
    'templates\design.md',
    'templates\execution.yaml',
    'templates\worker-result.md',
    'templates\verification-result.md',
    'templates\postmortem.md',
    'changes',
    'evals',
    'release',
    'reports',
    'reports\local-validation',
    'mcp',
    'mcp\README.md',
    'mcp\catalog.yaml',
    '.agent',
    '.agent\skills',
    '.agent\skills\memory-router',
    '.agent\skills\memory-router\SKILL.md',
    '.agent\skills\rule-resolver',
    '.agent\skills\rule-resolver\SKILL.md',
    '.agent\skills\postmortem-to-regression',
    '.agent\skills\postmortem-to-regression\SKILL.md',
    'scripts',
    'scripts\lib',
    'scripts\bootstrap\clone-repos.ps1',
    'scripts\bootstrap\sync-repos.ps1',
    'scripts\orchestrator',
    'scripts\orchestrator\dispatch-change.ps1',
    'scripts\orchestrator\run-role.ps1',
    'scripts\orchestrator\review-worker-output.ps1',
    'scripts\checks\discover-contracts.ps1',
    'scripts\checks\run-local-baseline.ps1'
)

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($required in $requiredPaths) {
    $fullPath = Join-Path $repoRoot $required
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $errors.Add("Required control-repository path is missing: $required")
    }
}

$repos = Get-HarnessRepoConfig
$roles = Get-HarnessAgentRegistry

if ($roles.Count -eq 0) {
    $errors.Add('No role definitions were found in agent-registry.yaml.')
}

foreach ($repo in $repos) {
    if (-not (Test-Path -LiteralPath $repo.local_path)) {
        $warnings.Add("Local business repository not found: $($repo.id) -> $($repo.local_path)")
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Workspace structure validation failed: " -ForegroundColor Red
    foreach ($errorItem in $errors) {
        Write-Host "  - $errorItem" -ForegroundColor Red
    }
    throw "Workspace structure validation failed."
}

Write-Host "The control-repository base structure is valid." -ForegroundColor Green

if ($warnings.Count -gt 0) {
    Write-Host "The following local business repositories are missing: " -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }

    if ($RequireLocalRepos) {
        throw "Some local business repositories are missing."
    }
}

Write-Host "Workspace check complete." -ForegroundColor Green
