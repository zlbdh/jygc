[CmdletBinding()]
param(
    [string[]]$RepoIds,
    [switch]$NoReport,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\HarnessRepoTools.ps1')

function Get-PackageJsonData {
    param([string]$PackagePath)

    if (-not (Test-Path -LiteralPath $PackagePath)) {
        return $null
    }

    try {
        return (Get-Content -LiteralPath $PackagePath -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Discover-RepoContract {
    param([pscustomobject]$Repo)

    $repoPath = [string]$Repo.local_path
    $localExists = Test-Path -LiteralPath $repoPath
    $gitExists = Test-Path -LiteralPath (Join-Path $repoPath '.git')
    $manifestNames = New-Object System.Collections.Generic.List[string]
    $packageScripts = @()
    $frameworks = New-Object System.Collections.Generic.List[string]
    $findings = New-Object System.Collections.Generic.List[string]
    $suggestedCommands = [ordered]@{
        build = ''
        test = ''
        typecheck = ''
        smoke = ''
    }
    $suggestedStatus = [string]$Repo.status

    if (-not $localExists) {
        return [pscustomobject]@{
            id = $Repo.id
            name = $Repo.name
            role = $Repo.role
            validation_profile = $Repo.validation_profile
            configured_status = $Repo.status
            suggested_status = $Repo.status
            local_exists = $false
            git_exists = $false
            manifests = @()
            package_scripts = @()
            frameworks = @()
            suggested_commands = [pscustomobject]$suggestedCommands
            findings = @('The repository has not been cloned locally.')
        }
    }

    $manifestCandidates = @(
        'pom.xml',
        'package.json',
        'package-lock.json',
        'pnpm-lock.yaml',
        'yarn.lock',
        'vite.config.js',
        'vite.config.ts',
        'project.config.json',
        'app.json',
        'app.config.js',
        'app.config.ts',
        'metro.config.js'
    )

    foreach ($manifest in $manifestCandidates) {
        if (Test-Path -LiteralPath (Join-Path $repoPath $manifest)) {
            $manifestNames.Add($manifest)
        }
    }

    $packageJson = Get-PackageJsonData -PackagePath (Join-Path $repoPath 'package.json')
    if ($null -ne $packageJson) {
        if ($null -ne $packageJson.scripts) {
            $packageScripts = @($packageJson.scripts.PSObject.Properties.Name | Sort-Object)
        }

        $dependencyNames = @()
        if ($null -ne $packageJson.dependencies) {
            $dependencyNames += @($packageJson.dependencies.PSObject.Properties.Name)
        }
        if ($null -ne $packageJson.devDependencies) {
            $dependencyNames += @($packageJson.devDependencies.PSObject.Properties.Name)
        }

        if ($dependencyNames -contains 'vite') { $frameworks.Add('vite') }
        if ($dependencyNames -contains 'expo') { $frameworks.Add('expo') }
        if ($dependencyNames -contains 'react-native') { $frameworks.Add('react-native') }
        if (@($dependencyNames | Where-Object { $_ -like '@dcloudio/*' }).Count -gt 0) { $frameworks.Add('uniapp') }
    }

    switch ([string]$Repo.validation_profile) {
        'backend-maven' {
            if ($manifestNames -contains 'pom.xml') {
                $suggestedCommands.build = [string]$Repo.build_command
                $suggestedCommands.test = [string]$Repo.test_command
                $suggestedCommands.smoke = [string]$Repo.smoke_command
                $suggestedStatus = 'baseline-ready'
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('pom.xml is missing.')
            }
        }
        'web-vite' {
            if ($manifestNames -contains 'package.json') {
                if ($packageScripts -contains 'build:prod') {
                    $suggestedCommands.build = 'npm run build:prod'
                } elseif ($packageScripts -contains 'build') {
                    $suggestedCommands.build = 'npm run build'
                }

                if ($packageScripts -contains 'typecheck') {
                    $suggestedCommands.typecheck = 'npm run typecheck'
                }
                if ($packageScripts -contains 'test') {
                    $suggestedCommands.test = 'npm run test'
                }
                $suggestedCommands.smoke = [string]$Repo.smoke_command

                if ([string]::IsNullOrWhiteSpace($suggestedCommands.build)) {
                    $suggestedStatus = 'missing-contract'
                    $findings.Add('No build/build:prod script was found.')
                } else {
                    $suggestedStatus = 'baseline-ready'
                }
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('package.json is missing.')
            }
        }
        'mobile-rn' {
            if ($manifestNames -contains 'package.json') {
                if ($packageScripts -contains 'lint') {
                    $suggestedCommands.typecheck = 'npm run lint'
                }
                if ($packageScripts -contains 'typecheck') {
                    $suggestedCommands.typecheck = 'npm run typecheck'
                }
                if ($packageScripts -contains 'test') {
                    $suggestedCommands.test = 'npm run test -- --watch=false'
                }
                if ($packageScripts -contains 'start') {
                    $suggestedCommands.build = 'npm run start'
                } elseif ($frameworks -contains 'expo') {
                    $suggestedCommands.build = 'npx expo start --offline'
                }
                $suggestedCommands.smoke = [string]$Repo.smoke_command

                if ([string]::IsNullOrWhiteSpace($suggestedCommands.typecheck) -and [string]::IsNullOrWhiteSpace($suggestedCommands.test)) {
                    $suggestedStatus = 'missing-contract'
                    $findings.Add('No typecheck/test script was found.')
                } else {
                    $suggestedStatus = 'baseline-ready'
                    if ($packageScripts -notcontains 'typecheck') {
                        $findings.Add('No typecheck script was found; using the lint/test baseline instead.')
                    }
                }
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('package.json is missing.')
            }
        }
        'miniapp' {
            if (($manifestNames -contains 'project.config.json') -or ($manifestNames -contains 'app.json') -or ($manifestNames -contains 'package.json')) {
                if ($packageScripts -contains 'build') {
                    $suggestedCommands.build = 'npm run build'
                }
                if ($packageScripts -contains 'lint') {
                    $suggestedCommands.test = 'npm run lint'
                }
                $suggestedCommands.smoke = [string]$Repo.smoke_command

                if ([string]::IsNullOrWhiteSpace($suggestedCommands.build)) {
                    $suggestedStatus = 'missing-contract'
                    $findings.Add('No miniapp build script was found.')
                } else {
                    $suggestedStatus = 'missing-local-env'
                    $findings.Add('Install WeChat DevTools or an equivalent local environment.')
                }
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('Required miniapp configuration files are missing.')
            }
        }
    }

    if ($gitExists -eq $false) {
        $findings.Add('The directory exists but is not a Git repository.')
    }

    return [pscustomobject]@{
        id = $Repo.id
        name = $Repo.name
        role = $Repo.role
        validation_profile = $Repo.validation_profile
        configured_status = $Repo.status
        suggested_status = $suggestedStatus
        local_exists = $localExists
        git_exists = $gitExists
        manifests = @($manifestNames)
        package_scripts = @($packageScripts)
        frameworks = @($frameworks | Select-Object -Unique)
        suggested_commands = [pscustomobject]$suggestedCommands
        findings = @($findings)
    }
}

$repos = Get-HarnessRepoConfig
if ($RepoIds -and $RepoIds.Count -gt 0) {
    $repos = @($repos | Where-Object { $RepoIds -contains $_.id })
}

$results = @($repos | ForEach-Object { Discover-RepoContract -Repo $_ })

if (-not $NoReport) {
    $reportDir = Get-HarnessValidationReportDir
    $timestamp = Get-HarnessTimestamp
    $jsonPath = Join-Path $reportDir ($timestamp + '-contracts.json')
    $mdPath = Join-Path $reportDir ($timestamp + '-contracts.md')

    $lines = @(
        '# Contract discovery reports',
        '',
        "| Repository | Configured status | Recommended status | Manifest | Key scripts | Findings |",
        "|------|----------|----------|----------|----------|------|"
    )

    foreach ($item in $results) {
        $manifests = if ($item.manifests.Count -gt 0) { ($item.manifests -join ', ') } else { 'None' }
        $scripts = if ($item.package_scripts.Count -gt 0) { ($item.package_scripts -join ', ') } else { 'None' }
        $findingsText = if ($item.findings.Count -gt 0) { ($item.findings -join '; ') } else { 'None' }
        $lines += "| $($item.id) | $($item.configured_status) | $($item.suggested_status) | $manifests | $scripts | $findingsText |"
    }

    Write-HarnessJsonFile -Path $jsonPath -Data $results
    Write-HarnessTextFile -Path $mdPath -Content ($lines -join [Environment]::NewLine)
    Write-Host "Generated contract discovery reports: " -ForegroundColor Green
    Write-Host "  - $mdPath"
    Write-Host "  - $jsonPath"
}

$results | Select-Object id, configured_status, suggested_status, validation_profile | Format-Table -AutoSize | Out-Host
if ($PassThru) {
    return $results
}
