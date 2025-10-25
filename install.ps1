param()

$installDir = if ($env:CX_HOME) { $env:CX_HOME } else { Join-Path $HOME '.cx' }
$binDir = if ($env:CX_BIN_DIR) { $env:CX_BIN_DIR } else { Join-Path $HOME 'bin' }

function Resolve-Python {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return @{ Cmd = 'python'; Prefix = @() } }
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { return @{ Cmd = 'py'; Prefix = @('-3') } }
    Write-Error 'Python is required to install Codex wrappers. Install Python 3 and re-run the installer.'
    exit 1
}

$pythonInfo = Resolve-Python
$pythonCmd = $pythonInfo.Cmd
$pythonPrefix = $pythonInfo.Prefix

function Invoke-Python {
    param(
        [string[]]$Arguments
    )

    & $pythonCmd @pythonPrefix @Arguments
}

function Ensure-Pip {
    Invoke-Python -Arguments @('-m', 'pip', '--version') *> $null
    if ($LASTEXITCODE -eq 0) { return }
    Invoke-Python -Arguments @('-m', 'ensurepip', '--upgrade') *> $null
    Invoke-Python -Arguments @('-m', 'pip', '--version') *> $null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'python -m pip unavailable; install pip to enable automatic dependency setup.'
    }
}

function Ensure-PythonModule {
    param(
        [string]$Module,
        [string[]]$InstallArguments
    )

    Invoke-Python -Arguments @('-c', "import $Module") *> $null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Python -Arguments @('-m', 'pip', 'install', '--user') + $InstallArguments *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to install Python module '$Module'. Install it manually."
        }
    }
}

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'metrics') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'context') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'offline') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'responses') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'prompts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'topics') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'grid') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'audit') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'inspect') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'hotspots') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'stale') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'format') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'depscan') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'improve') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'additive') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'enhance') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'backlog') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'modules') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'scaffold') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'weakpoints') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installDir 'doctor') -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $installDir 'relations') -Force | Out-Null
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

if (-not (Test-Path (Join-Path $installDir 'dict'))) {
    Copy-Item '.cx/dict' (Join-Path $installDir 'dict')
}

if (-not (Test-Path (Join-Path $installDir 'usage'))) {
    Copy-Item '.cx/usage' (Join-Path $installDir 'usage')
}

if (-not (Test-Path (Join-Path $installDir 'decompression_spec.md'))) {
    Copy-Item 'decompression_spec.md' (Join-Path $installDir 'decompression_spec.md')
}

Copy-Item 'cx-env.ps1' (Join-Path $installDir 'cx-env.ps1') -Force
Copy-Item 'cx-env.sh' (Join-Path $installDir 'cx-env.sh') -Force

Ensure-Pip
Ensure-PythonModule -Module 'tiktoken' -InstallArguments @('tiktoken')
Ensure-PythonModule -Module 'openai' -InstallArguments @('openai')

Copy-Item 'Invoke-Codex.ps1' (Join-Path $binDir 'Invoke-Codex.ps1') -Force
Copy-Item 'Compress-CX5.ps1' (Join-Path $binDir 'Compress-CX5.ps1') -Force

Write-Output "Installed Invoke-Codex.ps1 and Compress-CX5.ps1 to $binDir"
Write-Output "Dictionary and decompression spec ensured under $installDir"
Write-Output "Environment helpers written to $installDir/cx-env.{ps1,sh}"
Write-Output "Dot-source $installDir/cx-env.ps1 (or source cx-env.sh in WSL) to add Codex wrappers to your PATH automatically."
