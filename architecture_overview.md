# CodexWrapper Architecture Overview

## Purpose
This document captures how the CodexWrapper toolchain is assembled so every enhancement effort follows the same shared mental model. It catalogs imports and external prerequisites, summarizes major scripts and their responsibilities, and explains how execution flows through the wrapper during common operations. Maintaining this reference is now a standing goal (see `goals.md`), so refresh it whenever the automation surface changes and keep it synchronized with the complementary guidance in `organizational_methodology.md`.

## Key Components
| Component | Language | Responsibility |
| --- | --- | --- |
| `cx` | Bash | Primary wrapper. Expands symbolic prompts, interacts with project dictionaries, logs metrics/context, orchestrates automation commands (`--lint`, `--baseline`, `--start`, `--improve`, `--additive`, `--enhance`, etc.), and optionally calls the OpenAI Chat Completions API.
| `cx5` | Bash | Generates CX5-ALG compressed strings by inverting dictionary entries, folding raw fragments into goal/constraint sections, and emitting single-line payloads.
| `Invoke-Codex.ps1` | PowerShell | PowerShell mirror of `cx`, supporting Windows-friendly prompting, dictionary persistence, logging, API calls, and automation flags.
| `Compress-CX5.ps1` | PowerShell | PowerShell mirror of `cx5` for CX5 encoding on Windows.
| `install.sh` / `install.ps1` | Bash / PowerShell | Bootstrap CodexWrapper into `${CX_HOME}` and `${CX_BIN_DIR}` (or virtualenv) while ensuring `python3`, `pip`, `tiktoken`, and `openai` are installed. They copy helper scripts (`cx-env.sh`, `cx-env.ps1`) and seed dictionaries, metrics, context, prompts, responses, topics, relations, neuron grids, audit/inspect/hotspot/stale/enhance/improve/backlog/depscan/format/scaffold/modules/additive directories.
| `install_venv.sh` | Bash | Convenience installer that drops the same assets into the currently-activated Python virtual environment.
| `cx-env.sh` / `cx-env.ps1` | Shell helpers | Source-able helpers that export `CX_HOME`, update `PATH` to include `${CX_BIN_DIR}`, and reload saved API keys.
| `decompression_spec.md` | Markdown | Reference for how CX5 placeholders expand back into full prompts (symbol resolution, `^st{N}` conversion, raw fragment folding, comma normalization).
| `tests/test_modules.py` | Python | Smoke/regression tests that spin up sandbox repositories, execute module/additive workflows, and assert JSON snapshots, mitigation plans, and regression guards.

## External Dependencies
- **Mandatory:**
  - `bash` 5+, `python3` 3.8+, `pip`.
  - Python packages: `tiktoken`, `openai` (installed by the installers via `pip install --upgrade`).
- **Optional, auto-detected by `cx --start` / `--baseline` commands:** `git`, `node` ecosystem tools (`npm`, `yarn`, `pnpm`, `bun`), Python managers (`poetry`, `pipenv`), `pre-commit`, `just`, `task`, `bazel`/`bazelisk`, `pants`, `ruby`/`bundle`, `composer`, `.NET` CLI, `mvn`, `gradle`, `mix`, `stack`, `cabal`, `swift`, `sbt`, `flutter`, `dart`, `cmake`, `ctest`, `go`, `cargo`.
- **Formatters & linters triggered by `--format` / `--lint`:** `shfmt`, `black`, `isort`, `ruff`, `goimports`, `gofmt`, `cargo fmt`/`rustfmt`, `prettier`, `terraform`, `clang-format`, `python -m py_compile`, `node --check`, plus JSON/YAML/TOML validators via Python's standard library.
- **API:** OpenAI Chat Completions endpoint (`https://api.openai.com/v1/chat/completions`) accessed through `curl` from Bash or `Invoke-WebRequest` in PowerShell when `OPENAI_API_KEY` is present.

## Major Functions (Bash `cx`)
- **Project discovery:** `resolve_project_root`, `derive_project_name`, `enter_project_root`, `leave_project_root` standardize execution relative to the repository root.
- **Dictionary management:** `load_dictionaries`, `save_dictionary`, `record_symbol_usage`, `maybe_prompt_for_unknown_symbol`, `prompt_for_domain_tag`, and `contextual_usage_report` merge global/project dictionaries, persist new entries, and emit usage analytics.
- **Compression helpers:** `expand_standard_patterns` (handles `^st{N}`), `normalize_commas`, `apply_replacements`, `fold_raw_fragments`, `render_prompt` orchestrate prompt assembly across `role`, `goal`, `cons`, `reason`, and `out` fields while logging expansions to prompts/context/topic/relations/neuron-grid stores.
- **Metrics & logging:** `record_metrics`, `log_response`, `log_prompt`, `log_topic_usage`, `update_relations`, `update_neuron_grid` keep the `${CX_HOME}` workspace coherent.
- **API orchestration:** `ensure_api_key`, `call_openai_api`, `handle_offline_queue`, `replay_offline_queue` manage interactive API key capture, offline storage, and replay.
- **Automation runners:** suites of helpers prefixed with `run_` / `*_present` detect dependency managers, install prerequisites, and launch lint/tests/formatters. Examples include `run_node_install`, `run_python_install`, `run_bundle_install`, `run_composer_script`, `run_precommit_hooks`, `run_cmake_pipeline`, `run_bazel_targets`, `run_pants_commands`, plus `run_format_sweep`, `run_depscan`, `run_audit_scan`, `run_hotspot_scan`, `run_stale_scan`.
- **Composite workflows:**
  - `run_baseline_suite` drives `--baseline` by chaining lint/audit/inspect/hotspot/stale.
  - `run_start_suite` layers ecosystem automation and extra commands.
  - `run_improve_suite`, `run_additive_suite`, `run_enhance_suite`, `run_backlog_suite` coordinate reports/logging for advanced automation.
  - `run_modules_suite`, `run_scaffold_suite`, `run_depscan_suite` focus on module discovery and scaffolding.
  - `run_doctor_suite`, `run_weakpoints_suite`, `run_inspect_suite`, `run_hotspots_suite`, `run_stale_suite` surface targeted diagnostics.
  - `run_additive_mode` and `run_modules_mode` interpret mode arguments (`plan`, `apply`, `full`, `json`).

## PowerShell Functions (`Invoke-Codex.ps1`)
- Mirrors Bash functionality with advanced functions such as `Resolve-ProjectRoot`, `Get-ProjectName`, `Invoke-CodexBaseline`, `Invoke-CodexStart`, `Invoke-CodexImprove`, `Invoke-CodexAdditive`, `Invoke-CodexEnhance`, `Invoke-CodexModules`, `Invoke-CodexWeakPoints`, `Invoke-CodexDoctor`, ensuring Windows parity.
- Uses helper modules for dictionary persistence (`Load-CodexDictionary`, `Save-CodexDictionary`), context logging, API invocation (`Invoke-CodexRequest`), offline queuing, and formatting of reports.

## Data Layout under `${CX_HOME}`
```
.cx/
├── dict / usage              # Global dictionary entries and counts
├── metrics/                  # Token savings logs per project
├── prompts/ responses/       # Expanded prompts and model replies
├── offline/                  # Queued prompts for replay when offline
├── context/ topics/          # Per-symbol and per-topic histories
├── relations/                # Pair/triad co-occurrence logs
├── grid/                     # Neuron-style weighted adjacency maps
├── audit/ inspect/ hotspots/ stale/ baseline logs
├── format/ depscan/ improve/ enhance/ backlog/
├── modules/ scaffold/ additive/ weakpoints/
├── doctor/                   # Environment/diagnostic reports
├── enhance/ additive/ modules JSON snapshots
└── env/                      # Saved API key exports via `cx-env`
```
Project-specific dictionaries, usage, and logs live under `<project>/.cx` alongside repo roots so local context follows the codebase.

## Execution Flow (Typical `cx --improve` Run)
1. **Initialization:** `cx` resolves the project root, loads global + project dictionaries, and generates usage/context reports.
2. **Prompt Preparation:** Symbolic fields (`role=`, `goal=`, etc.) are expanded with `expand_standard_patterns`, replacements, and raw fragment folding. Expanded prompts are written to prompts/context/relations/neuron-grid/topic logs.
3. **Token Estimation:** If `--estimate` is supplied (implicitly for automation commands), the wrapper uses `tiktoken` when available to compare raw versus compressed token counts and logs metrics.
4. **Automation Sweep:**
   - `run_improve_suite` orchestrates linting (`run_lint_suite`), formatting (`run_format_sweep`), dependency scans (`run_depscan_suite`), audit/inspect/hotspot/stale analyses, and project-specific installs/tests via `run_start_suite`.
   - Logs are appended to `${CX_HOME}/improve`, `${CX_HOME}/format`, `${CX_HOME}/depscan`, `${CX_HOME}/audit`, `${CX_HOME}/inspect`, `${CX_HOME}/hotspots`, `${CX_HOME}/stale`.
5. **API Interaction:** If not offline, `call_openai_api` submits the structured prompt to OpenAI, captures the response, logs it to `${CX_HOME}/responses`, and mines it for new tag suggestions.
6. **Module & Additive Feedback:** Module analysis snapshots are compared against `${project}-latest.json`; quick tasks and mitigation plans feed additive/enhancement reports saved under `${CX_HOME}` directories.
7. **Output:** The wrapper prints relevant summaries (prompt, metrics, automation status, API response) to stdout/stderr and records any new symbols or tags after user confirmation.

## Integration Points & Enhancement Playbook
- **Installers** ensure prerequisites exist before copying wrappers, enabling consistent environments across Linux, macOS, Windows, and WSL.
- **Environment Scripts** (`cx-env.sh`/`.ps1`) make it easy to adopt `${CX_HOME}` and `${CX_BIN_DIR}` inside shells, CI pipelines, or virtual environments.
- **Automation Flags** (`--baseline`, `--start`, `--improve`, `--enhance`, `--additive`, `--modules`, `--depscan`, `--backlog`, `--weakpoints`, `--doctor`) provide layered insight so teams can normalize enhancement workflows:
  - Start with `--locate` and `--doctor` to confirm prerequisites.
  - Run `--baseline`/`--start` for initial hygiene.
  - Use `--format`, `--depscan`, `--lint --fix` for cleanup.
  - Generate improvement plans via `--improve`, `--enhance`, `--backlog`.
  - Evaluate modularization with `--modules`, `--scaffold`, `--additive`.
  - Track weak points through `--weakpoints` and mitigate using module decisions.

## Execution Path Summary
```
install.sh → seeds ${CX_HOME}, installs python deps, copies cx/cx5
cx (user invocation)
  ├─ resolve_project_root / enter_project_root
  ├─ load dictionaries + usage/context reporting
  ├─ expand prompt + token estimation
  ├─ automation suites (--baseline/--start/--improve/etc.)
  ├─ optional API request (online) or offline queueing
  ├─ log prompts/responses/metrics/topics/relations/grid
  └─ suggest new symbols/tags and persist dictionary updates
```
This playbook should be updated whenever new commands or logs are added so contributors can quickly understand the end-to-end automation pipeline.
