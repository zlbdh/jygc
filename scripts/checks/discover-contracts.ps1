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
            findings = @('本地仓库尚未克隆。')
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
                $findings.Add('缺少 pom.xml。')
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
                    $findings.Add('未发现 build/build:prod 脚本。')
                } else {
                    $suggestedStatus = 'baseline-ready'
                }
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('缺少 package.json。')
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
                    $findings.Add('未发现 typecheck/test 脚本。')
                } else {
                    $suggestedStatus = 'baseline-ready'
                    if ($packageScripts -notcontains 'typecheck') {
                        $findings.Add('未发现 typecheck，已回退为 lint/test 基线。')
                    }
                }
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('缺少 package.json。')
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
                    $findings.Add('未发现小程序构建脚本。')
                } else {
                    $suggestedStatus = 'missing-local-env'
                    $findings.Add('需补充微信开发者工具或等价本地环境。')
                }
            } else {
                $suggestedStatus = 'missing-contract'
                $findings.Add('缺少小程序关键配置文件。')
            }
        }
    }

    if ($gitExists -eq $false) {
        $findings.Add('目录存在但不是 git 仓库。')
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
        '# 契约发现报告',
        '',
        "| 仓库 | 配置状态 | 建议状态 | Manifest | 关键脚本 | 发现 |",
        "|------|----------|----------|----------|----------|------|"
    )

    foreach ($item in $results) {
        $manifests = if ($item.manifests.Count -gt 0) { ($item.manifests -join ', ') } else { '无' }
        $scripts = if ($item.package_scripts.Count -gt 0) { ($item.package_scripts -join ', ') } else { '无' }
        $findingsText = if ($item.findings.Count -gt 0) { ($item.findings -join '；') } else { '无' }
        $lines += "| $($item.id) | $($item.configured_status) | $($item.suggested_status) | $manifests | $scripts | $findingsText |"
    }

    Write-HarnessJsonFile -Path $jsonPath -Data $results
    Write-HarnessTextFile -Path $mdPath -Content ($lines -join [Environment]::NewLine)
    Write-Host "已输出契约发现报告：" -ForegroundColor Green
    Write-Host "  - $mdPath"
    Write-Host "  - $jsonPath"
}

$results | Select-Object id, configured_status, suggested_status, validation_profile | Format-Table -AutoSize | Out-Host
if ($PassThru) {
    return $results
}
