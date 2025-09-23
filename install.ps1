param()

$installDir = Join-Path $HOME '.cx'
$binDir = Join-Path $HOME 'bin'

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

# Ensure tiktoken is available for token estimation
python -c "import tiktoken" 2>$null
if ($LASTEXITCODE -ne 0) {
    python -m pip install --user tiktoken | Out-Null
}

Copy-Item 'Invoke-Codex.ps1' (Join-Path $binDir 'Invoke-Codex.ps1') -Force
Copy-Item 'Compress-CX5.ps1' (Join-Path $binDir 'Compress-CX5.ps1') -Force

Write-Output "Installed Invoke-Codex.ps1 and Compress-CX5.ps1 to $binDir"
Write-Output "Dictionary and decompression spec ensured under $installDir"
Write-Output "Add $binDir to your PATH and dot-source the functions in your PowerShell profile."
