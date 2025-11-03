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

Set `CX_HOME` or `CX_BIN_DIR` before running the installer if you want the Codex data directory or wrapper binaries somewhere other than the defaults (`~/.cx` and `~/.local/bin`). During installation the script verifies `python3`/`pip`, installs the `tiktoken` and `openai` Python modules, copies the Bash wrappers (`cx`, `cx5`) or PowerShell scripts (`Invoke-Codex.ps1`, `Compress-CX5.ps1`) into `${CX_BIN_DIR:-~/.local/bin}`, and seeds `${CX_HOME:-~/.cx}` with a starter dictionary plus metrics, context, offline, responses, prompts, topics, neuron-grid, audit, inspect, hotspots, stale, format, depscan, improve, additive, enhance, backlog, modules, and relations assets along with the decompression spec. The installers also drop reusable environment helpers at `${CX_HOME}/cx-env.sh` and `${CX_HOME}/cx-env.ps1`.

After installing, add the helper to your shell profile so PATH updates and environment defaults load automatically:

```bash
source ~/.cx/cx-env.sh    # Bash/zsh
```

```powershell
. $env:CX_HOME/cx-env.ps1 # PowerShell
```

If you store an API key in `~/.cx/openai_api_key`, the helper exports it so wrappers can call the OpenAI API without prompting.

## Normalize architecture and methodology artifacts

Every engagement should start with two synchronized documents before automation runs, and they should be refreshed whenever new automation lands so the latest recommendations are captured:

- `architecture_overview.md` – captures imports, key functions, module responsibilities, integration points, requirements, and the execution flow for the codebase.
- `organizational_methodology.md` – the companion playbook that catalogues imports, functions, requirements, module behavior, integration seams, execution paths, and a curated set of recommendations (immediate, foundational, exploratory) for the current project; refresh it before automation so the improvement backlog is rooted in the latest discovery work.
- `recommendations.md` – the live backlog of improvement ideas with sub-notes, automation hooks, and status tracking; review it (or run `cx --recommendations`) before each sweep so the backlog grows faster than completion throughput. Every `cx --improve` run now appends a new entry to the `## Auto-generated Summaries` section so discovery signals accumulate automatically.
- `goals.md` – track a standing **Organizational Methodology Goal** so every engagement explicitly documents imports, functions, requirements, module responsibilities, integration seams, execution flow, and curated recommendations before enhancements run.

Treat drafting or refreshing these artifacts as a standing goal (see `goals.md`) so CodexWrapper always operates from a shared understanding when generating improvements. Record notable discoveries in both playbooks after each sweep so future contributors inherit up-to-date guidance and prioritized recommendations. Before running automation, confirm the **Methodology Summary** section inside `organizational_methodology.md` enumerates the imports, functions, requirements, module responsibilities, integration seams, execution path, and recommendation categories; that published summary is the go/no-go gate for enhancement runs.

### Install into an active virtualenv (WSL/Kali)

If you're running under WSL or Kali and want the tools scoped to a Python virtualenv, activate it and run:

```
python3 -m venv .venv
source .venv/bin/activate
./install_venv.sh
```

This drops `cx` and `cx5` into the virtualenv's `bin` (or `Scripts/` on Windows-style environments), installs the required Python modules locally, and seeds `.cx` assets plus `cx-env.sh` inside the environment so the wrapper can act as the API layer between Codex and the user. Source `$VIRTUAL_ENV/.cx/cx-env.sh` after activation to expose the wrappers and defaults.

## Usage

The wrapper resolves the repository root (preferring `git` metadata and common build manifests) before it runs, so logs, metrics,
and automation all target the full project even if you invoke `cx` from a nested directory.

### Expand to a full prompt

```
cx role=@dev goal='demo' cons='^mm,^st{3}' reason='^ts' out='code' --estimate
# or in PowerShell
Invoke-Codex role=@dev goal='demo' cons='^mm,^st{3}' reason='^ts' out='code' --estimate
```

`role=` and `goal=` are required. Optional `cons=`, `reason=`, and `out=` populate constraint, reasoning, and output blocks. Use `topic=foo,bar` to label the run for topic tracking. Set `model=gpt-4o-mini` (or export `CX_MODEL`) to override the default `gpt-3.5-turbo` model. Adjust `temp=0.7` (or export `CX_TEMP`) to tune randomness.

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

### Review the dictionary

```bash
cx --dict
```

Prints the combined global and project dictionaries with usage counts so you can monitor symbol growth.

### Diagnose the Codex environment

```bash
cx --doctor
```

Runs a quick health check before automation. The wrapper verifies core commands (`python3`, `curl`, `git`), confirms that `python3 -m pip` is available, checks for the `tiktoken` and `openai` Python modules, validates that `${CX_HOME:-~/.cx}` is writable, and reports whether `OPENAI_API_KEY` is already exported. Results are written to `${CX_HOME:-~/.cx}/doctor/<project>-<timestamp>.md` (with a `-latest.md` copy) so you can diff environment changes over time. Each line is tagged with `[OK]`, `[WARN]`, or `[ERROR]`, making it easy to fix missing prerequisites before running `cx --start`, `--improve`, or other automation suites.

### Surface module weak points

```bash
cx --weakpoints
```

Highlights the riskiest areas discovered by the module analyzer without generating the full Markdown report. The command emits a Markdown summary to `${CX_HOME:-~/.cx}/weakpoints/<project>-<timestamp>.md` (and stores the machine-readable snapshot alongside it) showing severity, scores, metrics (LOC, TODO/FIXME counts, largest file size), and the mitigation tasks already tracked in the module plan. Use `CX_WEAKPOINT_LIMIT=10` to expand the number of entries shown. Review the summary to decide whether to run `cx --modules=apply` for automated fixes or `cx --additive` for a broader improvement sweep.

### Run a baseline repository scan

```bash
cx --baseline
```

Runs a starter suite that lints the tree (adding `--fix` if you pass it), builds audit and inspection reports, and, when git
history is available, generates hotspot and stale-file analyses so you have actionable logs from a single command.

### Bootstrap a project and run auto-detected tasks

```bash
cx --start
```

Runs the baseline automation and then executes language-aware project tasks. The wrapper surfaces a git status summary; installs
Node dependencies when `package.json` is present and modules are missing before running `npm`/`yarn`/`pnpm`/`bun` lint and test
scripts; installs Ruby gems with Bundler and runs `bundle exec rspec` or rake targets when they are available; installs PHP
dependencies via Composer and runs its `test` script or `vendor/bin/phpunit`; installs Elixir dependencies with `mix deps.get`
and runs `mix test` when a `test/` folder is present; installs Python dependencies via Poetry, Pipenv, or pip heuristics before
executing `tox` or `pytest`; installs git hooks with `pre-commit install --install-hooks` (when a repository is detected) and runs
`pre-commit run --all-files`; executes common `just` recipes (`just install`/`just lint`/`just test`) when a `Justfile` and the CLI are present; runs Taskfile
targets (`task install`/`task lint`/`task test`) when go-task is available; builds and tests Bazel workspaces with `bazel`/`bazelisk`/`./bazelw`; warms Pants projects by running `pants dependencies`, `pants lint`, and `pants test` when configuration files are present; checks `make lint`/`make test`; runs `.NET` projects through `dotnet restore` and `dotnet test`;
warms Maven dependencies and runs `mvn test`; executes Gradle `test`; primes Haskell projects by running `stack build --only-
dependencies` plus `stack test` (or `cabal v2-build --only-dependencies` / `cabal v2-test` when Cabal files exist); resolves
Swift packages before running `swift test`; warms Scala builds with `sbt update` and runs `sbt test`; fetches Flutter
dependencies via `flutter pub get` before `flutter test`; pulls Dart packages with `dart pub get` and runs `dart test` when
Flutter tooling is absent; configures and builds CMake projects with `cmake -S . -B ${CX_CMAKE_BUILD_DIR:-build}` followed by
`cmake --build`, and runs `ctest` when a CTest manifest is present; and invokes `go test ./...` or `cargo test` when Go or Rust
projects are detected.
Override the default build directory or pass extra flags by exporting `CX_CMAKE_BUILD_DIR`, `CX_CMAKE_CONFIGURE_ARGS`,
`CX_CMAKE_BUILD_ARGS`, `CX_CMAKE_BUILD_TARGET`, or `CX_CTEST_ARGS` before running `cx --start`. Adjust Bazel automation with `CX_START_BAZEL_BUILD_ARGS`, `CX_START_BAZEL_BUILD_TARGETS`, `CX_START_BAZEL_TEST_ARGS`, or `CX_START_BAZEL_TEST_TARGETS`, and tune Pants workflows with `CX_START_PANTS_DEPS_ARGS`, `CX_START_PANTS_DEPS_TARGETS`, `CX_START_PANTS_LINT_ARGS`, `CX_START_PANTS_LINT_TARGETS`, `CX_START_PANTS_TEST_ARGS`, or `CX_START_PANTS_TEST_TARGETS`.
Set `CX_START_SKIP_INSTALL=1` to skip dependency installation attempts (including `pre-commit install`, `just install`, `task install`, and Bazel/Pants dependency warmups) and `CX_START_SKIP_TESTS=1` to skip the test and lint commands if
you only want setup reports.

Need to bolt on custom automation? Export newline-delimited shell commands via `CX_START_EXTRA_INSTALL`,
`CX_START_EXTRA_TEST`, or `CX_START_EXTRA_STEPS`. The first two run after the built-in install/test actions (and honor the skip
flags) while the general list executes at the end regardless of skip settings. Each command is executed in its own `bash -lc`
subshell so you can reuse aliases and environment variables.

### Run available code formatters

```bash
cx --format
```

Runs the formatter suite, calling tools such as `shfmt`, `black`, `isort`, `ruff`, `goimports`, `gofmt`, `cargo fmt`/`rustfmt`, `prettier`, `terraform fmt`, and `clang-format` when they are installed and relevant files are present. Each invocation appends output to `${CX_HOME:-~/.cx}/format/<project>.log`, making it easy to review which formatters ran or were skipped. The improvement and enhancement workflows automatically trigger this sweep, so running it manually is helpful when you want formatting-only cleanups.

### Scan for outdated dependencies

```bash
cx --depscan
```

Detects common Node and Python dependency managers, runs their non-destructive "outdated" checks (for example `npm outdated`, `yarn outdated`, `pnpm outdated`, `bun outdated`, `poetry show --outdated`, `pipenv run pip list --outdated`, or `python3 -m pip list --outdated`), and appends the results to `${CX_HOME:-~/.cx}/depscan/<project>.log`. Use the log to queue dependency upgrades or security patches. The comprehensive `--improve` and `--enhance` workflows call this scan automatically so plans always include the latest package insights.

### Run a comprehensive improvement pass

```bash
cx --improve
```

Runs the baseline automation with autofixes enabled, invokes the formatter suite, performs the dependency scan, and then executes the project bootstrap actions with installs and tests turned on by default so gaps surface early. Set `CX_IMPROVE_SKIP_INSTALL=1` or `CX_IMPROVE_SKIP_TESTS=1` to bypass those phases when needed, and export newline-delimited commands via `CX_IMPROVE_EXTRA` to run additional cleanup or verification steps after the built-in automation. After completion the wrapper prints a git status summary, shows a `git diff --stat`, and appends the results to `${CX_HOME:-~/.cx}/improve/<project>.log` while recording formatter output in `${CX_HOME:-~/.cx}/format/<project>.log` and dependency findings in `${CX_HOME:-~/.cx}/depscan/<project>.log` for later review.

Each `--improve` sweep also appends a timestamped entry to the `## Auto-generated Summaries` section of `recommendations.md`, capturing the outcome (success or follow-up required) and pointing to the freshly written improve log. This keeps the backlog growing automatically and satisfies recommendation R-002 without relying on manual edits.

### Generate an additive improvement plan

```bash
cx --additive
```

Performs the full improvement sweep (baseline with fixes, formatter run, dependency scan, and project automation) and then collates the latest signals into `${CX_HOME:-~/.cx}/additive/<project>-<timestamp>.md`. The Markdown report highlights high-priority follow-ups, embeds module-building suggestions derived from `cx --modules`, references the freshest automation logs, and captures the latest inspection excerpt so you can apply additive enhancements immediately. Each plan now includes a **Quick module tasks** section distilled from the machine-readable module analysis plus a log reference to the JSON snapshot written under `${CX_HOME:-~/.cx}/modules`, making it easy to hand actionable scaffolding items to teammates or downstream tooling. Run `cx --additive=apply` to execute the scaffolding helper as part of the sweep (embedding the scaffold summary directly in the module section), or `cx --additive=full` to apply scaffolding and refresh the post-scaffold module analysis. Set `CX_ADDITIVE_MODE` to `plan`, `apply`, or `full` to change the default behaviour; the legacy `CX_ADDITIVE_APPLY_SCAFFOLD=1` flag continues to trigger scaffolding when you stay on `--additive`.

Additive runs now enforce a regression guard on module opportunities. The wrapper retains `${CX_HOME:-~/.cx}/modules/<project>-latest.json` from the previous sweep and fails the run if new gaps appear—such as extra packages missing `__init__.py`, fresh components without tests, or modules that just grew beyond the "heavy" threshold. Export `CX_MODULE_ALLOW_REGRESSION=1` to acknowledge the regression after manual review; the additive Markdown still enumerates the newly detected gaps so you can resolve them quickly.

### Generate an automated enhancement plan

```bash
cx --enhance
```

Executes the same improvement sweep as `--improve` (respecting `CX_IMPROVE_SKIP_INSTALL`, `CX_IMPROVE_SKIP_TESTS`, and `CX_IMPROVE_EXTRA`) and then collates the latest automation signals into `${CX_HOME:-~/.cx}/enhance/<project>-<timestamp>.md`. The Markdown report captures automation opportunities and gaps from `cx --locate`, summarizes recommended follow-up actions, and embeds excerpts from the most recent audit, inspect, hotspot, stale, format, depscan, and improve logs so you can triage concrete fixes immediately.

### Build an actionable backlog from automation signals

```bash
cx --backlog
```

Runs the baseline analyses (lint, audit, inspect, hotspot, stale) and then writes a backlog report to `${CX_HOME:-~/.cx}/backlog/<project>-<timestamp>.md`. The Markdown summary bubbles up immediate follow-ups—TODO/FIXME markers, churn-heavy files, stale code, dependency scan results, and formatter skips—while embedding excerpts from the source logs so you can jump directly into fixes. Use it to prioritize automated cleanups before launching deeper refactors.

### Analyze module-building opportunities

```bash
cx --modules
```

Generates `${CX_HOME:-~/.cx}/modules/<project>-<timestamp>.md`, summarizing detected Python packages, Node/TypeScript areas, Go packages, and Rust modules. The report flags directories that need `__init__.py` files, highlights components without tests, calls out oversized modules ready to be split, and recommends where to scaffold new additive modules so the codebase grows with clear boundaries. Pass `--modules=json` to write the raw analysis as `${CX_HOME:-~/.cx}/modules/<project>-<timestamp>.json`, or `--modules=apply` to run the scaffolding helper in-place while capturing a Markdown summary alongside a JSON snapshot. The additive workflow automatically reuses that JSON snapshot to surface the **Quick module tasks** list; tune `CX_MODULE_SUMMARY_LIMIT` to control how many items are surfaced per category.

Module sweeps also produce decision guidance that scores each component based on missing package files, absent tests, surface area, and directory breadth. Opportunities are grouped into **Immediate module work**, **Plan soon**, or **Monitor for growth** so teams can balance quick wins against longer-term refactors while reviewing the Markdown or JSON output.

In addition to priority buckets, every run now records module **weak points** by blending line counts, TODO/FIXME markers, and oversize-file heuristics. The Markdown report surfaces these high-risk components in a dedicated section (and the JSON snapshot mirrors the structure), helping you spot brittle modules—like large untested areas or TODO-heavy directories—before they snowball into production issues. Regression checks fail fast when new weak points appear, keeping the improvement loop focused on shoring up fragile areas.

Module sweeps also compare each fresh JSON snapshot with the `${project}-latest.json` baseline. If new missing `__init__.py` files, untested areas, or heavy modules are detected, `cx --modules` exits non-zero to prevent regressions sneaking into the backlog. When you intentionally accept the change (for example, while scaffolding a large refactor), rerun with `CX_MODULE_ALLOW_REGRESSION=1` to update the baseline while still printing the offending categories.

### Apply scaffolding placeholders

```bash
cx --scaffold
```

Creates missing `__init__.py` files and placeholder test suites for the gaps reported by `cx --modules`, covering Python, Node/TypeScript, Go, and Rust code. Each run logs its actions to `${CX_HOME:-~/.cx}/scaffold/<project>-<timestamp>.md` (alongside a JSON snapshot) so you can review and replace the TODO stubs with real tests.

### Self-host the wrapper inside a sandbox

Run the improvement sweep from the repository root to exercise every automated analysis against the wrapper itself:

```bash
./cx --improve
```

For a complete sandbox session:

1. Clone the repository into an isolated workspace (a throwaway container, VM, or `git worktree`).
2. Run `./install.sh` (or `./install_venv.sh` inside an activated virtual environment) so the wrappers, starter dictionaries, and logging directories are available.
3. Export any overrides you want to test:
   - `CX_HOME=/tmp/cx-sandbox` to capture logs outside your main profile.
   - `CX_IMPROVE_SKIP_INSTALL=1` or `CX_IMPROVE_SKIP_TESTS=1` to focus on a particular slice of automation.
   - `CX_IMPROVE_EXTRA=$'pytest -q\npre-commit run --all-files'` to append custom checks.
4. Execute `./cx --improve` and let the sweep finish.
5. Review `${CX_HOME:-~/.cx}/improve/CodexWrapper.log` for git status, diff stats, and any failing steps, then iterate on the findings.

Executing the workflow inside a sandboxed clone (like this development container) drives lint, audit, inspect, hotspot, stale, and start automations across the CodexWrapper sources. The command writes fresh inspection data and git summaries to `${CX_HOME:-~/.cx}/improve/CodexWrapper.log`, making it easy to review how the tool evolves after each conversation. Re-running the sweep whenever new features land keeps the symbolic dictionary, automation coverage, and documentation growing alongside the codebase. Because the logs are stored per project, you can compare successive runs to confirm that each improvement request raises the automation bar.

### Review token-savings history

```bash
cx --metrics
```

Displays the token-savings log under `${CX_HOME:-~/.cx}/metrics/<project>.log` for the current directory.

### Review neuron grid

```bash
cx --grid
```

Prints the weighted neighbor map stored in `${CX_HOME:-~/.cx}/grid/<project>.grid` so you can inspect how symbols cluster around each other.

### Locate the project root and automation coverage

```bash
cx --locate
```

Shows the detected project root, how your current directory relates to it, and which ecosystem automations are ready to run (Node,
Python, Ruby, Java, Bazel, Pants, Nix, Terraform, Ansible, Docker Compose, Helm, Kustomize, Vagrant, pre-commit, Justfile, Taskfile,
etc.) along with any missing prerequisites the wrapper needs before `cx --start` can help.

### Provide default arguments via config files

The wrappers read optional config files to pre-populate arguments so routine prompts stay concise:

- `${CX_HOME:-~/.cx}/config` holds per-user defaults.
- `<project>/.cx/config` overrides those defaults for the current repository.
- Set `CX_CONFIG` to a colon-separated list of additional config files; they are applied last and win on conflicts.

Each config file uses simple `key=value` pairs (ignoring blank lines or `#` comments). Recognized keys include `role`, `goal`,
`cons`/`constraints`, `reason`/`reasons`, `out`/`output`, `raw`, `topic`/`topics`, `model`, and `temp`/`temperature`. Command-line
arguments still take precedence, so you can override defaults for a single run without editing the config files.

Use `cx --config` (or `Invoke-Codex -ShowConfig` on PowerShell) whenever you want to inspect which config files were discovered,
the layered defaults they contributed, any CLI overrides that will win, and the resolved values that will populate the next
prompt. Run `cx --config-list` (PowerShell: `Invoke-Codex -ShowConfigList`) to group the layered defaults by their source files so you can see exactly which scope contributed each key. When you need to compare scopes directly, call `cx --config-diff[=SCOPE[:SCOPE]]` (PowerShell: `Invoke-Codex -ShowConfigDiff [-ConfigDiffScopes SCOPE[:SCOPE]]`) to highlight different values plus keys that only exist on one side before you commit updates.

Need to pinpoint where a specific argument originated? Use `cx --config-which` (PowerShell: `Invoke-Codex -ShowConfigWhich`) to
print, for each requested key, the layered default and its source file, any CLI override, relevant environment variables (such as
`CX_MODEL`/`CX_TEMP`), and the final resolved value that will drive the prompt. Provide a comma-separated list of keys (for example
`--config-which=goal,model`) to focus on targeted entries; without arguments the command enumerates every known key gathered from
defaults and overrides.

Capture the resolved defaults for later review with `cx --config-export`. Without a path it prints a timestamped snapshot (with source annotations) to stdout; provide a destination (for example, `--config-export=./.cx/snapshot.cfg`) to save the same report on disk. PowerShell offers identical behaviour via `Invoke-Codex -ConfigExport` plus an optional `-ConfigExportPath` parameter.

Need to reuse those resolved values in another shell? Run `cx --config-env[=FORMAT]` to emit ready-to-source exports. By default the Bash wrapper prints `export CX_*=` commands; pass `--config-env=powershell` when you prefer `Set-Item Env:` assignments. The PowerShell wrapper exposes the same behaviour via `Invoke-Codex -ConfigEnv [-ConfigEnvFormat FORMAT]`, defaulting to PowerShell output while still capable of generating POSIX-friendly exports for cross-platform automation.

Need to sanity-check your defaults before prompting? Run `cx --config-validate[=scope]` (PowerShell: `Invoke-Codex -ConfigValidate [-ConfigValidateScope scope]`) to scan layered entries for unknown keys, empty required values, and out-of-range temperatures. The report highlights offending sources, warns when scoped files are missing, and exits non-zero when fixes are required so automation can catch misconfigured defaults early.

#### Manage config defaults from the CLI

- `cx --config-set=key=value` writes or updates entries (defaulting to `<project>/.cx/config`). Repeat the flag to set multiple
  keys at once. The PowerShell wrapper mirrors this via `Invoke-Codex -ConfigSet key=value`.
- `cx --config-unset=key` removes a key; when the final entry disappears the wrapper deletes the config file. Use
  `Invoke-Codex -ConfigUnset key` for the PowerShell equivalent.
- Add `--config-scope=user` (PowerShell: `-ConfigScope user`) to target `${CX_HOME:-~/.cx}/config` instead of the project file.
  You can also pass `--config-path=/custom/file` (PowerShell: `-ConfigPath`) to maintain a bespoke config and combine it with
  `--config` to audit the new defaults immediately.
  - `--project-root=/path/to/repo` forces the wrapper to operate on a specific directory without changing where you launched the
    command. PowerShell exposes the same behaviour via `Invoke-Codex -ProjectPath /path/to/repo`.
  - `--select-root` opens a cross-platform folder picker so you can choose the project interactively: macOS runs through
    `osascript`, Linux shells try Zenity/KDialog/Yad when available, and WSL/Windows environments probe `powershell.exe`,
    `pwsh.exe`, `pwsh`, or `powershell` before falling back to Tkinter or a manual prompt. PowerShell mirrors this via
    `Invoke-Codex -SelectProjectRoot`.
  - `cx --config-import=/path/to/file` (PowerShell: `Invoke-Codex -ConfigImport`) merges entries from another config snapshot before applying any `--config-set` overrides so projects can inherit shared templates.
  - `cx --config-reset[=scope]` removes the chosen config file (defaulting to the active scope) so you can clear stale defaults without editing dotfiles by hand. PowerShell mirrors this with `Invoke-Codex -ConfigReset scope`.
  - Config management commands exit after updating the target file unless you also request `--config`/`-ShowConfig`, letting you
    layer defaults without providing `role=`/`goal=` arguments.

Flags:

- `--dry` preview the expanded prompt without sending it.
- `--estimate` report raw vs compressed token counts and log `[ISO timestamp] raw=X compressed=Y savings=Z%` under `${CX_HOME:-~/.cx}/metrics/<project>.log`. Uses the `tiktoken` tokenizer when available and falls back to word counts. This flag implies `--dry`.
- `--estimate-detail` extends `--estimate` by breaking down raw vs compressed token counts per prompt field (role, goal, constraints, reason, output) and appending `[timestamp] field=…` entries to the same metrics log (PowerShell: `Invoke-Codex -EstimateDetail`).
- `--estimate-summary` (PowerShell: `Invoke-Codex -EstimateSummary`) aggregates the metrics log, reporting run counts, weighted/mean savings, best and worst runs, and per-field averages pulled from `--estimate-detail` entries.
- `--offline` skip the API call and save the expanded prompt under `${CX_HOME:-~/.cx}/offline/<project>/<timestamp>.txt` for later use.
- `--replay` send any queued prompts from project subdirectories under `${CX_HOME:-~/.cx}/offline` once an API key is available.
- `--dict` display the combined dictionary with usage counts and exit.
- `--config` show the layered config defaults, highlight active files, surface CLI overrides, and print the resolved values that
  will feed the wrapper before any prompt processing.
- `--config-list` display the layered defaults grouped by source file so you can confirm which scope supplied each key before running prompts.
- `--config-which[=KEYS]` report the layered default, CLI override, relevant environment variables, and resolved value for specific keys (comma-separated) or all known keys when no list is provided. PowerShell exposes the same behaviour via `Invoke-Codex -ShowConfigWhich [-ConfigWhich key1,key2]`.
- `--config-diff[=SCOPE[:SCOPE]]` compare two config scopes (defaulting to project vs user) and report differing values or missing keys. PowerShell exposes the same behaviour via `Invoke-Codex -ShowConfigDiff` with an optional `-ConfigDiffScopes` argument.
- `--config-validate[=SCOPE]` audit layered defaults for unknown keys, empty required values, and invalid temperatures; exits non-zero when issues are found. PowerShell mirrors this via `Invoke-Codex -ConfigValidate [-ConfigValidateScope scope]`.
- `--config-export[=FILE]` capture the resolved defaults (with source annotations) to stdout or a chosen file. PowerShell mirrors this via `Invoke-Codex -ConfigExport [-ConfigExportPath path]`.
- `--config-env[=FORMAT]` emit ready-to-source environment assignments for the resolved defaults. Bash defaults to shell exports; pass `powershell` for `Set-Item` output. PowerShell mirrors this via `Invoke-Codex -ConfigEnv [-ConfigEnvFormat FORMAT]`.
- `--config-template[=SCOPE]` print a ready-to-use config skeleton (with save-path hints) for the requested scope so teams can seed new defaults without hunting for valid keys. PowerShell mirrors this via `Invoke-Codex -ConfigTemplate [-ConfigTemplateScope scope]`.
- `--config-edit[=SCOPE]` open the resolved config file in `$CX_CONFIG_EDITOR`, `$EDITOR`, `$VISUAL`, or a cross-platform fallback (creating a template when the file is missing). PowerShell mirrors this via `Invoke-Codex -ConfigEdit [-ConfigEditScope scope]`.
- `--metrics` show token-savings history for the current project and exit.
- `--recommendations` parse `recommendations.md`, print a status summary (counts of Planned vs Completed), and then emit the full backlog so local or remote agents can triage without opening the repository manually.
- `--grid` display the neuron-style grid of symbol neighbors for the current project and exit.
- `--locate` report the detected project root, current-relative path, automation opportunities, and missing prerequisites.
- `--relations` show the most frequent symbol pairs and triads from `${CX_HOME:-~/.cx}/relations` and exit.
- `--topics` list each topic log in `${CX_HOME:-~/.cx}/topics` with its entry count and exit.
- `--audit` scan tracked files for line counts and TODO/FIXME markers, saving a report under `${CX_HOME:-~/.cx}/audit/<project>.log`.
- `--inspect` generate a repository health report covering file extension breakdowns, hot directories, the largest files, TODO/FIXME counts, merge conflict markers, and debug statements, logging to `${CX_HOME:-~/.cx}/inspect/<project>.log`.
- `--hotspots` analyze git history (default last 90 days) to surface the hottest files, highest-churn directories, and busiest authors, logging to `${CX_HOME:-~/.cx}/hotspots/<project>.log`. Tune the lookback window or list length with `CX_HOTSPOTS_DAYS` and `CX_HOTSPOTS_LIMIT`.
- `--stale` highlight tracked files whose last commit is older than `CX_STALE_MIN_AGE` days (default 180), showing up to `CX_STALE_LIMIT` entries and logging the report to `${CX_HOME:-~/.cx}/stale/<project>.log`.
- `--format` run installed formatters (shfmt, black, isort, ruff, goimports, gofmt, cargo fmt/rustfmt, prettier, terraform fmt, clang-format when available) against tracked files and log the results to `${CX_HOME:-~/.cx}/format/<project>.log`. The `--improve` and `--enhance` workflows invoke this automatically.
- `--depscan` analyze Node (npm/yarn/pnpm/bun) and Python (Poetry/Pipenv/pip) projects for outdated dependencies, appending results to `${CX_HOME:-~/.cx}/depscan/<project>.log`. The `--improve` and `--enhance` workflows invoke this automatically.
  - `--backlog` rerun the baseline suite and emit `${CX_HOME:-~/.cx}/backlog/<project>-<timestamp>.md`, summarizing TODO/FIXME hits, churn-heavy files, stale code, dependency scan notes, formatter skips, and inspection excerpts so you can queue focused follow-up work.
  - `--baseline` run lint, audit, and inspection passes plus git-based hotspot and stale-file reports (when a repository is present) in one shot so you can bootstrap analysis quickly.
  - `--start` run the baseline suite and then perform auto-detected project actions (git status, Node dependency installs and
    scripts across `npm`/`yarn`/`pnpm`/`bun`, Ruby/Bundler setup and tests, PHP/Composer installs and tests, Elixir `mix deps.get`/
    `mix test`, Python dependency installs via Poetry/Pipenv/pip plus `tox`/`pytest`, Bazel builds/tests via `bazel`/`bazelisk`/`./bazelw`, Pants `dependencies`/`lint`/`test` via `pants` or `./pants`, `make lint`/`make test`, `.NET` `dotnet
restore`/`dotnet test`, Maven dependency warmup plus `mvn test`, Gradle `test`, Haskell `stack build --only-dependencies`/`stack
test` or `cabal v2-build --only-dependencies`/`cabal v2-test`, Swift `swift package resolve`/`swift test`, Scala `sbt update`/`sbt
test`, Flutter `flutter pub get`/`flutter test`, Dart `dart pub get`/`dart test` when Flutter isn't present, configure/build CMake
    projects (`cmake -S . -B ${CX_CMAKE_BUILD_DIR:-build}` → `cmake --build`) before running `ctest`, `go test ./...`, and `cargo
test`). Honor `CX_START_SKIP_INSTALL=1` to skip installs and `CX_START_SKIP_TESTS=1` to omit test commands. Customize the CMake
    workflow with `CX_CMAKE_BUILD_DIR`, `CX_CMAKE_CONFIGURE_ARGS`, `CX_CMAKE_BUILD_ARGS`, `CX_CMAKE_BUILD_TARGET`, or `CX_CTEST_ARGS`.
  - `--improve` run baseline automation with autofixes enabled, execute project actions with installs/tests turned on, run any
    newline-delimited commands from `CX_IMPROVE_EXTRA`, and log git status plus diff stats under `${CX_HOME:-~/.cx}/improve/<project>.log` while updating `${CX_HOME:-~/.cx}/format/<project>.log` and `${CX_HOME:-~/.cx}/depscan/<project>.log`.
  - `--enhance` run the improvement sweep and emit a Markdown plan under `${CX_HOME:-~/.cx}/enhance/<project>-<timestamp>.md` that summarizes automation opportunities, missing prerequisites, and the latest audit/inspect/hotspot/stale/improve findings.
  - `--additive[=MODE]` run the improvement sweep and emit `${CX_HOME:-~/.cx}/additive/<project>-<timestamp>.md`, combining follow-up highlights with module-building suggestions. Use `MODE=apply` to execute scaffolding during the sweep (embedding the scaffold summary in the module section) or `MODE=full` to scaffold and then refresh the post-scaffold module analysis. Set `CX_ADDITIVE_MODE` (plan/apply/full) to change the default; legacy `CX_ADDITIVE_APPLY_SCAFFOLD=1` still forces scaffolding when you omit a mode.
  - `--modules` analyze source layouts and write `${CX_HOME:-~/.cx}/modules/<project>-<timestamp>.md` describing package/tests gaps and scaffold opportunities. Use `--modules=json` to capture the structured analysis or `--modules=apply` to scaffold placeholders immediately.
  - `--scaffold` apply starter scaffolding by creating missing `__init__.py` files and placeholder tests across Python, Node/TypeScript, Go, and Rust code, logging results under `${CX_HOME:-~/.cx}/scaffold/<project>-<timestamp>.md`.
  - `--lint` run `bash -n` and `shellcheck` (if available) on shell scripts, parse PowerShell files when `pwsh` or `powershell` exists, syntax-check Python, JavaScript, JSON, YAML, and TOML sources when interpreters or modules are available, and flag trailing whitespace, missing final newlines, or merge conflict markers in any text file, aiding bug hunts.
- `--fix` alongside `--lint` remove trailing whitespace and append final newlines to offending files.
- `--help` show usage.

Arguments also accept `model=NAME` to select an OpenAI model. If omitted, the wrappers use the `CX_MODEL` environment variable or default to `gpt-3.5-turbo`. Use `temp=0.7` (or `CX_TEMP`) to adjust sampling temperature.

The dictionary accepts both symbolic tags like `@dev` and numeric macros such as `#42` that expand to preset bundles.
When a plain phrase repeats, `cx` will offer to mint a new `@domain` tag so it can be reused in future prompts. Export `CX_DISABLE_MINT=1` when running the wrapper in non-interactive automation or tests to suppress these prompts.
Symbol usage counts are tracked and the wrapper reports both the top and least-used symbols after each run for context.
Usage summaries also show average uses and how many symbols remain unused. Dictionary pruning no longer enforces a hard limit—set `CX_DICT_MAX` only as a hint. When the limit is exceeded, the wrapper presents usage statistics and lets you choose how many entries to keep or skip pruning entirely.
Each time a symbol is expanded, its final text is appended to `${CX_HOME:-~/.cx}/context/<symbol>.log`, letting the wrapper build richer context histories that can seed smarter prompts in the future. Symbol co-occurrences are tracked in `${CX_HOME:-~/.cx}/relations` as pairs and triads drawn from up to nine symbols; when a triad recurs, the wrapper reports it and can prompt you to mint a combined `@tag` so compound concepts compress cleanly.
Those same symbols populate a neuron-like grid stored per project under `${CX_HOME:-~/.cx}/grid/<project>.grid`, where each entry starts at the center of a 3×3 block and records up to eight neighboring symbols with their visit counts, adding a depth dimension so relationships evolve and explain context like weighted connections in a neural lattice.
The wrapper scans offline prompt queues and per-symbol context logs on each run to surface repeated phrases and offer new tag suggestions, but review the files under `${CX_HOME:-~/.cx}/offline` and `${CX_HOME:-~/.cx}/context` periodically to refine definitions and keep the dictionary growing.
Responses from Codex are saved under `${CX_HOME:-~/.cx}/responses/<project>.log` and scanned for repeated phrases, prompting you to mint new tags from model feedback. Each run also mines the entire responses log so recurring phrases across sessions can be symbolized, letting the dictionary grow over time.
Prompts are likewise appended to `${CX_HOME:-~/.cx}/prompts/<project>.log` and mined across runs so recurring instructions you write become reusable tags.

You can also tag runs with `topic=alpha,beta`. Each symbol expanded during the prompt is logged under `~/.cx/topics/<topic>.log`, building a growing map of which symbols relate to which topics.
Run `cx --topics` to review the topics collected so far and see how many symbol expansions each has recorded.

Run `cx --audit` to generate an audit report of the current repository. The wrapper records line counts for tracked files and lists any `TODO`, `FIXME`, or `BUG` markers it finds, storing the results under `~/.cx/audit/<project>.log`.

Run `cx --lint` to syntax-check project scripts and configs. The wrapper executes `bash -n` (and `shellcheck` when present) on Bash files, parses PowerShell scripts when a PowerShell interpreter is available, checks Python (`python -m py_compile`), JavaScript (`node --check`), JSON (`python -m json.tool`), YAML (when PyYAML is installed), and TOML (via `tomllib`/`tomli` when available), and warns about trailing whitespace, missing final newlines, or leftover merge conflict markers in any text file. Add `--fix` to strip trailing whitespace and append a newline at end-of-file where missing.

Run `cx --inspect` to build a repository health summary. The command tallies tracked files and total lines, highlights the most common extensions and busiest top-level directories, lists the largest files, and surfaces potential problems such as TODO/FIXME markers, unresolved merge conflicts, and debug statements like `console.log`, `debugger;`, or `pdb.set_trace`. Results are written to `~/.cx/inspect/<project>.log` for later review.

Run `cx --hotspots` to analyze git history and surface likely bug hotspots. By default the wrapper looks back 90 days of commits (override with `CX_HOTSPOTS_DAYS=180`, or set `0` to scan the entire history) and reports the busiest authors, files touched most frequently, the highest-churn files, and the noisiest top-level directories. Reports are saved to `~/.cx/hotspots/<project>.log`, and you can adjust how many entries appear by setting `CX_HOTSPOTS_LIMIT`.

Run `cx --stale` to identify files that have gone cold. The command scans git history for the most recently touched commit per tracked file, filters anything older than `CX_STALE_MIN_AGE` days (default 180), sorts by age, and prints the oldest entries along with their last commit date, author, and hash. Reports are saved to `~/.cx/stale/<project>.log`, and you can change how many entries appear with `CX_STALE_LIMIT`.

### Architecture reference

Before launching automated improvement sweeps on a new project, review or draft an architecture playbook. CodexWrapper's canonical reference lives in [`architecture_overview.md`](architecture_overview.md) and should explicitly capture:

- Imports and external requirements.
- Key functions alongside module boundaries and responsibilities.
- Integration points within the repo and to external services.
- The execution flow/end-to-end path the code follows.

Pair the architecture reference with the companion methodology checklist in [`organizational_methodology.md`](organizational_methodology.md), which standardizes how we inventory imports, modules, requirements, integration seams, execution paths, and recommendations before automation. Treat this as a standing goal: each engagement must refresh the dossier so it explicitly lists imports, functions, requirements, module responsibilities, integration seams, execution flow, and curated immediate/foundational/exploratory recommendations before any automation runs. The playbook now includes a **Current CodexWrapper Recommendations** section that captures the latest priorities (tests to add, CI coverage, analytics ideas) so every engagement begins with a shared improvement backlog.

Treat this checklist as a template when onboarding other repositories so each team starts with the same normalized enhancement reference. It is also tracked as an explicit goal in [`goals.md`](goals.md); mark the architecture playbook complete only after the document is refreshed for the current repo.

### API calls

To send the expanded prompt to OpenAI, set the `OPENAI_API_KEY` environment variable. The wrappers post the prompt to the
`chat/completions` endpoint using the model chosen via `model=` or `CX_MODEL` (default `gpt-3.5-turbo`) and temperature from `temp=` or `CX_TEMP` (default `0.7`), then print the model's reply. If the key is missing or you run with `--offline`,
the prompt is saved to `~/.cx/offline/<project>/<timestamp>.txt` so it can be replayed later. When prompted for a key, pressing Enter
queues the prompt offline. Network or HTTP failures likewise store the prompt in the offline queue. Run `cx --replay` after a
key is available to send and remove queued prompts.

`cx5` folds any `raw=` fragments like `g:foo` or `c:bar` into goals or constraints before symbol replacement so compressed CX5 strings capture those directives.
