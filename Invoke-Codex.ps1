param(
    [Parameter(Mandatory=$true)][string]$role,
    [Parameter(Mandatory=$true)][string]$goal,
    [string]$cons,
    [string]$reason,
    [string]$out,
    [string]$raw,
    [switch]$estimate,
    [switch]$dry
)

function Expand-St {
    param([string]$text)
    return ($text -replace '\^st\{([0-9]+)\}', '^st$1')
}

function Norm-Commas {
    param([string]$text)
    $t = $text -replace ' *, *', ','
    return ($t -replace ',', ', ')
}

$dict = @{}
function Load-Dict {
    param([string]$file)
    if (Test-Path $file) {
        Get-Content $file | ForEach-Object {
            if ($_ -match '^(.*?)=(.*)$') {
                $dict[$matches[1]] = $matches[2]
            }
        }
    }
}

Load-Dict (Join-Path $HOME '.cx/dict')
Load-Dict '.cx/dict'

if ($raw) {
    $raw.Split(';') | ForEach-Object {
        $part = $_.Trim()
        if ($part -match '^(g|goal):(.*)$') {
            $goal = (($goal, $matches[2].Trim()) -join ', ').Trim(', ')
        } elseif ($part -match '^(c|cons):(.*)$') {
            $cons = (($cons, $matches[2].Trim()) -join ', ').Trim(', ')
        } else {
            $cons = (($cons, $part) -join ', ').Trim(', ')
        }
    }
}

$role = Expand-St $role
$goal = Norm-Commas (Expand-St $goal)
$cons = Norm-Commas (Expand-St $cons)
$reason = Norm-Commas (Expand-St $reason)
$out = Expand-St $out

$symbols = ([regex]::Matches("$role $goal $cons $reason $out", '[@^#][A-Za-z0-9_]+') | Select-Object -Unique).Value
foreach ($sym in $symbols) {
    if (-not $dict.ContainsKey($sym)) {
        $def = Read-Host "Define $sym"
        if ($def) {
            $dict[$sym] = $def
            New-Item -ItemType Directory -Path '.cx' -Force | Out-Null
            Add-Content '.cx/dict' "$sym=$def"
            $lines = Get-Content '.cx/dict'
            if ($lines.Count -gt 100) {
                $lines | Select-Object -Last 100 | Set-Content '.cx/dict'
            }
        }
    }
}

$sorted = $dict.Keys | Sort-Object Length -Descending
foreach ($k in $sorted) {
    $esc = [regex]::Escape($k)
    $role = $role -replace $esc, $dict[$k]
    $goal = $goal -replace $esc, $dict[$k]
    $cons = $cons -replace $esc, $dict[$k]
    $reason = $reason -replace $esc, $dict[$k]
    $out = $out -replace $esc, $dict[$k]
}

$prompt = "Follow these instructions exactly.`n::r $role`n::g $goal"
if ($cons) { $prompt += "`n::c $cons" }
if ($reason) { $prompt += "`n::s $reason" }
if ($out) { $prompt += "`n::o $out" }

if ($estimate) {
    $dry = $true
    $rawTokens = ($prompt -split '\s+').Count
    $compressedTokens = (("$role $goal $cons $reason $out" -split '\s+')).Count
    if ($rawTokens -gt 0) { $savings = [int](100 * ($rawTokens - $compressedTokens) / $rawTokens) } else { $savings = 0 }
    $msg = "raw=$rawTokens compressed=$compressedTokens savings=${savings}%"
    Write-Error $msg
    $proj = Split-Path (Get-Location) -Leaf
    $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
    $metricsDir = Join-Path $HOME '.cx/metrics'
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    Add-Content (Join-Path $metricsDir "$proj.log") "[$timestamp] $msg"
}

Write-Output $prompt
if (-not $dry) {
    Write-Error "(no API call implemented)"
}
