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

Set `CX_HOME` or `CX_BIN_DIR` before running the installer if you want the Codex data directory or wrapper binaries somewhere other than the defaults (`~/.cx` and `~/.local/bin`). During installation the script verifies `python3`/`pip`, installs the `tiktoken` and `openai` Python modules, copies the Bash wrappers (`cx`, `cx5`) or PowerShell scripts (`Invoke-Codex.ps1`, `Compress-CX5.ps1`) into `${CX_BIN_DIR:-~/.local/bin}`, and seeds `${CX_HOME:-~/.cx}` with a starter dictionary plus metrics, context, offline, responses, prompts, topics, inspect, hotspots, stale, neuron-grid, and relations assets along with the decompression spec. The installers also drop reusable environment helpers at `${CX_HOME}/cx-env.sh` and `${CX_HOME}/cx-env.ps1`.

After installing, add the helper to your shell profile so PATH updates and environment defaults load automatically:

```bash
source ~/.cx/cx-env.sh    # Bash/zsh
```

```powershell
. $env:CX_HOME/cx-env.ps1 # PowerShell
```

If you store an API key in `~/.cx/openai_api_key`, the helper exports it so wrappers can call the OpenAI API without prompting.

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

### Run a comprehensive improvement pass

```bash
cx --improve
```

Runs the baseline automation with autofixes enabled and then executes the project bootstrap actions with installs and tests turne
d on by default so gaps surface early. Set `CX_IMPROVE_SKIP_INSTALL=1` or `CX_IMPROVE_SKIP_TESTS=1` to bypass those phases when n
eeded, and export newline-delimited commands via `CX_IMPROVE_EXTRA` to run additional cleanup or verification steps after the bu
ilt-in automation. After completion the wrapper prints a git status summary, shows a `git diff --stat`, and appends the results t
o `${CX_HOME:-~/.cx}/improve/<project>.log` for future reference.

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

Flags:

- `--dry` preview the expanded prompt without sending it.
- `--estimate` report raw vs compressed token counts and log `[ISO timestamp] raw=X compressed=Y savings=Z%` under `${CX_HOME:-~/.cx}/metrics/<project>.log`. Uses the `tiktoken` tokenizer when available and falls back to word counts. This flag implies `--dry`.
- `--offline` skip the API call and save the expanded prompt under `${CX_HOME:-~/.cx}/offline/<project>/<timestamp>.txt` for later use.
- `--replay` send any queued prompts from project subdirectories under `${CX_HOME:-~/.cx}/offline` once an API key is available.
- `--dict` display the combined dictionary with usage counts and exit.
- `--metrics` show token-savings history for the current project and exit.
- `--grid` display the neuron-style grid of symbol neighbors for the current project and exit.
- `--locate` report the detected project root, current-relative path, automation opportunities, and missing prerequisites.
- `--relations` show the most frequent symbol pairs and triads from `${CX_HOME:-~/.cx}/relations` and exit.
- `--topics` list each topic log in `${CX_HOME:-~/.cx}/topics` with its entry count and exit.
- `--audit` scan tracked files for line counts and TODO/FIXME markers, saving a report under `${CX_HOME:-~/.cx}/audit/<project>.log`.
- `--inspect` generate a repository health report covering file extension breakdowns, hot directories, the largest files, TODO/FIXME counts, merge conflict markers, and debug statements, logging to `${CX_HOME:-~/.cx}/inspect/<project>.log`.
- `--hotspots` analyze git history (default last 90 days) to surface the hottest files, highest-churn directories, and busiest authors, logging to `${CX_HOME:-~/.cx}/hotspots/<project>.log`. Tune the lookback window or list length with `CX_HOTSPOTS_DAYS` and `CX_HOTSPOTS_LIMIT`.
- `--stale` highlight tracked files whose last commit is older than `CX_STALE_MIN_AGE` days (default 180), showing up to `CX_STALE_LIMIT` entries and logging the report to `${CX_HOME:-~/.cx}/stale/<project>.log`.
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
    newline-delimited commands from `CX_IMPROVE_EXTRA`, and log git status plus diff stats under `${CX_HOME:-~/.cx}/improve/<project>.log`.
 - `--lint` run `bash -n` and `shellcheck` (if available) on shell scripts, parse PowerShell files when `pwsh` or `powershell` exists, syntax-check Python, JavaScript, JSON, YAML, and TOML sources when interpreters or modules are available, and flag trailing whitespace, missing final newlines, or merge conflict markers in any text file, aiding bug hunts.
 - `--fix` alongside `--lint` remove trailing whitespace and append final newlines to offending files.
- `--help` show usage.

Arguments also accept `model=NAME` to select an OpenAI model. If omitted, the wrappers use the `CX_MODEL` environment variable or default to `gpt-3.5-turbo`. Use `temp=0.7` (or `CX_TEMP`) to adjust sampling temperature.

The dictionary accepts both symbolic tags like `@dev` and numeric macros such as `#42` that expand to preset bundles.
When a plain phrase repeats, `cx` will offer to mint a new `@domain` tag so it can be reused in future prompts.
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

### API calls

To send the expanded prompt to OpenAI, set the `OPENAI_API_KEY` environment variable. The wrappers post the prompt to the
`chat/completions` endpoint using the model chosen via `model=` or `CX_MODEL` (default `gpt-3.5-turbo`) and temperature from `temp=` or `CX_TEMP` (default `0.7`), then print the model's reply. If the key is missing or you run with `--offline`,
the prompt is saved to `~/.cx/offline/<project>/<timestamp>.txt` so it can be replayed later. When prompted for a key, pressing Enter
queues the prompt offline. Network or HTTP failures likewise store the prompt in the offline queue. Run `cx --replay` after a
key is available to send and remove queued prompts.

`cx5` folds any `raw=` fragments like `g:foo` or `c:bar` into goals or constraints before symbol replacement so compressed CX5 strings capture those directives.
