param(
    [Parameter(Mandatory=$true)][string]$role,
    [Parameter(Mandatory=$true)][string]$goal,
    [string]$cons,
    [string]$reason,
    [string]$raw,
    [string]$out
)

$cxHome = if ($env:CX_HOME) { $env:CX_HOME } else { Join-Path $HOME '.cx' }

$dict = @{}
$inv = @{}
function Load-Dict {
    param([string]$file)
    if (Test-Path $file) {
        Get-Content $file | ForEach-Object {
            if ($_ -match '^(.*?)=(.*)$') {
                $dict[$matches[1]] = $matches[2]
                $inv[$matches[2]] = $matches[1]
            }
        }
    }
}

Load-Dict (Join-Path $cxHome 'dict')
Load-Dict '.cx/dict'

function Expand-St {
    param([string]$text)
    return ($text -replace '\^st\{([0-9]+)\}', '^st$1')
}

function Norm-Commas {
    param([string]$text)
    $t = $text -replace ' *, *', ','
    return ($t -replace ',', ', ')
}

$role = Expand-St $role
$goal = Expand-St $goal
$cons = Expand-St $cons
$reason = Expand-St $reason
$out = Expand-St $out
$raw = Expand-St $raw

$sorted = $inv.Keys | Sort-Object Length -Descending
foreach ($val in $sorted) {
    $esc = [regex]::Escape($val)
    $key = $inv[$val]
    $role = $role -replace $esc, $key
    $goal = $goal -replace $esc, $key
    $cons = $cons -replace $esc, $key
    $reason = $reason -replace $esc, $key
    $out = $out -replace $esc, $key
    $raw = $raw -replace $esc, $key
}

$goal = Norm-Commas $goal
$cons = Norm-Commas $cons
$reason = Norm-Commas $reason

$F = "∫($role ⊕ goal($goal)"
if ($cons) { $F += " ⊕ d[$cons]" }
if ($reason) { $F += " ⊕ Π{$reason}" }
$F += ")"

Write-Output "CX5|v=1|Σ=|F=$F|R=$raw|O=$out"
