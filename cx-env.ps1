param()

if ($env:VIRTUAL_ENV) {
    $defaultHome = Join-Path $env:VIRTUAL_ENV '.cx'
    if (Test-Path (Join-Path $env:VIRTUAL_ENV 'bin')) {
        $defaultBin = Join-Path $env:VIRTUAL_ENV 'bin'
    } else {
        $defaultBin = Join-Path $env:VIRTUAL_ENV 'Scripts'
    }
} else {
    $defaultHome = Join-Path $HOME '.cx'
    $defaultBin = Join-Path $HOME 'bin'
}

if (-not $env:CX_HOME) { $env:CX_HOME = $defaultHome }
if (-not $env:CX_BIN_DIR) { $env:CX_BIN_DIR = $defaultBin }

if ($env:PATH -notlike "*$($env:CX_BIN_DIR)*") {
    $env:PATH = "$($env:CX_BIN_DIR);$($env:PATH)"
}

if (-not $env:CX_DICTIONARY) { $env:CX_DICTIONARY = Join-Path $env:CX_HOME 'dict' }
if (-not $env:CX_USAGE_FILE) { $env:CX_USAGE_FILE = Join-Path $env:CX_HOME 'usage' }
if (-not $env:CX_DECOMP_SPEC) { $env:CX_DECOMP_SPEC = Join-Path $env:CX_HOME 'decompression_spec.md' }

$apiKeyFile = Join-Path $env:CX_HOME 'openai_api_key'
if (-not $env:OPENAI_API_KEY -and (Test-Path $apiKeyFile)) {
    $env:OPENAI_API_KEY = Get-Content $apiKeyFile | Select-Object -First 1
}
