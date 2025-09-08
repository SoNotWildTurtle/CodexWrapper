param(
    [Parameter(Mandatory=$true)][string]$role,
    [Parameter(Mandatory=$true)][string]$goal,
    [string]$cons,
    [string]$reason,
    [string]$out,
    [string]$raw,
    [switch]$estimate,
    [switch]$dry,
    [switch]$offline
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

function Log-Context {
    param([string]$field, [string]$orig, [string]$expanded)
    $syms = ([regex]::Matches($orig, '[@^#][A-Za-z0-9_]+') | Select-Object -Unique).Value
    foreach ($sym in $syms) {
        $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
        $dir = Join-Path $HOME '.cx/context'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Add-Content (Join-Path $dir "$sym.log") "[$timestamp] field=$field text=$expanded"
        $script:sessionSyms[$sym] = 1
    }
}

function Log-Relations {
    $file = Join-Path $HOME '.cx/relations'
    $combos = @{}
    if (Test-Path $file) {
        Get-Content $file | ForEach-Object {
            if ($_ -match '^(.*)=(\d+)$') { $combos[$matches[1]] = [int]$matches[2] }
        }
    }
    $limit = 9
    $syms = $sessionSyms.Keys | Select-Object -First $limit
    for ($i=0; $i -lt $syms.Count - 2; $i++) {
        for ($j=$i+1; $j -lt $syms.Count - 1; $j++) {
            for ($k=$j+1; $k -lt $syms.Count; $k++) {
                $combo = "$($syms[$i]),$($syms[$j]),$($syms[$k])"
                $combos[$combo] = ($combos[$combo] + 1)
            }
        }
    }
    $combos.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } | Set-Content $file
}

function Update-NeuronGrid {
    $dir = Join-Path $HOME '.cx/grid'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $proj = Split-Path (Get-Location) -Leaf
    $file = Join-Path $dir "$proj.grid"
    $grid = @{}
    if (Test-Path $file) {
        Get-Content $file | ForEach-Object {
            if ($_ -match '^(.*?):(.*)$') { $grid[$matches[1]] = $matches[2] }
        }
    }
    $limit = 9
    $syms = $sessionSyms.Keys | Select-Object -First $limit
    foreach ($center in $syms) {
        $neighbors = @()
        if ($grid.ContainsKey($center)) {
            $neighbors = $grid[$center].Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        }
        foreach ($n in $syms) {
            if ($n -eq $center) { continue }
            if ($neighbors -notcontains $n) { $neighbors += $n }
        }
        $grid[$center] = ($neighbors | Select-Object -Unique | Select-Object -First 8) -join ' '
    }
    $grid.GetEnumerator() | ForEach-Object { "{0}:{1}" -f $_.Key, $_.Value } | Set-Content $file
}

function Relation-Report {
    $file = Join-Path $HOME '.cx/relations'
    if (-not (Test-Path $file)) { return }
    [Console]::Error.WriteLine('Top symbol triads:')
    Get-Content $file | Sort-Object { ($_ -split '=')[1] } -Descending | Select-Object -First 5 | ForEach-Object { [Console]::Error.WriteLine($_) }
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

$sessionSyms = @{}

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

$roleOrig = $role
$goalOrig = $goal
$consOrig = $cons
$reasonOrig = $reason
$outOrig = $out

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

Log-Context 'role' $roleOrig $role
Log-Context 'goal' $goalOrig $goal
Log-Context 'cons' $consOrig $cons
Log-Context 'reason' $reasonOrig $reason
Log-Context 'out' $outOrig $out
Log-Relations
Update-NeuronGrid
Relation-Report

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
    [Console]::Error.WriteLine($msg)
    $proj = Split-Path (Get-Location) -Leaf
    $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
    $metricsDir = Join-Path $HOME '.cx/metrics'
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    Add-Content (Join-Path $metricsDir "$proj.log") "[$timestamp] $msg"
}

Write-Output $prompt
if (-not $dry) {
    if (-not $offline) {
        $key = $env:OPENAI_API_KEY
        if (-not $key) {
            $key = Read-Host 'Enter OpenAI API key (leave blank for offline)'
            if ($key) { $env:OPENAI_API_KEY = $key } else { $offline = $true }
        }
    }
    if ($offline) {
        $dir = Join-Path $HOME '.cx/offline'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
        $path = Join-Path $dir "$timestamp.txt"
        Set-Content $path $prompt
        [Console]::Error.WriteLine("Saved prompt offline to $path")
    } else {
        $key = $env:OPENAI_API_KEY
        $body = @{model='gpt-3.5-turbo'; messages=@(@{role='user'; content=$prompt})} | ConvertTo-Json -Depth 5
        try {
            $resp = Invoke-RestMethod -Uri https://api.openai.com/v1/chat/completions -Method Post -Headers @{Authorization="Bearer $key"} -Body $body -ContentType 'application/json'
            $resp.choices[0].message.content
        } catch {
            $dir = Join-Path $HOME '.cx/offline'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
            $path = Join-Path $dir "$timestamp.txt"
            Set-Content $path $prompt
            [Console]::Error.WriteLine("API call failed; saved prompt offline to $path")
        }
    }
}
