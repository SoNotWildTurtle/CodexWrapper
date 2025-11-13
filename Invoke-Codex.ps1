param(
    [string]$role,
    [string]$goal,
    [string]$cons,
    [string]$reason,
    [string]$out,
    [string]$raw,
    [switch]$estimate,
    [switch]$EstimateDetail,
    [switch]$EstimateSummary,
    [switch]$Recommendations,
    [string[]]$RecommendationsFilter,
    [string[]]$RecommendationsSearch,
    [switch]$dry,
    [switch]$offline,
    [string]$model,
    [double]$temperature,
    [switch]$topics,
    [string[]]$ConfigSet,
    [string[]]$ConfigUnset,
    [string]$ConfigScope,
    [string]$ConfigPath,
    [switch]$ConfigExport,
    [string]$ConfigExportPath,
    [string[]]$ConfigImport,
    [string[]]$ConfigReset,
    [switch]$ConfigTemplate,
    [string]$ConfigTemplateScope,
    [switch]$ConfigEdit,
    [string[]]$ConfigEditScope,
    [switch]$showConfig,
    [switch]$ShowConfigList,
    [switch]$ShowConfigDiff,
    [string]$ConfigDiffScopes,
    [switch]$ShowConfigWhich,
    [string[]]$ConfigWhich,
    [switch]$ConfigValidate,
    [string]$ConfigValidateScope,
    [switch]$ConfigEnv,
    [string]$ConfigEnvFormat,
    [string]$ProjectPath,
    [switch]$SelectProjectRoot
)

if ($EstimateDetail) {
    $estimate = $true
}

$script:ConfigHistory = @()
$script:ConfigLast = @{}
$script:ConfigUnknown = @()

function Get-ConfigDefaults {
    param([string[]]$Paths)

    $map = @{}
    foreach ($path in $Paths) {
        if (-not $path) { continue }
        if (-not (Test-Path $path)) { continue }
        foreach ($line in [System.IO.File]::ReadLines($path)) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            if ($trimmed.StartsWith('#')) { continue }
            $eqIndex = $trimmed.IndexOf('=')
            if ($eqIndex -lt 1) { continue }
            $rawKey = $trimmed.Substring(0, $eqIndex).Trim()
            $key = $rawKey.ToLowerInvariant()
            $value = $trimmed.Substring($eqIndex + 1).Trim()
            $canonical = $null
            switch ($key) {
                'role' { $canonical = 'role' }
                'goal' { $canonical = 'goal' }
                'cons' { $canonical = 'cons' }
                'constraints' { $canonical = 'cons' }
                'reason' { $canonical = 'reason' }
                'reasons' { $canonical = 'reason' }
                'out' { $canonical = 'out' }
                'output' { $canonical = 'out' }
                'raw' { $canonical = 'raw' }
                'model' { $canonical = 'model' }
                'temp' { $canonical = 'temperature' }
                'temperature' { $canonical = 'temperature' }
            }
            if ($canonical) {
                $map[$canonical] = $value
                $script:ConfigHistory += [pscustomobject]@{ Source = $path; Key = $canonical; Value = $value }
                $script:ConfigLast[$canonical] = [pscustomobject]@{ Source = $path; Value = $value }
            } else {
                $script:ConfigUnknown += [pscustomobject]@{ Source = $path; Key = $rawKey; Value = $value }
            }
        }
    }
    return $map
}

function Canonicalize-ConfigKey {
    param([string]$Key)

    if (-not $Key) { return '' }
    $canonical = $Key.Trim().ToLowerInvariant()
    switch ($canonical) {
        'constraints' { return 'cons' }
        'reasons' { return 'reason' }
        'output' { return 'out' }
        'topics' { return 'topic' }
        'temperature' { return 'temp' }
        'r' { return 'raw' }
        default { return $canonical }
    }
}

function Normalize-ConfigPath {
    param(
        [string]$Path,
        [string]$Base
    )

    if (-not $Path) { return $null }
    $expanded = [System.Environment]::ExpandEnvironmentVariables($Path)
    if ($expanded.StartsWith('~')) {
        $expanded = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) $expanded.Substring(1)
    }
    if (-not [System.IO.Path]::IsPathRooted($expanded)) {
        if (-not $Base) { $Base = (Get-Location).Path }
        $expanded = [System.IO.Path]::GetFullPath((Join-Path $Base $expanded))
    }
    return $expanded
}

function Select-ProjectDirectory {
    param([string]$InitialPath)

    $initial = $InitialPath
    if (-not $initial) { $initial = (Get-Location).Path }
    try {
        if (-not (Test-Path $initial -PathType Container)) {
            $initial = (Get-Location).Path
        }
    } catch {
        $initial = (Get-Location).Path
    }

    $selected = $null

    $isWindows = $false
    $isMac = $false
    $isLinux = $false
    try {
        $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
        $isMac = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
        $isLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
    } catch {
        $isWindows = $false
        $isMac = $false
        $isLinux = $false
    }

    if ($isWindows) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = 'Select project root for CodexWrapper'
            if ($initial -and (Test-Path $initial -PathType Container)) {
                $dialog.SelectedPath = $initial
            }
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $selected = $dialog.SelectedPath
            }
        } catch {
            $selected = $null
        }
    }

    if (-not $selected -and $isMac) {
        $osaCmd = Get-Command osascript -ErrorAction SilentlyContinue
        if ($osaCmd) {
            $escaped = $initial
            if (-not $escaped) { $escaped = (Get-Location).Path }
            $escaped = $escaped.Replace('"', '\"')
            $appleScript = @"
set initialFolder to POSIX file "$escaped"
try
  set chosenFolder to choose folder with prompt "Select project root" default location initialFolder
  POSIX path of chosenFolder
on error
  ""
end try
"@
            try {
                $osaOutput = & $osaCmd.Source -e $appleScript 2>$null
                if ($osaOutput) {
                    $candidate = ($osaOutput | Select-Object -First 1).Trim()
                    if ($candidate) { $selected = $candidate }
                }
            } catch {
                $selected = $null
            }
        }
    }

    if (-not $selected -and ($isLinux -or -not $isWindows)) {
        foreach ($tool in @('zenity','kdialog','yad')) {
            if ($selected) { break }
            $cmd = Get-Command $tool -ErrorAction SilentlyContinue
            if (-not $cmd) { continue }
            try {
                switch ($tool) {
                    'zenity' {
                        $candidate = & $cmd.Source --file-selection --directory --title 'Select project root' --filename "$initial/" 2>$null
                    }
                    'kdialog' {
                        $candidate = & $cmd.Source --getexistingdirectory $initial 2>$null
                    }
                    default {
                        $candidate = & $cmd.Source --file-selection --directory --title 'Select project root' --filename "$initial/" 2>$null
                    }
                }
                if ($candidate) {
                    $text = ($candidate | Select-Object -First 1).Trim()
                    if ($text) { $selected = $text }
                }
            } catch {
                continue
            }
        }
    }

    if (-not $selected) {
        $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
        if (-not $pythonCmd) {
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        }
        if ($pythonCmd) {
            $pythonCode = @"
import os
import sys

initial = sys.argv[1]
try:
    import tkinter as tk
    from tkinter import filedialog
except Exception:
    sys.exit(0)

root = tk.Tk()
root.withdraw()
try:
    root.update()
except Exception:
    pass

path = filedialog.askdirectory(initialdir=initial or None, title="Select project root")
root.destroy()
if path:
    print(path)
"@

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $pythonCmd.Path
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.ArgumentList.Add('-c')
            $psi.ArgumentList.Add($pythonCode)
            $psi.ArgumentList.Add($initial)

            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi
            if ($proc.Start()) {
                $proc.WaitForExit()
                if ($proc.ExitCode -eq 0) {
                    $output = $proc.StandardOutput.ReadToEnd().Trim()
                    if ($output) { $selected = $output }
                }
            }
        }
    }

    if (-not $selected) {
        $selected = Read-Host 'Enter project root path (leave blank to cancel)'
    }

    if (-not $selected) { return $null }

    $resolved = Normalize-ConfigPath -Path $selected -Base (Get-Location).Path
    if (-not (Test-Path $resolved -PathType Container)) {
        Write-Error "Selected project root '$resolved' was not found or is not a directory."
        return $null
    }

    return $resolved
}

function Resolve-ConfigTarget {
    param(
        [string]$Scope,
        [string]$CxHome,
        [string]$ProjectCx,
        [string]$CustomPath,
        [string]$ProjectRoot
    )

    if (-not $Scope) { $Scope = 'project' }
    $scopeLower = $Scope.ToLowerInvariant()

    if ($CustomPath) {
        $resolved = Normalize-ConfigPath -Path $CustomPath -Base $ProjectRoot
        return [pscustomobject]@{ Path = $resolved; Label = 'custom' }
    }

    switch ($scopeLower) {
        '' { $scopeLower = 'project' }
        'project' { return [pscustomobject]@{ Path = (Join-Path $ProjectCx 'config'); Label = 'project' } }
        'local' { return [pscustomobject]@{ Path = (Join-Path $ProjectCx 'config'); Label = 'project' } }
        'user' { return [pscustomobject]@{ Path = (Join-Path $CxHome 'config'); Label = 'user' } }
        'home' { return [pscustomobject]@{ Path = (Join-Path $CxHome 'config'); Label = 'user' } }
        'global' { return [pscustomobject]@{ Path = (Join-Path $CxHome 'config'); Label = 'user' } }
        default {
            if ($scopeLower.StartsWith('path:') -or $scopeLower.StartsWith('file:')) {
                $value = $Scope.Substring($Scope.IndexOf(':') + 1)
                $resolved = Normalize-ConfigPath -Path $value -Base $ProjectRoot
                return [pscustomobject]@{ Path = $resolved; Label = 'custom' }
            }
            $resolved = Normalize-ConfigPath -Path $Scope -Base $ProjectRoot
            return [pscustomobject]@{ Path = $resolved; Label = 'custom' }
        }
    }
}

function Manage-ConfigFile {
    param(
        [string]$TargetPath,
        [string]$ScopeLabel,
        [string[]]$SetEntries,
        [string[]]$UnsetKeys,
        [string[]]$ImportFiles
    )

    if (-not $TargetPath) {
        throw 'Config target path could not be resolved'
    }

    $directory = [System.IO.Path]::GetDirectoryName($TargetPath)
    if ($directory) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $map = @{}
    $order = New-Object System.Collections.Generic.List[string]

    if (Test-Path $TargetPath) {
        foreach ($line in [System.IO.File]::ReadLines($TargetPath)) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            if ($trimmed.StartsWith('#')) { continue }
            $eq = $trimmed.IndexOf('=')
            if ($eq -lt 1) { continue }
            $key = $trimmed.Substring(0, $eq)
            $value = $trimmed.Substring($eq + 1).Trim()
            $canonical = Canonicalize-ConfigKey $key
            if (-not $canonical) { continue }
            if (-not $order.Contains($canonical)) { $order.Add($canonical) | Out-Null }
            $map[$canonical] = $value
        }
    }

    if ($ImportFiles) {
        foreach ($import in $ImportFiles) {
            if (-not $import) { continue }
            $resolvedImport = Normalize-ConfigPath -Path $import -Base (Get-Location).Path
            if (-not $resolvedImport -or -not (Test-Path $resolvedImport)) {
                throw "Config import file not found: $import"
            }
            foreach ($line in [System.IO.File]::ReadLines($resolvedImport)) {
                $trimmed = $line.Trim()
                if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
                if ($trimmed.StartsWith('#')) { continue }
                $eq = $trimmed.IndexOf('=')
                if ($eq -lt 1) { continue }
                $key = $trimmed.Substring(0, $eq)
                $value = $trimmed.Substring($eq + 1).Trim()
                $canonical = Canonicalize-ConfigKey $key
                if (-not $canonical) { continue }
                if (-not $order.Contains($canonical)) { $order.Add($canonical) | Out-Null }
                $map[$canonical] = $value
            }
        }
    }

    if ($SetEntries) {
        foreach ($entry in $SetEntries) {
            if (-not $entry) { continue }
            $eq = $entry.IndexOf('=')
            if ($eq -lt 1) { throw "Invalid --ConfigSet entry '$entry'. Expected key=value." }
            $key = $entry.Substring(0, $eq)
            $value = $entry.Substring($eq + 1).Trim()
            $canonical = Canonicalize-ConfigKey $key
            if (-not $canonical) { throw "Invalid --ConfigSet entry '$entry'. Key cannot be empty." }
            if (-not $order.Contains($canonical)) { $order.Add($canonical) | Out-Null }
            $map[$canonical] = $value
        }
    }

    if ($UnsetKeys) {
        foreach ($key in $UnsetKeys) {
            if (-not $key) { continue }
            $canonical = Canonicalize-ConfigKey $key
            if (-not $canonical) { continue }
            $map.Remove($canonical) | Out-Null
        }
        $order = New-Object System.Collections.Generic.List[string] ($order | Where-Object { $map.ContainsKey($_) })
    }

    if ($map.Count -eq 0) {
        if (Test-Path $TargetPath) {
            Remove-Item -Path $TargetPath -Force
            [Console]::Error.WriteLine("Removed empty config file: $TargetPath")
        } else {
            [Console]::Error.WriteLine("No config entries to persist for scope '$ScopeLabel'.")
        }
        return
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# cx configuration ($ScopeLabel scope)") | Out-Null
    $lines.Add("# Updated: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')") | Out-Null
    foreach ($key in $order) {
        if ($map.ContainsKey($key)) {
            $lines.Add("{0}={1}" -f $key, $map[$key]) | Out-Null
        }
    }
    foreach ($key in $map.Keys) {
        if (-not $order.Contains($key)) {
            $lines.Add("{0}={1}" -f $key, $map[$key]) | Out-Null
        }
    }
    [System.IO.File]::WriteAllLines($TargetPath, $lines)
    [Console]::Error.WriteLine("Wrote config to $TargetPath ($ScopeLabel scope)")
}

function Reset-ConfigFile {
    param(
        [string]$TargetPath,
        [string]$ScopeLabel
    )

    if (-not $TargetPath) {
        throw 'Config target path could not be resolved'
    }

    if (Test-Path $TargetPath) {
        Remove-Item -LiteralPath $TargetPath -Force
        Write-Output ("Removed config file for {0} scope ({1})" -f $ScopeLabel, $TargetPath)
    } else {
        Write-Output ("No config file found for {0} scope ({1})" -f $ScopeLabel, $TargetPath)
    }
}

function Show-ConfigTemplate {
    param(
        [pscustomobject]$Target
    )

    if (-not $Target -or -not $Target.Path) {
        throw 'Config target path could not be resolved'
    }

    Write-Output ("# cx configuration template ({0} scope)" -f $Target.Label)
    Write-Output ("# Save to: {0}" -f $Target.Path)
    Write-Output '# Lines beginning with ''#'' are ignored.'
    Write-Output '# Configure defaults for frequently reused prompt fields.'
    Write-Output 'role=You are a seasoned developer.'
    Write-Output 'goal=Summarize the current objective.'
    Write-Output 'cons=List any constraints that must be enforced.'
    Write-Output 'reason=Outline the reasoning approach or checklist.'
    Write-Output 'out=code'
    Write-Output 'topic=project-tag'
    Write-Output 'model=gpt-4o-mini'
    Write-Output 'temp=0.2'
    Write-Output '# raw=Add raw directives (e.g. r:include tests)'
}

function Write-ConfigTemplateFile {
    param(
        [string]$TargetPath,
        [string]$ScopeLabel
    )

    if (-not $TargetPath) {
        throw 'Config target path could not be resolved'
    }

    $directory = [System.IO.Path]::GetDirectoryName($TargetPath)
    if ($directory) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $lines = @()
    $lines += "# cx configuration template (${ScopeLabel} scope)"
    $lines += '# Lines beginning with ''#'' are ignored.'
    $lines += '# Configure defaults for frequently reused prompt fields.'
    $lines += 'role=You are a seasoned developer.'
    $lines += 'goal=Summarize the current objective.'
    $lines += 'cons=List any constraints that must be enforced.'
    $lines += 'reason=Outline the reasoning approach or checklist.'
    $lines += 'out=code'
    $lines += 'topic=project-tag'
    $lines += 'model=gpt-4o-mini'
    $lines += 'temp=0.2'
    $lines += '# raw=Add raw directives (e.g. r:include tests)'

    [System.IO.File]::WriteAllLines($TargetPath, $lines)
}

function Get-ConfigEditorCommand {
    $candidates = @()
    if ($env:CX_CONFIG_EDITOR) { $candidates += $env:CX_CONFIG_EDITOR }
    if ($env:EDITOR) { $candidates += $env:EDITOR }
    if ($env:VISUAL) { $candidates += $env:VISUAL }

    foreach ($fallback in @('code', 'code-insiders', 'notepad', 'nano', 'vi', 'vim')) {
        if (Get-Command $fallback -ErrorAction SilentlyContinue) {
            $candidates += $fallback
            break
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and $candidate.Trim().Length -gt 0) {
            return $candidate
        }
    }

    return $null
}

function Split-CommandLine {
    param([string]$Command)

    if (-not $Command) { return @() }

    $errors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($Command, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        return @($Command)
    }

    $parts = @()
    foreach ($token in $tokens) {
        if ($token.Type -in @('Command', 'CommandArgument', 'StringLiteral')) {
            $value = $token.Content
            if ($token.Type -eq 'StringLiteral' -and $value.Length -ge 2) {
                $quote = $value[0]
                if (($quote -eq '"' -and $value[-1] -eq '"') -or ($quote -eq ''' -and $value[-1] -eq ''')) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }
            if ($value) { $parts += $value }
        }
    }

    if ($parts.Count -eq 0) { $parts = @($Command) }
    return $parts
}

function Invoke-EditorCommand {
    param(
        [string]$Command,
        [string]$TargetPath
    )

    if (-not $Command) { throw 'Editor command was not provided.' }
    if (-not $TargetPath) { throw 'Editor target path was not provided.' }

    $parts = Split-CommandLine -Command $Command
    if ($parts.Count -eq 0) { $parts = @($Command) }

    $exe = $parts[0]
    $args = @()
    if ($parts.Count -gt 1) {
        $args = $parts[1..($parts.Count - 1)]
    }
    $args += $TargetPath

    & $exe @args
    return $LASTEXITCODE
}

function Get-ConfigMapFromFile {
    param([string]$Path)

    $map = @{}
    if (-not $Path) { return $map }
    if (-not (Test-Path $Path)) { return $map }

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith('#')) { continue }
        $eq = $trimmed.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $trimmed.Substring(0, $eq)
        $value = $trimmed.Substring($eq + 1).Trim()
        $canonical = Canonicalize-ConfigKey $key
        if (-not $canonical) { continue }
        $map[$canonical] = $value
    }

    return $map
}

function Show-ConfigDiff {
    param(
        [pscustomobject]$Left,
        [pscustomobject]$Right
    )

    Write-Output '# Config diff'

    $leftPath = $Left.Path
    $leftLabel = $Left.Label
    $rightPath = $Right.Path
    $rightLabel = $Right.Label

    if (-not $leftLabel) { $leftLabel = 'project' }
    if (-not $rightLabel) { $rightLabel = 'user' }

    $leftDisplay = if ($leftPath) { $leftPath } else { '(unresolved)' }
    if ($leftPath -and -not (Test-Path $leftPath)) { $leftDisplay = "{0} (missing)" -f $leftPath }
    $rightDisplay = if ($rightPath) { $rightPath } else { '(unresolved)' }
    if ($rightPath -and -not (Test-Path $rightPath)) { $rightDisplay = "{0} (missing)" -f $rightPath }

    Write-Output ("Comparing {0} ({1}) vs {2} ({3})" -f $leftLabel, $leftDisplay, $rightLabel, $rightDisplay)

    $leftMap = Get-ConfigMapFromFile -Path $leftPath
    $rightMap = Get-ConfigMapFromFile -Path $rightPath

    $keys = @()
    if ($leftMap.Keys.Count -gt 0) { $keys += $leftMap.Keys }
    if ($rightMap.Keys.Count -gt 0) { $keys += $rightMap.Keys }
    $keys = $keys | Sort-Object -Unique

    if (-not $keys -or $keys.Count -eq 0) {
        Write-Output '(no entries to compare)'
        return
    }

    $differences = New-Object System.Collections.Generic.List[string]
    foreach ($key in $keys) {
        $hasLeft = $leftMap.ContainsKey($key)
        $hasRight = $rightMap.ContainsKey($key)

        if ($hasLeft -and $hasRight) {
            $leftValue = $leftMap[$key]
            $rightValue = $rightMap[$key]
            if ($leftValue -ne $rightValue) {
                $differences.Add(("- {0}: {1}=\"{2}\" vs {3}=\"{4}\"" -f $key, $leftLabel, $leftValue, $rightLabel, $rightValue)) | Out-Null
            }
        } elseif ($hasLeft) {
            $leftValue = $leftMap[$key]
            $differences.Add(("- {0}: {1}=\"{2}\" (missing from {3})" -f $key, $leftLabel, $leftValue, $rightLabel)) | Out-Null
        } elseif ($hasRight) {
            $rightValue = $rightMap[$key]
            $differences.Add(("- {0}: {1}=\"{2}\" (missing from {3})" -f $key, $rightLabel, $rightValue, $leftLabel)) | Out-Null
        }
    }

    if ($differences.Count -eq 0) {
        Write-Output 'No differences.'
    } else {
        $differences | ForEach-Object { Write-Output $_ }
    }
}

function Show-ConfigReport {
    param(
        [string]$CxHome,
        [string]$ProjectRoot,
        [string[]]$SearchPaths,
        [System.Collections.IEnumerable]$History,
        [hashtable]$LastMap,
        [hashtable]$CliValues,
        [hashtable]$Resolved
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    Write-Output '# Configuration overview'
    Write-Output ("CX_HOME: {0}" -f $CxHome)
    Write-Output ("Project root: {0}" -f $ProjectRoot)
    Write-Output ("Project config dir: {0}" -f (Join-Path $ProjectRoot '.cx'))
    Write-Output ''
    Write-Output '## Config search paths'
    if (-not $SearchPaths -or $SearchPaths.Count -eq 0) {
        Write-Output '(no config paths)'
    } else {
        foreach ($path in $SearchPaths) {
            if (-not $path) { continue }
            $status = if (Test-Path $path) { 'found' } else { 'missing' }
            Write-Output ("- {0} ({1})" -f $path, $status)
        }
    }

    Write-Output ''
    Write-Output '## Layered defaults'
    if ($History -and $History.Count -gt 0) {
        foreach ($entry in $History) {
            Write-Output ("- {0}={1} (source: {2})" -f $entry.Key, $entry.Value, $entry.Source)
        }
    } else {
        Write-Output '(no layered defaults applied)'
    }

    Write-Output ''
    Write-Output '## Effective defaults'
    if ($LastMap.Keys.Count -gt 0) {
        foreach ($key in ($LastMap.Keys | Sort-Object)) {
            $entry = $LastMap[$key]
            Write-Output ("{0}={1} (source: {2})" -f $key, $entry.Value, $entry.Source)
        }
    } else {
        Write-Output '(no effective defaults)'
    }

    Write-Output ''
    Write-Output '## CLI overrides'
    $overrideKeys = @('role','goal','cons','reason','out','raw','model','temperature')
    $overrides = @()
    foreach ($key in $overrideKeys) {
        if ($CliValues.ContainsKey($key)) {
            $value = $CliValues[$key]
            if ($null -eq $value) { $value = '' }
            if ($value -is [double]) { $value = $value.ToString('G', $culture) }
            $overrides += ("{0}={1}" -f $key, $value)
        }
    }
    if ($overrides.Count -gt 0) {
        $overrides | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output '(none)'
    }

    Write-Output ''
    Write-Output '## Resolved values'
    foreach ($pair in @(
        @('role', $Resolved['role']),
        @('goal', $Resolved['goal']),
        @('cons', $Resolved['cons']),
        @('reason', $Resolved['reason']),
        @('out', $Resolved['out']),
        @('raw', $Resolved['raw']),
        @('topic', $Resolved['topic']),
        @('model', $Resolved['model']),
        @('temp', $Resolved['temp'])
    )) {
        $label = $pair[0]
        $value = $pair[1]
        if ($value -is [double]) {
            $value = $value.ToString('G', $culture)
        } elseif ($null -eq $value) {
            $value = ''
        }
        Write-Output ("{0}={1}" -f $label, $value)
    }
}

function Show-ConfigSources {
    param([System.Collections.IEnumerable]$History)

    Write-Output '# Config entries by source'
    if (-not $History -or $History.Count -eq 0) {
        Write-Output '(no layered defaults applied)'
        return
    }

    $groups = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($entry in $History) {
        $source = if ($entry.Source) { $entry.Source } else { '(unknown)' }
        if (-not $groups.Contains($source)) {
            $groups.Add($source, [System.Collections.Generic.List[string]]::new())
        }
        $groups[$source].Add("{0}={1}" -f $entry.Key, $entry.Value)
    }

    foreach ($key in $groups.Keys) {
        Write-Output ''
        Write-Output ("## {0}" -f $key)
        foreach ($line in $groups[$key]) {
            Write-Output ("  - {0}" -f $line)
        }
    }
}

function Convert-ToShellLiteral {
    param([string]$Value)

    if ($null -eq $Value) { return "''" }
    if ($Value.Length -eq 0) { return "''" }
    $escaped = $Value -replace "'", "'\\''"
    return "'$escaped'"
}

function Convert-ToPowerShellLiteral {
    param([string]$Value)

    if ($null -eq $Value) { return "''" }
    $escaped = $Value -replace "'", "''"
    return "'$escaped'"
}

function Show-ConfigEnv {
    param(
        [hashtable]$Resolved,
        [string]$Format
    )

    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $entries = @(
        @{ Name = 'CX_ROLE'; Value = $Resolved['role'] },
        @{ Name = 'CX_GOAL'; Value = $Resolved['goal'] },
        @{ Name = 'CX_CONS'; Value = $Resolved['cons'] },
        @{ Name = 'CX_REASON'; Value = $Resolved['reason'] },
        @{ Name = 'CX_OUT'; Value = $Resolved['out'] },
        @{ Name = 'CX_RAW'; Value = $Resolved['raw'] },
        @{ Name = 'CX_TOPIC'; Value = $Resolved['topic'] },
        @{ Name = 'CX_MODEL'; Value = $Resolved['model'] },
        @{ Name = 'CX_TEMP'; Value = $Resolved['temp'] }
    )

    $fmt = if ($Format) { $Format.Trim().ToLowerInvariant() } else { 'powershell' }

    switch ($fmt) {
        'shell' {
            Write-Output '# Shell exports for cx resolved configuration'
            Write-Output ("# Generated: {0}" -f $timestamp)
            foreach ($entry in $entries) {
                $value = $entry.Value
                if ($value -is [double]) { $value = $value.ToString('G', [System.Globalization.CultureInfo]::InvariantCulture) }
                if ($null -eq $value) { $value = '' }
                $literal = Convert-ToShellLiteral $value
                Write-Output ("export {0}={1}" -f $entry.Name, $literal)
            }
        }
        { $_ -in @('powershell','ps') } {
            Write-Output '# PowerShell environment assignments for cx resolved configuration'
            Write-Output ("# Generated: {0}" -f $timestamp)
            foreach ($entry in $entries) {
                $value = $entry.Value
                if ($value -is [double]) { $value = $value.ToString('G', [System.Globalization.CultureInfo]::InvariantCulture) }
                if ($null -eq $value) { $value = '' }
                $literal = Convert-ToPowerShellLiteral $value
                Write-Output ("Set-Item -Path Env:{0} -Value {1}" -f $entry.Name, $literal)
            }
        }
        default {
            throw "Unknown config environment format '$Format'. Use 'shell' or 'powershell'."
        }
    }
}

function Show-ConfigValidation {
    param(
        [string]$Scope,
        [System.Collections.IEnumerable]$History,
        [System.Collections.IEnumerable]$Unknown,
        [string]$CxHome,
        [string]$ProjectRoot,
        [string]$ProjectCx,
        [string]$CustomPath,
        [ref]$ErrorCount
    )

    if (-not $ErrorCount) { $ErrorCount = [ref]0 }

    $scopeLabel = 'layered defaults'
    $targetPath = $null
    $entries = New-Object System.Collections.Generic.List[object]
    $unknownEntries = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[string]

    $trimmedScope = if ($Scope) { $Scope.Trim() } else { '' }
    if ($trimmedScope) {
        $target = Resolve-ConfigTarget -Scope $trimmedScope -CxHome $CxHome -ProjectCx $ProjectCx -CustomPath $CustomPath -ProjectRoot $ProjectRoot
        if (-not $target -or -not $target.Path) {
            throw "Unable to resolve config scope '$Scope'."
        }
        $scopeLabel = $target.Label
        $targetPath = $target.Path
        if ($History) {
            foreach ($item in $History) {
                if ($null -eq $item) { continue }
                if ($item.Source -eq $targetPath) { $entries.Add($item) | Out-Null }
            }
        }
        if ($Unknown) {
            foreach ($item in $Unknown) {
                if ($null -eq $item) { continue }
                if ($item.Source -eq $targetPath) { $unknownEntries.Add($item) | Out-Null }
            }
        }
        if ($targetPath -and -not (Test-Path $targetPath)) {
            $warnings.Add("Config file $targetPath does not exist.") | Out-Null
        }
    } else {
        if ($History) {
            foreach ($item in $History) {
                if ($null -eq $item) { continue }
                $entries.Add($item) | Out-Null
            }
        }
        if ($Unknown) {
            foreach ($item in $Unknown) {
                if ($null -eq $item) { continue }
                $unknownEntries.Add($item) | Out-Null
            }
        }
    }

    Write-Output ("# Config validation ({0})" -f $scopeLabel)

    $entryCount = $entries.Count
    $unknownCount = $unknownEntries.Count
    if ($entryCount -eq 0 -and $unknownCount -eq 0) {
        Write-Output ''
        Write-Output 'No config entries were found for validation.'
    }

    if ($unknownCount -gt 0) {
        Write-Output ''
        Write-Output '## Unknown entries'
        foreach ($entry in $unknownEntries) {
            $errors.Add(("Unknown config key '{0}' in {1}" -f $entry.Key, $entry.Source)) | Out-Null
            Write-Output ("  - {0}={1} (source: {2})" -f $entry.Key, $entry.Value, $entry.Source)
        }
    }

    foreach ($entry in $entries) {
        $key = $entry.Key
        if ($key -eq 'temperature') { $key = 'temp' }
        $value = $entry.Value
        switch ($key) {
            'role' {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $errors.Add(("Config key 'role' from {0} is empty." -f $entry.Source)) | Out-Null
                }
            }
            'goal' {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $errors.Add(("Config key 'goal' from {0} is empty." -f $entry.Source)) | Out-Null
                }
            }
            'model' {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $errors.Add(("Model value from {0} is empty." -f $entry.Source)) | Out-Null
                }
            }
            'temp' {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $errors.Add(("Temperature value from {0} is empty." -f $entry.Source)) | Out-Null
                } else {
                    $parsed = 0.0
                    $style = [System.Globalization.NumberStyles]::Float
                    $culture = [System.Globalization.CultureInfo]::InvariantCulture
                    if (-not [double]::TryParse($value, $style, $culture, [ref]$parsed)) {
                        $errors.Add(("Temperature '{0}' from {1} is not numeric." -f $value, $entry.Source)) | Out-Null
                    } elseif ($parsed -lt 0 -or $parsed -gt 2) {
                        $errors.Add(("Temperature '{0}' from {1} is outside the allowed 0-2 range." -f $value, $entry.Source)) | Out-Null
                    }
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Output ''
        Write-Output '## Errors'
        foreach ($err in $errors) {
            Write-Output ("  - {0}" -f $err)
        }
    }

    if ($warnings.Count -gt 0) {
        Write-Output ''
        Write-Output '## Warnings'
        foreach ($warn in $warnings) {
            Write-Output ("  - {0}" -f $warn)
        }
    }

    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Output ''
        Write-Output 'Validation passed with no issues.'
    } elseif ($errors.Count -eq 0) {
        Write-Output ''
        Write-Output 'Validation completed with warnings.'
    }

    $ErrorCount.Value = $errors.Count
}

function Get-ConfigResolvedValue {
    param(
        [string]$Key,
        [hashtable]$Resolved
    )

    if (-not $Resolved.ContainsKey($Key)) {
        if ($Key -eq 'temp' -and $Resolved.ContainsKey('temp')) { return $Resolved['temp'] }
        return ''
    }
    $value = $Resolved[$Key]
    if ($null -eq $value) { return '' }
    if ($value -is [double]) {
        return $value.ToString('G', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $value
}

function Get-ConfigSourceLabel {
    param(
        [string]$Key,
        [hashtable]$CliValues,
        [hashtable]$LastMap,
        [hashtable]$EnvMap,
        [hashtable]$Resolved
    )

    $cliLookup = if ($CliValues.ContainsKey($Key)) { $Key } elseif ($Key -eq 'temp' -and $CliValues.ContainsKey('temperature')) { 'temperature' } else { $null }
    if ($cliLookup) {
        return 'CLI override'
    }

    if ($LastMap.ContainsKey($Key)) {
        $entry = $LastMap[$Key]
        if ($entry -and $entry.Source) { return $entry.Source }
    }

    if ($Key -eq 'temp' -and $LastMap.ContainsKey('temperature')) {
        $entry = $LastMap['temperature']
        if ($entry -and $entry.Source) { return $entry.Source }
    }

    if ($EnvMap.ContainsKey($Key)) {
        $envEntry = $EnvMap[$Key]
        return "environment $($envEntry.Name)"
    }

    $value = Get-ConfigResolvedValue -Key $Key -Resolved $Resolved
    if ($value) { return 'script default' }
    return '(not set)'
}

function Write-ConfigExport {
    param(
        [string]$OutputPath,
        [string[]]$SearchPaths,
        [hashtable]$Resolved,
        [hashtable]$CliValues,
        [hashtable]$LastMap,
        [hashtable]$EnvMap,
        [string]$ProjectRoot
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# cx configuration snapshot') | Out-Null
    $lines.Add("# Generated: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')") | Out-Null
    $lines.Add("# Project root: $ProjectRoot") | Out-Null
    $lines.Add('# Config search paths:') | Out-Null

    if ($SearchPaths -and $SearchPaths.Count -gt 0) {
        foreach ($path in $SearchPaths) {
            if (-not $path) { continue }
            $status = if (Test-Path $path) { 'found' } else { 'missing' }
            $lines.Add("#   - {0} ({1})" -f $path, $status) | Out-Null
        }
    } else {
        $lines.Add('#   (none)') | Out-Null
    }

    $lines.Add('') | Out-Null

    foreach ($key in @('role','goal','cons','reason','out','raw','topic','model','temp')) {
        $value = Get-ConfigResolvedValue -Key $key -Resolved $Resolved
        $source = Get-ConfigSourceLabel -Key $key -CliValues $CliValues -LastMap $LastMap -EnvMap $EnvMap -Resolved $Resolved
        if ($null -eq $value) { $value = '' }
        $lines.Add("{0}={1}  # source: {2}" -f $key, $value, $source) | Out-Null
    }

    if ($OutputPath) {
        $directory = [System.IO.Path]::GetDirectoryName($OutputPath)
        if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
        [System.IO.File]::WriteAllLines($OutputPath, $lines)
        [Console]::Error.WriteLine("Exported config snapshot to $OutputPath")
    } else {
        foreach ($line in $lines) { Write-Output $line }
    }
}

function Show-ConfigWhich {
    param(
        [string[]]$Keys,
        [hashtable]$LastMap,
        [hashtable]$CliValues,
        [hashtable]$Resolved,
        [hashtable]$EnvMap
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $set = New-Object System.Collections.Generic.HashSet[string]
    $ordered = New-Object System.Collections.Generic.List[string]

    function Add-Key([string]$Key) {
        if (-not $Key) { return }
        $canonical = Canonicalize-ConfigKey $Key
        if (-not $canonical) { return }
        if (-not $set.Contains($canonical)) {
            $set.Add($canonical) | Out-Null
            $ordered.Add($canonical) | Out-Null
        }
    }

    if (-not $Keys -or $Keys.Count -eq 0) {
        foreach ($default in @('role','goal','cons','reason','out','raw','topic','model','temp')) { Add-Key $default }
        foreach ($entry in $LastMap.Keys) { Add-Key $entry }
        foreach ($entry in $CliValues.Keys) { Add-Key $entry }
    } else {
        foreach ($entry in $Keys) {
            if (-not $entry) { continue }
            foreach ($part in ($entry -split ',')) {
                Add-Key $part
            }
        }
    }

    if ($ordered.Count -eq 0) {
        Write-Output 'No config keys to inspect.'
        return
    }

    $keysToShow = $ordered | Sort-Object -Unique

    Write-Output '# Config resolution'
    foreach ($key in $keysToShow) {
        Write-Output ''
        Write-Output ("## {0}" -f $key)

        $defaultLookup = if ($LastMap.ContainsKey($key)) { $key } elseif ($key -eq 'temp' -and $LastMap.ContainsKey('temperature')) { 'temperature' } else { $null }
        if ($defaultLookup) {
            $entry = $LastMap[$defaultLookup]
            Write-Output ("- default: {0} (source: {1})" -f $entry.Value, $entry.Source)
        } else {
            Write-Output '- default: (not set)'
        }

        $cliLookup = if ($CliValues.ContainsKey($key)) { $key } elseif ($key -eq 'temp' -and $CliValues.ContainsKey('temperature')) { 'temperature' } else { $null }
        if ($cliLookup) {
            $value = $CliValues[$cliLookup]
            if ($value -is [double]) { $value = $value.ToString('G', $culture) }
            Write-Output ("- cli: {0}" -f $value)
        } else {
            Write-Output '- cli: (not set)'
        }

        if ($EnvMap.ContainsKey($key)) {
            $envEntry = $EnvMap[$key]
            Write-Output ("- env: {0}={1}" -f $envEntry.Name, $envEntry.Value)
        } else {
            Write-Output '- env: (not set)'
        }

        $resolvedLookup = if ($Resolved.ContainsKey($key)) { $key } elseif ($key -eq 'temp' -and $Resolved.ContainsKey('temp')) { 'temp' } else { $null }
        $resolvedValue = $null
        if ($resolvedLookup) {
            $resolvedValue = $Resolved[$resolvedLookup]
        }
        if ($resolvedValue -is [double]) { $resolvedValue = $resolvedValue.ToString('G', $culture) }
        if ($null -eq $resolvedValue -or $resolvedValue -eq '') {
            Write-Output '- resolved: (empty)'
        } else {
            Write-Output ("- resolved: {0}" -f $resolvedValue)
        }
    }
}

$initialLocation = (Get-Location).Path
$projectOverride = $null

if ($ProjectPath) {
    $projectOverride = Normalize-ConfigPath -Path $ProjectPath -Base $initialLocation
}

if ($SelectProjectRoot) {
    $selectionBase = if ($projectOverride) { $projectOverride } else { $initialLocation }
    $selectedProject = Select-ProjectDirectory -InitialPath $selectionBase
    if (-not $selectedProject) {
        Write-Error 'Project root selection cancelled.'
        exit 1
    }
    $projectOverride = $selectedProject
}

if ($projectOverride) {
    if (-not (Test-Path $projectOverride -PathType Container)) {
        Write-Error "Project root '$projectOverride' was not found or is not a directory."
        exit 1
    }
    Set-Location $projectOverride
    Write-Host ("Selected project root: {0}" -f (Get-Location).Path)
}

$projectRoot = (Get-Location).Path
$projectCx = Join-Path $projectRoot '.cx'
$cxHome = if ($env:CX_HOME) { $env:CX_HOME } else { Join-Path $HOME '.cx' }
$defaultConfigScope = if ($ConfigPath) { "path:$ConfigPath" } elseif ($ConfigScope) { $ConfigScope } else { 'project' }
$showConfigTemplateRequested = $ConfigTemplate -or ($ConfigTemplateScope -and $ConfigTemplateScope.Trim().Length -gt 0)
$configEditRequested = $ConfigEdit -or ($ConfigEditScope -and $ConfigEditScope.Count -gt 0)

$configUpdateTarget = $null
$performedConfigUpdate = $false
if (-not $ConfigReset) { $ConfigReset = @() }
if ($PSBoundParameters.ContainsKey('ConfigReset') -and $ConfigReset.Count -eq 0) {
    $ConfigReset = @('')
}
if ($ConfigReset.Count -gt 0) {
    foreach ($spec in $ConfigReset) {
        $descriptor = if ($spec -and $spec.Trim().Length -gt 0) { $spec } else { $defaultConfigScope }
        $customOverride = if (-not $spec -or $spec.Trim().Length -eq 0) { $ConfigPath } else { $null }
        $target = Resolve-ConfigTarget -Scope $descriptor -CxHome $cxHome -ProjectCx $projectCx -CustomPath $customOverride -ProjectRoot $projectRoot
        if (-not $target -or -not $target.Path) {
            Write-Error "Unable to resolve config scope '$descriptor'."
            exit 1
        }
        Reset-ConfigFile -TargetPath $target.Path -ScopeLabel $target.Label
    }
    $performedConfigUpdate = $true
}

if (($ConfigSet -and $ConfigSet.Count -gt 0) -or ($ConfigUnset -and $ConfigUnset.Count -gt 0) -or ($ConfigImport -and $ConfigImport.Count -gt 0)) {
    if (-not $ConfigScope) { $ConfigScope = 'project' }
    $configUpdateTarget = Resolve-ConfigTarget -Scope $ConfigScope -CxHome $cxHome -ProjectCx $projectCx -CustomPath $ConfigPath -ProjectRoot $projectRoot
    Manage-ConfigFile -TargetPath $configUpdateTarget.Path -ScopeLabel $configUpdateTarget.Label -SetEntries $ConfigSet -UnsetKeys $ConfigUnset -ImportFiles $ConfigImport
    $performedConfigUpdate = $true
}

if ($configEditRequested) {
    $editScopes = @()
    if ($ConfigEditScope) { $editScopes += $ConfigEditScope }
    if ($ConfigEdit -and $editScopes.Count -eq 0) { $editScopes += '' }
    if ($editScopes.Count -eq 0) { $editScopes += '' }

    $editorCommand = Get-ConfigEditorCommand
    if (-not $editorCommand) {
        Write-Error 'Unable to locate an editor. Set CX_CONFIG_EDITOR or EDITOR before using -ConfigEdit.'
        exit 1
    }

    foreach ($spec in $editScopes) {
        $descriptor = if ($spec -and $spec.Trim().Length -gt 0) { $spec } else { $defaultConfigScope }
        $customOverride = if (-not $spec -or $spec.Trim().Length -eq 0) { $ConfigPath } else { $null }
        $target = Resolve-ConfigTarget -Scope $descriptor -CxHome $cxHome -ProjectCx $projectCx -CustomPath $customOverride -ProjectRoot $projectRoot
        if (-not $target -or -not $target.Path) {
            Write-Error "Unable to resolve config scope '$descriptor'."
            exit 1
        }

        if (-not (Test-Path $target.Path)) {
            Write-ConfigTemplateFile -TargetPath $target.Path -ScopeLabel $target.Label
            Write-Output ("Created config template at {0} ({1} scope)" -f $target.Path, $target.Label)
        }

        Write-Output ("Launching editor '{0}' for {1} config ({2})" -f $editorCommand, $target.Label, $target.Path)
        $exitCode = Invoke-EditorCommand -Command $editorCommand -TargetPath $target.Path
        if ($exitCode -ne 0) {
            Write-Error ("Editor command failed for {0}" -f $target.Path)
            exit $exitCode
        }

        if (-not $configUpdateTarget) { $configUpdateTarget = $target }
    }

    $performedConfigUpdate = $true
}

$configPaths = @()
$configPaths += (Join-Path $cxHome 'config')
$configPaths += (Join-Path $projectCx 'config')
if ($ConfigPath) {
    $resolvedCustom = Normalize-ConfigPath -Path $ConfigPath -Base $projectRoot
    if ($resolvedCustom) { $configPaths += $resolvedCustom }
} elseif ($configUpdateTarget -and $configUpdateTarget.Label -eq 'custom' -and $configUpdateTarget.Path) {
    $configPaths += $configUpdateTarget.Path
}
if ($env:CX_CONFIG) {
    $configPaths += ($env:CX_CONFIG -split '[:;]' | Where-Object { $_ })
}
$configPaths = $configPaths | Where-Object { $_ } | Select-Object -Unique
$showConfigDiffRequested = $ShowConfigDiff -or ($ConfigDiffScopes -and $ConfigDiffScopes.Trim().Length -gt 0)
$showConfigWhichRequested = $ShowConfigWhich -or ($ConfigWhich -and $ConfigWhich.Length -gt 0)
$configExportRequested = $ConfigExport -or ($ConfigExportPath -and $ConfigExportPath.Trim().Length -gt 0)
$configEnvRequested = $ConfigEnv -or ($ConfigEnvFormat -and $ConfigEnvFormat.Trim().Length -gt 0)
$configEnvFormat = if ($ConfigEnvFormat) { $ConfigEnvFormat.Trim() } else { $null }
$script:ConfigUnknown = @()
$configDefaults = Get-ConfigDefaults -Paths $configPaths

if (-not $PSBoundParameters.ContainsKey('role') -and $configDefaults.ContainsKey('role')) { $role = $configDefaults['role'] }
if (-not $PSBoundParameters.ContainsKey('goal') -and $configDefaults.ContainsKey('goal')) { $goal = $configDefaults['goal'] }
if (-not $PSBoundParameters.ContainsKey('cons') -and $configDefaults.ContainsKey('cons')) { $cons = $configDefaults['cons'] }
if (-not $PSBoundParameters.ContainsKey('reason') -and $configDefaults.ContainsKey('reason')) { $reason = $configDefaults['reason'] }
if (-not $PSBoundParameters.ContainsKey('out') -and $configDefaults.ContainsKey('out')) { $out = $configDefaults['out'] }
if (-not $PSBoundParameters.ContainsKey('raw') -and $configDefaults.ContainsKey('raw')) { $raw = $configDefaults['raw'] }
if (-not $PSBoundParameters.ContainsKey('model') -and $configDefaults.ContainsKey('model')) { $model = $configDefaults['model'] }
if (-not $PSBoundParameters.ContainsKey('temperature') -and $configDefaults.ContainsKey('temperature')) {
    try {
        $temperature = [double]::Parse($configDefaults['temperature'], [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        $temperature = $configDefaults['temperature']
    }
}

if ($EstimateSummary) {
    $proj = Split-Path (Get-Location) -Leaf
    $metricsPath = Join-Path (Join-Path $cxHome 'metrics') "$proj.log"
    if (-not (Test-Path $metricsPath)) {
        Write-Output "No metrics log for $proj"
        return
    }

    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    }

    if ($pythonCmd) {
        $pythonCode = @'
import sys
import re
from collections import defaultdict

path = sys.argv[1]
project = sys.argv[2]

pattern = re.compile(r"\[(?P<ts>[^\]]+)\]\s+(?:field=(?P<field>\w+)\s+)?raw=(?P<raw>\d+)\s+compressed=(?P<compressed>\d+)\s+savings=(?P<savings>-?\d+(?:\.\d+)?)%")

overall = []
fields = defaultdict(list)

with open(path, encoding='utf-8') as fh:
    for line in fh:
        match = pattern.search(line)
        if not match:
            continue
        entry = {
            'timestamp': match.group('ts'),
            'raw': int(match.group('raw')),
            'compressed': int(match.group('compressed')),
            'savings': float(match.group('savings')),
        }
        field = match.group('field')
        if field:
            fields[field].append(entry)
        else:
            overall.append(entry)

if not overall:
    print(f"No summary entries found in metrics log for {project}")
    sys.exit(0)

total_raw = sum(e['raw'] for e in overall)
total_compressed = sum(e['compressed'] for e in overall)
total_saved = total_raw - total_compressed
weighted = (total_saved / total_raw * 100.0) if total_raw else 0.0
mean = sum(e['savings'] for e in overall) / len(overall)
best = max(overall, key=lambda e: e['savings'])
worst = min(overall, key=lambda e: e['savings'])

def fmt(value: float) -> str:
    return f"{value:.2f}"

print(f"Token metrics summary for {project}")
print(f"  Runs logged: {len(overall)}")
print(f"  Total raw tokens: {total_raw}")
print(f"  Total compressed tokens: {total_compressed}")
print(f"  Total tokens saved: {total_saved}")
print(f"  Weighted average savings: {fmt(weighted)}% (across raw tokens)")
print(f"  Mean savings: {fmt(mean)}% (per run)")
print(f"  Best savings: {fmt(best['savings'])}% ({best['timestamp']})")
print(f"  Worst savings: {fmt(worst['savings'])}% ({worst['timestamp']})")

if fields:
    print('\nPer-field averages:')
    for name in sorted(fields):
        entries = fields[name]
        field_raw = sum(e['raw'] for e in entries)
        field_compressed = sum(e['compressed'] for e in entries)
        field_saved = field_raw - field_compressed
        weighted_field = (field_saved / field_raw * 100.0) if field_raw else 0.0
        mean_field = sum(e['savings'] for e in entries) / len(entries)
        print(f"  {name}: runs={len(entries)} saved={field_saved} avg={fmt(weighted_field)}% weighted, mean={fmt(mean_field)}%")
'@

        & $pythonCmd.Path -c $pythonCode -- $metricsPath $proj
    } else {
        Write-Warning 'python is required to summarize metrics; showing raw log instead.'
        Get-Content $metricsPath
    }
    return
}

if ($topics) {
    $dir = Join-Path $cxHome 'topics'
    if (Test-Path $dir) {
        Get-ChildItem $dir -Filter '*.log' | ForEach-Object {
            $count = (Get-Content $_.FullName).Count
            Write-Output "$($_.BaseName) $count"
        }
    } else {
        Write-Output 'No topics logged'
    }
    return
}

if ($showConfigTemplateRequested) {
    $templateScope = if ($ConfigTemplateScope) { $ConfigTemplateScope } else { $defaultConfigScope }
    $customOverride = if ($ConfigTemplateScope) { $null } else { $ConfigPath }
    $target = Resolve-ConfigTarget -Scope $templateScope -CxHome $cxHome -ProjectCx $projectCx -CustomPath $customOverride -ProjectRoot $projectRoot
    if (-not $target -or -not $target.Path) {
        Write-Error "Unable to resolve config scope '$templateScope'."
        exit 1
    }
    Show-ConfigTemplate -Target $target
    return
}

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
    $dir = Join-Path $cxHome 'context'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Add-Content (Join-Path $dir "$sym.log") "[$timestamp] field=$field text=$expanded"
        $script:sessionSyms[$sym] = 1
    }
}

if ($Recommendations -or $RecommendationsFilter -or $RecommendationsSearch) {
    $proj = Split-Path $projectRoot -Leaf
    $candidates = @(
        (Join-Path $projectRoot 'recommendations.md'),
        (Join-Path $cxHome 'recommendations.md')
    )
    $target = $null
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate -PathType Leaf)) {
            $target = $candidate
            break
        }
    }
    if (-not $target) {
        Write-Output "No recommendations.md found for $proj"
        return
    }

    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    }

    if ($pythonCmd) {
        $pythonCode = @'
import os
import sys
from collections import Counter

path = sys.argv[1]
project = sys.argv[2]

raw_filters = [line.strip().lower() for line in os.environ.get("CX_REC_FILTERS", "").splitlines() if line.strip()]
raw_search = [line.strip().lower() for line in os.environ.get("CX_REC_SEARCHES", "").splitlines() if line.strip()]

with open(path, encoding="utf-8") as fh:
    lines = fh.read().splitlines()

preface = []
sections = []
auto_section = []
current = None
status = ""
buffer = []
capture_auto = False

def flush_current():
    if current is None:
        return
    sections.append({
        "heading": current,
        "status": status,
        "lines": buffer.copy(),
    })

i = 0
while i < len(lines):
    line = lines[i]
    if line.startswith("## Auto-generated Summaries"):
        flush_current()
        auto_section = lines[i:]
        capture_auto = True
        break
    if line.startswith("## "):
        if current is not None:
            flush_current()
        current = line[3:].strip()
        status = ""
        buffer = [line]
    elif current is not None:
        buffer.append(line)
        if line.lower().startswith("status:"):
            status = line.split(":", 1)[1].strip()
    else:
        preface.append(line)
    i += 1

flush_current()

if capture_auto and not auto_section:
    auto_section = []

entries = [(section["heading"], section["status"]) for section in sections if section["heading"]]

counter = Counter()
completed = 0
for _, status_text in entries:
    if not status_text:
        continue
    key = status_text.split()[0]
    counter[key] += 1
    lowered = status_text.lower()
    if "✅" in status_text or "complete" in lowered or "done" in lowered:
        completed += 1

total = len(entries)
print(f"Recommendations summary ({total} tracked) for {project}")
for key, value in counter.most_common():
    print(f"  {key}: {value}")
pending = total - completed
print(f"  Completed: {completed}")
print(f"  Pending: {pending}")
if raw_filters:
    print(f"  Applied status filters: {', '.join(raw_filters)}")
if raw_search:
    print(f"  Applied search terms: {', '.join(raw_search)}")
print()

def matches_filters(section):
    if not raw_filters:
        return True
    status_text = section.get("status", "").lower()
    for token in raw_filters:
        if token in status_text:
            return True
    return False

def matches_search(section):
    if not raw_search:
        return True
    blob = "\n".join(section.get("lines", []))
    lowered = blob.lower()
    return all(term in lowered for term in raw_search)

if raw_filters or raw_search:
    for line in preface:
        print(line)
    if preface:
        print()
    for section in sections:
        if not matches_filters(section):
            continue
        if not matches_search(section):
            continue
        for line in section["lines"]:
            print(line)
        print()
    if auto_section:
        for line in auto_section:
            print(line)
    sys.exit(0)
'@

        $previousFilters = $env:CX_REC_FILTERS
        $previousSearch = $env:CX_REC_SEARCHES
        try {
            if ($RecommendationsFilter) {
                $env:CX_REC_FILTERS = ($RecommendationsFilter | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() }) -join "`n"
            } else {
                Remove-Item Env:CX_REC_FILTERS -ErrorAction SilentlyContinue
            }
            if ($RecommendationsSearch) {
                $env:CX_REC_SEARCHES = ($RecommendationsSearch | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() }) -join "`n"
            } else {
                Remove-Item Env:CX_REC_SEARCHES -ErrorAction SilentlyContinue
            }
            & $pythonCmd.Path -c $pythonCode -- $target $proj
            if (($RecommendationsFilter -and $RecommendationsFilter.Count -gt 0) -or ($RecommendationsSearch -and $RecommendationsSearch.Count -gt 0)) {
                return
            }
        } finally {
            if ($null -ne $previousFilters) {
                $env:CX_REC_FILTERS = $previousFilters
            } else {
                Remove-Item Env:CX_REC_FILTERS -ErrorAction SilentlyContinue
            }
            if ($null -ne $previousSearch) {
                $env:CX_REC_SEARCHES = $previousSearch
            } else {
                Remove-Item Env:CX_REC_SEARCHES -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Warning 'python is required to summarize recommendations; showing raw file only.'
    }

    Get-Content $target
    return
}

function Log-Relations {
    $file = Join-Path $cxHome 'relations'
    $combos = @{}
    if (Test-Path $file) {
        Get-Content $file | ForEach-Object {
            if ($_ -match '^(.*)=(\d+)$') { $combos[$matches[1]] = [int]$matches[2] }
        }
    }
    $limit = 9
    $syms = $sessionSyms.Keys | Select-Object -First $limit
    for ($i=0; $i -lt $syms.Count - 1; $i++) {
        for ($j=$i+1; $j -lt $syms.Count; $j++) {
            $combo = "$($syms[$i]),$($syms[$j])"
            $combos[$combo] = ($combos[$combo] + 1)
        }
    }
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
    $dir = Join-Path $cxHome 'grid'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $proj = Split-Path (Get-Location) -Leaf
    $file = Join-Path $dir "$proj.grid"
    $grid = @{}
    if (Test-Path $file) {
        Get-Content $file | ForEach-Object {
            if ($_ -match '^(.*?):(.*)$') {
                $center = $matches[1]
                $neighbors = @{}
                $matches[2].Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
                    if ($_ -match '^(.*)=(\d+)$') { $neighbors[$matches[1]] = [int]$matches[2] }
                }
                $grid[$center] = $neighbors
            }
        }
    }
    $limit = 9
    $syms = $sessionSyms.Keys | Select-Object -First $limit
    foreach ($center in $syms) {
        if (-not $grid.ContainsKey($center)) { $grid[$center] = @{} }
        foreach ($n in $syms) {
            if ($n -eq $center) { continue }
            if ($grid[$center].ContainsKey($n)) { $grid[$center][$n]++ } else { $grid[$center][$n] = 1 }
        }
        $top = $grid[$center].GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 8
        $trim = @{}
        foreach ($entry in $top) { $trim[$entry.Key] = $entry.Value }
        $grid[$center] = $trim
    }
    $grid.Keys | ForEach-Object {
        $center = $_
        $neighbors = $grid[$center].GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } -join ' '
        "$center:$neighbors"
    } | Set-Content $file
}

function Relation-Report {
    $file = Join-Path $cxHome 'relations'
    if (-not (Test-Path $file)) { return }
    [Console]::Error.WriteLine('Top symbol pairs:')
    Get-Content $file | Where-Object { ($_ -split '=')[0].Split(',').Count -eq 2 } | Sort-Object { ($_ -split '=')[1] } -Descending | Select-Object -First 5 | ForEach-Object { [Console]::Error.WriteLine($_) }
    [Console]::Error.WriteLine('Top symbol triads:')
    Get-Content $file | Where-Object { ($_ -split '=')[0].Split(',').Count -eq 3 } | Sort-Object { ($_ -split '=')[1] } -Descending | Select-Object -First 5 | ForEach-Object { [Console]::Error.WriteLine($_) }
}

if (-not $model) {
    if ($env:CX_MODEL) { $model = $env:CX_MODEL } else { $model = 'gpt-3.5-turbo' }
}
if (-not $PSBoundParameters.ContainsKey('temperature')) {
    if ($env:CX_TEMP) { $temperature = [double]$env:CX_TEMP } else { $temperature = 0.7 }
}

$cliValues = @{}
foreach ($key in @('role','goal','cons','reason','out','raw','model','temperature')) {
    if ($PSBoundParameters.ContainsKey($key)) {
        $cliValues[$key] = $PSBoundParameters[$key]
    }
}

$envMap = @{}
if ($env:CX_MODEL) { $envMap['model'] = [pscustomobject]@{ Name = 'CX_MODEL'; Value = $env:CX_MODEL } }
if ($env:CX_TEMP) { $envMap['temp'] = [pscustomobject]@{ Name = 'CX_TEMP'; Value = $env:CX_TEMP } }

$resolved = @{
    role = $role
    goal = $goal
    cons = $cons
    reason = $reason
    out = $out
    raw = $raw
    topic = ''
    model = $model
    temp = $temperature
}

$validationRequested = $ConfigValidate -or ($ConfigValidateScope -and $ConfigValidateScope.Trim().Length -gt 0)
if ($validationRequested) {
    $scopeSpec = if ($ConfigValidateScope) { $ConfigValidateScope.Trim() } else { '' }
    $errorCount = 0
    Show-ConfigValidation -Scope $scopeSpec -History $script:ConfigHistory -Unknown $script:ConfigUnknown -CxHome $cxHome -ProjectRoot $projectRoot -ProjectCx $projectCx -CustomPath $ConfigPath -ErrorCount ([ref]$errorCount)
    if ($errorCount -gt 0) { exit 1 } else { return }
}

if ($configEnvRequested) {
    try {
        Show-ConfigEnv -Resolved $resolved -Format $configEnvFormat
    } catch {
        Write-Error $_
        exit 1
    }
    return
}

if ($configExportRequested) {
    $exportPath = $null
    if ($ConfigExportPath -and $ConfigExportPath.Trim().Length -gt 0) {
        $exportPath = Normalize-ConfigPath -Path $ConfigExportPath -Base $projectRoot
    }
    Write-ConfigExport -OutputPath $exportPath -SearchPaths $configPaths -Resolved $resolved -CliValues $cliValues -LastMap $script:ConfigLast -EnvMap $envMap -ProjectRoot $projectRoot
    return
}

if ($showConfig) {
    Show-ConfigReport -CxHome $cxHome -ProjectRoot (Get-Location).Path -SearchPaths $configPaths -History $script:ConfigHistory -LastMap $script:ConfigLast -CliValues $cliValues -Resolved $resolved
    return
}

if ($showConfigWhichRequested) {
    Show-ConfigWhich -Keys $ConfigWhich -LastMap $script:ConfigLast -CliValues $cliValues -Resolved $resolved -EnvMap $envMap
    return
}

if ($showConfigDiffRequested) {
    $defaultLeft = 'project'
    $defaultRight = 'user'
    $leftSpec = $defaultLeft
    $rightSpec = $defaultRight
    if ($ConfigDiffScopes) {
        $scopes = $ConfigDiffScopes.Trim()
        if ($scopes -match '^[A-Za-z]:[\\/]') {
            $rightSpec = $scopes
        } elseif ($scopes -match ':') {
            $parts = $scopes -split ':', 2
            if ($parts.Length -gt 0 -and $parts[0]) { $leftSpec = $parts[0].Trim() } else { $leftSpec = $defaultLeft }
            if ($parts.Length -gt 1 -and $parts[1]) { $rightSpec = $parts[1].Trim() } else { $rightSpec = $defaultRight }
        } else {
            $rightSpec = $scopes
        }
    }
    if (-not $leftSpec) { $leftSpec = $defaultLeft }
    if (-not $rightSpec) { $rightSpec = $defaultRight }

    $leftTarget = Resolve-ConfigTarget -Scope $leftSpec -CxHome $cxHome -ProjectCx $projectCx -CustomPath $null -ProjectRoot $projectRoot
    if (-not $leftTarget -or -not $leftTarget.Path) {
        Write-Error "Unable to resolve config scope '$leftSpec'."
        exit 1
    }
    $rightTarget = Resolve-ConfigTarget -Scope $rightSpec -CxHome $cxHome -ProjectCx $projectCx -CustomPath $null -ProjectRoot $projectRoot
    if (-not $rightTarget -or -not $rightTarget.Path) {
        Write-Error "Unable to resolve config scope '$rightSpec'."
        exit 1
    }

    Show-ConfigDiff -Left $leftTarget -Right $rightTarget
    return
}

if ($ShowConfigList) {
    Show-ConfigSources -History $script:ConfigHistory
    return
}

if ($performedConfigUpdate -and -not $role -and -not $goal -and -not $showConfig -and -not $showConfigDiffRequested -and -not $ShowConfigList -and -not $showConfigWhichRequested -and -not $configExportRequested -and -not $configEnvRequested -and -not $showConfigTemplateRequested -and -not $EstimateSummary -and -not $Recommendations) {
    return
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

Load-Dict (Join-Path $cxHome 'dict')
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

if (-not $role -or -not $goal) {
    throw 'role and goal are required'
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

$compPrompt = "Follow these instructions exactly.`n::r $roleOrig`n::g $goalOrig"
if ($consOrig) { $compPrompt += "`n::c $consOrig" }
if ($reasonOrig) { $compPrompt += "`n::s $reasonOrig" }
if ($outOrig) { $compPrompt += "`n::o $outOrig" }

if ($estimate) {
    $dry = $true
    $summaryRaw = $null
    $summaryCompressed = $null
    $fieldData = @()

    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $pythonCmd) { $pythonCmd = Get-Command python -ErrorAction SilentlyContinue }
    if ($pythonCmd) {
        $envAssignments = @(
            @{ Key = 'CX_PROMPT_RAW'; Value = $prompt },
            @{ Key = 'CX_PROMPT_COMP'; Value = $compPrompt },
            @{ Key = 'CX_ROLE_RAW'; Value = $role },
            @{ Key = 'CX_ROLE_COMP'; Value = $roleOrig },
            @{ Key = 'CX_GOAL_RAW'; Value = $goal },
            @{ Key = 'CX_GOAL_COMP'; Value = $goalOrig },
            @{ Key = 'CX_CONS_RAW'; Value = $cons },
            @{ Key = 'CX_CONS_COMP'; Value = $consOrig },
            @{ Key = 'CX_REASON_RAW'; Value = $reason },
            @{ Key = 'CX_REASON_COMP'; Value = $reasonOrig },
            @{ Key = 'CX_OUT_RAW'; Value = $out },
            @{ Key = 'CX_OUT_COMP'; Value = $outOrig }
        )
        if ($model) {
            $envAssignments += @{ Key = 'CX_ESTIMATE_MODEL'; Value = $model }
        }

        $previousAssignments = @{}
        foreach ($assignment in $envAssignments) {
            $key = $assignment.Key
            $previousAssignments[$key] = [System.Environment]::GetEnvironmentVariable($key)
            [System.Environment]::SetEnvironmentVariable($key, [string]$assignment.Value)
        }

        $pythonCode = @'
import json
import os

model = os.environ.get("CX_ESTIMATE_MODEL") or os.environ.get("MODEL") or "gpt-3.5-turbo"
raw_prompt = os.environ.get("CX_PROMPT_RAW", "")
comp_prompt = os.environ.get("CX_PROMPT_COMP", "")
fields = [
    ("role", os.environ.get("CX_ROLE_RAW", ""), os.environ.get("CX_ROLE_COMP", "")),
    ("goal", os.environ.get("CX_GOAL_RAW", ""), os.environ.get("CX_GOAL_COMP", "")),
    ("cons", os.environ.get("CX_CONS_RAW", ""), os.environ.get("CX_CONS_COMP", "")),
    ("reason", os.environ.get("CX_REASON_RAW", ""), os.environ.get("CX_REASON_COMP", "")),
    ("out", os.environ.get("CX_OUT_RAW", ""), os.environ.get("CX_OUT_COMP", "")),
]

try:
    import tiktoken
    enc = tiktoken.encoding_for_model(model)

    def count(text: str) -> int:
        return len(enc.encode(text))
except Exception:

    def count(text: str) -> int:
        return len(text.split())

data = {
    "summary": {
        "raw": count(raw_prompt),
        "compressed": count(comp_prompt),
    },
    "fields": [],
}

for name, raw, comp in fields:
    if not raw and not comp:
        continue
    data["fields"].append({
        "name": name,
        "raw": count(raw),
        "compressed": count(comp),
    })

print(json.dumps(data))
'@

        try {
            $json = & $pythonCmd.Path -c $pythonCode
            if ($LASTEXITCODE -eq 0 -and $json) {
                $parsed = $json | ConvertFrom-Json
                if ($parsed.summary) {
                    $summaryRaw = [int]$parsed.summary.raw
                    $summaryCompressed = [int]$parsed.summary.compressed
                }
                if ($parsed.fields) {
                    foreach ($entry in $parsed.fields) {
                        $fieldData += [pscustomobject]@{
                            Name = $entry.name
                            Raw = [int]$entry.raw
                            Compressed = [int]$entry.compressed
                        }
                    }
                }
            }
        } catch {
            # fall back to word counts below
        } finally {
            foreach ($assignment in $envAssignments) {
                $key = $assignment.Key
                $original = $previousAssignments[$key]
                [System.Environment]::SetEnvironmentVariable($key, $original)
            }
        }
    }

    if (-not $summaryRaw) { $summaryRaw = ([regex]::Matches([string]$prompt, '\S+')).Count }
    if (-not $summaryCompressed) { $summaryCompressed = ([regex]::Matches([string]$compPrompt, '\S+')).Count }
    if (-not $fieldData) {
        $fields = @(
            [pscustomobject]@{ Name = 'role'; Raw = ([regex]::Matches([string]$role, '\S+')).Count; Compressed = ([regex]::Matches([string]$roleOrig, '\S+')).Count },
            [pscustomobject]@{ Name = 'goal'; Raw = ([regex]::Matches([string]$goal, '\S+')).Count; Compressed = ([regex]::Matches([string]$goalOrig, '\S+')).Count }
        )
        if ($cons -or $consOrig) {
            $fields += [pscustomobject]@{ Name = 'cons'; Raw = ([regex]::Matches([string]$cons, '\S+')).Count; Compressed = ([regex]::Matches([string]$consOrig, '\S+')).Count }
        }
        if ($reason -or $reasonOrig) {
            $fields += [pscustomobject]@{ Name = 'reason'; Raw = ([regex]::Matches([string]$reason, '\S+')).Count; Compressed = ([regex]::Matches([string]$reasonOrig, '\S+')).Count }
        }
        if ($out -or $outOrig) {
            $fields += [pscustomobject]@{ Name = 'out'; Raw = ([regex]::Matches([string]$out, '\S+')).Count; Compressed = ([regex]::Matches([string]$outOrig, '\S+')).Count }
        }
        $fieldData = $fields
    }

    if ($summaryRaw -gt 0) { $savings = [int](100 * ($summaryRaw - $summaryCompressed) / $summaryRaw) } else { $savings = 0 }
    $msg = "raw=$summaryRaw compressed=$summaryCompressed savings=${savings}%"
    [Console]::Error.WriteLine($msg)
    $proj = Split-Path (Get-Location) -Leaf
    $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
    $metricsDir = Join-Path $cxHome 'metrics'
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    $metricsPath = Join-Path $metricsDir "$proj.log"
    Add-Content $metricsPath "[$timestamp] $msg"

    if ($EstimateDetail -and $fieldData) {
        foreach ($entry in $fieldData) {
            $fieldSavings = 0
            if ($entry.Raw -gt 0) {
                $fieldSavings = [int](100 * ($entry.Raw - $entry.Compressed) / $entry.Raw)
            }
            $detail = "field=$($entry.Name) raw=$($entry.Raw) compressed=$($entry.Compressed) savings=${fieldSavings}%"
            [Console]::Error.WriteLine($detail)
            Add-Content $metricsPath "[$timestamp] $detail"
        }
    }
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
        $dir = Join-Path $cxHome 'offline'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
        $path = Join-Path $dir "$timestamp.txt"
        Set-Content $path $prompt
        [Console]::Error.WriteLine("Saved prompt offline to $path")
    } else {
        $key = $env:OPENAI_API_KEY
        $body = @{model=$model; temperature=$temperature; messages=@(@{role='user'; content=$prompt})} | ConvertTo-Json -Depth 5
        try {
            $resp = Invoke-RestMethod -Uri https://api.openai.com/v1/chat/completions -Method Post -Headers @{Authorization="Bearer $key"} -Body $body -ContentType 'application/json'
            $resp.choices[0].message.content
        } catch {
            $dir = Join-Path $cxHome 'offline'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHHmmZ')
            $path = Join-Path $dir "$timestamp.txt"
            Set-Content $path $prompt
            [Console]::Error.WriteLine("API call failed; saved prompt offline to $path")
        }
    }
}
