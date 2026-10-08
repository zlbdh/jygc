Set-StrictMode -Version Latest

function Get-HarnessRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Unquote-HarnessScalar {
    param([string]$Value)

    $trimmed = $Value.Trim()
    if ($trimmed.Length -ge 2) {
        if (($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) -or ($trimmed.StartsWith("'") -and $trimmed.EndsWith("'"))) {
            $trimmed = $trimmed.Substring(1, $trimmed.Length - 2)
        }
    }
    return $trimmed.Replace('\\', '\')
}

function Parse-HarnessTopLevelListConfig {
    param(
        [string]$YamlPath,
        [string]$SectionName
    )

    if (-not (Test-Path -LiteralPath $YamlPath)) {
        throw "Configuration file not found: $YamlPath"
    }

    $lines = Get-Content -LiteralPath $YamlPath
    $repos = @()
    $insideRepos = $false
    $current = $null
    $currentListKey = $null

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -eq ("{0}:" -f $SectionName)) {
            $insideRepos = $true
            continue
        }

        if (-not $insideRepos) {
            continue
        }

        $indent = $line.Length - $line.TrimStart().Length

        if (($indent -eq 2) -and $trimmed.StartsWith('- ')) {
            if ($null -ne $current) {
                $repos += [pscustomobject]$current
            }

            $current = @{}
            $currentListKey = $null
            $inline = $trimmed.Substring(2).Trim()
            if ($inline) {
                $parts = $inline -split ':\s*', 2
                if ($parts.Count -eq 2) {
                    $current[$parts[0].Trim()] = (Unquote-HarnessScalar $parts[1])
                }
            }
            continue
        }

        if ($null -eq $current) {
            continue
        }

        if (($indent -ge 6) -and $trimmed.StartsWith('- ') -and $currentListKey) {
            if (-not ($current[$currentListKey] -is [System.Collections.IList])) {
                $current[$currentListKey] = New-Object System.Collections.Generic.List[string]
            }
            $current[$currentListKey].Add((Unquote-HarnessScalar ($trimmed.Substring(2))))
            continue
        }

        if ($indent -ge 4) {
            $parts = $trimmed -split ':\s*', 2
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $rawValue = $parts[1]

                if ([string]::IsNullOrWhiteSpace($rawValue)) {
                    $current[$key] = New-Object System.Collections.Generic.List[string]
                    $currentListKey = $key
                } else {
                    $current[$key] = (Unquote-HarnessScalar $rawValue)
                    $currentListKey = $null
                }
            }
        }
    }

    if ($null -ne $current) {
        $repos += [pscustomobject]$current
    }

    foreach ($repo in $repos) {
        foreach ($property in $repo.PSObject.Properties) {
            if ($property.Value -is [System.Collections.IList]) {
                $repo.$($property.Name) = @($property.Value)
            }
        }
    }

    return $repos
}

function Parse-HarnessRepoConfig {
    param([string]$YamlPath)

    return Parse-HarnessTopLevelListConfig -YamlPath $YamlPath -SectionName 'repos'
}

function Get-HarnessRepoConfig {
    $repoRoot = Get-HarnessRepoRoot
    return Parse-HarnessRepoConfig -YamlPath (Join-Path $repoRoot 'repos\repos.yaml')
}

function Get-HarnessAgentRegistry {
    $repoRoot = Get-HarnessRepoRoot
    return Parse-HarnessTopLevelListConfig -YamlPath (Join-Path $repoRoot 'config\agent-registry.yaml') -SectionName 'roles'
}

function Get-HarnessAgentRegistryMap {
    $roles = Get-HarnessAgentRegistry
    $map = @{}
    foreach ($role in $roles) {
        if (-not [string]::IsNullOrWhiteSpace([string]$role.id)) {
            $map[[string]$role.id] = $role
        }
    }
    return $map
}

function Parse-HarnessExecutionConfig {
    param([string]$YamlPath)

    if (-not (Test-Path -LiteralPath $YamlPath)) {
        throw "execution.yaml not found: $YamlPath"
    }

    $lines = Get-Content -LiteralPath $YamlPath
    $result = [ordered]@{
        ChangeId = ''
        Title = ''
        Stage = ''
        StageOwner = ''
        RepoOwners = @{}
        DependsOn = @()
        Branch = @{}
        Worktree = @{}
        SnapshotPolicy = @{}
        RuntimeType = @{}
        RegistryRef = @{}
        WorkerResult = @{}
        ReviewResult = @{}
        WriteScopesBusiness = @{}
        LockStateBusiness = @{}
    }

    $state = ''
    $subState = ''
    $currentRepoId = ''

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('#')) {
            continue
        }

        $indent = $line.Length - $line.TrimStart().Length

        if ($indent -eq 0) {
            $state = ''
            $subState = ''
            $currentRepoId = ''

            switch -Regex ($trimmed) {
                '^change_id:\s*(.+)$' {
                    $result.ChangeId = Unquote-HarnessScalar $Matches[1]
                    continue
                }
                '^title:\s*(.+)$' {
                    $result.Title = Unquote-HarnessScalar $Matches[1]
                    continue
                }
                '^stage:\s*(.+)$' {
                    $result.Stage = Unquote-HarnessScalar $Matches[1]
                    continue
                }
                '^stage_owner:\s*(.+)$' {
                    $result.StageOwner = Unquote-HarnessScalar $Matches[1]
                    continue
                }
                '^repo_owners:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'RepoOwners'
                    continue
                }
                '^depends_on:\s*$' {
                    $state = 'list'
                    $subState = 'DependsOn'
                    continue
                }
                '^branch:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'Branch'
                    continue
                }
                '^worktree:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'Worktree'
                    continue
                }
                '^snapshot_policy:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'SnapshotPolicy'
                    continue
                }
                '^runtime_type:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'RuntimeType'
                    continue
                }
                '^registry_ref:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'RegistryRef'
                    continue
                }
                '^worker_result:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'WorkerResult'
                    continue
                }
                '^review_result:\s*$' {
                    $state = 'simpleMap'
                    $subState = 'ReviewResult'
                    continue
                }
                '^write_scopes:\s*$' {
                    $state = 'writeScopes'
                    continue
                }
                '^lock_state:\s*$' {
                    $state = 'lockState'
                    continue
                }
            }

            continue
        }

        switch ($state) {
            'simpleMap' {
                if (($indent -ge 2) -and ($trimmed -match '^([A-Za-z0-9_-]+):\s*(.*)$')) {
                    $result[$subState][$Matches[1]] = Unquote-HarnessScalar $Matches[2]
                }
            }
            'list' {
                if (($indent -ge 2) -and ($trimmed -match '^- (.+)$')) {
                    $result.DependsOn += (Unquote-HarnessScalar $Matches[1])
                }
            }
            'writeScopes' {
                if (($indent -eq 2) -and ($trimmed -eq 'business_repos:')) {
                    $subState = 'business'
                    $currentRepoId = ''
                    continue
                }

                if ($subState -eq 'business') {
                    if (($indent -eq 4) -and ($trimmed -match '^([A-Za-z0-9_-]+):\s*(.*)$')) {
                        $currentRepoId = $Matches[1]
                        $rawValue = $Matches[2].Trim()
                        if ($rawValue -eq '[]') {
                            $result.WriteScopesBusiness[$currentRepoId] = @()
                            $currentRepoId = ''
                        } else {
                            $result.WriteScopesBusiness[$currentRepoId] = @()
                        }
                        continue
                    }

                    if (($indent -ge 6) -and ($trimmed -match '^- (.+)$') -and $currentRepoId) {
                        $result.WriteScopesBusiness[$currentRepoId] += (Unquote-HarnessScalar $Matches[1])
                    }
                }
            }
            'lockState' {
                if (($indent -eq 2) -and ($trimmed -eq 'business_repos:')) {
                    $subState = 'business'
                    continue
                }

                if (($subState -eq 'business') -and ($indent -eq 4) -and ($trimmed -match '^([A-Za-z0-9_-]+):\s*(.*)$')) {
                    $result.LockStateBusiness[$Matches[1]] = Unquote-HarnessScalar $Matches[2]
                }
            }
        }
    }

    return [pscustomobject]$result
}

function Ensure-HarnessDirectory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    return $Path
}

function Get-HarnessTimestamp {
    return (Get-Date -Format 'yyyyMMdd-HHmmss')
}

function Get-HarnessValidationReportDir {
    $repoRoot = Get-HarnessRepoRoot
    return (Ensure-HarnessDirectory -Path (Join-Path $repoRoot 'reports\local-validation'))
}

function Write-HarnessTextFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        Ensure-HarnessDirectory -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function Write-HarnessJsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 10
    Write-HarnessTextFile -Path $Path -Content $json
}

function Get-HarnessAuthenticatedRemoteUrl {
    param(
        [string]$Remote,
        [string]$AccessToken
    )

    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        return $Remote
    }

    if ($Remote -match '^https://example\.com/') {
        return $Remote -replace '^https://', ("https://oauth2:{0}@" -f $AccessToken)
    }

    return $Remote
}

function Invoke-HarnessCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = "/d /s /c ""$Command"""
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $null = $process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = (($stdout + $stderr).Trim())
        Command = $Command
        WorkingDirectory = $WorkingDirectory
    }
}

function Test-HarnessCommandExists {
    param([string]$Name)

    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-HarnessGitOriginUrl {
    param([string]$RepoPath)

    $result = Invoke-HarnessCommand -Command 'git remote get-url origin' -WorkingDirectory $RepoPath
    if ($result.ExitCode -ne 0) {
        return $null
    }
    return $result.Output
}

function Normalize-HarnessText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    return ($Value -replace '\r', '').Trim()
}
