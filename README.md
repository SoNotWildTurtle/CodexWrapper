# CodexWrapper

Wrapper for codex.

## Install
Linux/macOS:
```
./install.sh
```
Windows PowerShell:
```
pwsh ./install.ps1
# or if PowerShell Core isn't available
powershell -File install.ps1
```
If neither `pwsh` nor `powershell` is present, install PowerShell from
[Microsoft's documentation](https://learn.microsoft.com/powershell/).
These installers place the Bash wrappers (`cx`, `cx5`) or PowerShell scripts (`Invoke-Codex.ps1`, `Compress-CX5.ps1`) in a `bin` directory
under your home folder and seed `~/.cx` with a starter dictionary, metrics folder, and decompression spec.

### Install into an active virtualenv (WSL/Kali)
If you're running under WSL or Kali and want the tools scoped to a Python virtualenv, activate it and run:

```
python3 -m venv .venv
source .venv/bin/activate
./install_venv.sh
```

This drops `cx` and `cx5` into the virtualenv's `bin` and seeds `.cx` assets inside the environment so the wrapper can act as the API layer between Codex and the user.

## Usage

### Expand to a full prompt
```
cx role=@dev goal='demo' cons='^mm,^st{3}' reason='^ts' out='code' --estimate
# or in PowerShell
Invoke-Codex role=@dev goal='demo' cons='^mm,^st{3}' reason='^ts' out='code' --estimate
```
`role=` and `goal=` are required. Optional `cons=`, `reason=`, and `out=` populate constraint, reasoning, and output blocks.

### Compress to CX5 format
```
cx5 role='You are a seasoned developer.' goal='demo' \
    cons='Use minimal tokens; compress phrasing, keep meaning.,Provide at most 3 bullet points.' \
    reason='Think step-by-step and verify each step.' out='code'
# or in PowerShell
Compress-CX5 role='You are a seasoned developer.' goal='demo' \
    cons='Use minimal tokens; compress phrasing, keep meaning.,Provide at most 3 bullet points.' \
    reason='Think step-by-step and verify each step.' out='code'
```
Both emit a single-line `CX5|...` string using dictionary entries where possible.

Flags:

- `--dry` preview the expanded prompt without sending it.
- `--estimate` report raw vs compressed token counts and log `[ISO timestamp] raw=X compressed=Y savings=Z%` under `~/.cx/metrics/<project>.log`. This flag implies `--dry`.
- `--help` show usage.

The dictionary accepts both symbolic tags like `@dev` and numeric macros such as `#42` that expand to preset bundles.
When a plain phrase repeats, `cx` will offer to mint a new `@domain` tag so it can be reused in future prompts.
