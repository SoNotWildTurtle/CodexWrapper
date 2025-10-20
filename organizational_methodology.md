# Organizational Methodology Playbook

## Purpose
This playbook standardizes how we profile a repository before automating fixes with CodexWrapper. It extends the architecture reference by capturing the day-to-day checklists, questions, and artifacts we expect to maintain while studying imports, functions, requirements, module responsibilities, integration seams, execution flow, and any follow-on recommendations. Maintaining and refining this methodology is now a standing goal in `goals.md`, so every engagement should refresh or adapt it before running automation to ensure contributors and CodexWrapper share the same mental model.

## Discovery Checklist
1. **Establish the baseline.**
   - Run `cx --locate` to confirm the detected project root, supported ecosystems, and missing tooling.
   - Run `cx --doctor` to validate core prerequisites and capture environment drift.
   - Record findings in the engagement journal (architecture overview + this methodology).
2. **Inventory dependencies.**
   - Document language runtimes, package managers, and external services from manifests (`requirements.txt`, `package.json`, `pyproject.toml`, `go.mod`, `Gemfile`, etc.).
   - Note optional tooling surfaced by `cx --start` (pre-commit hooks, formatters, CI entrypoints) and whether they are active.
3. **Trace imports and modules.**
   - For each primary language, map modules/packages, key entry files, and shared libraries.
   - Identify dependency direction (e.g., CLI wrappers → automation suites → loggers) and ensure circular relationships are called out.
4. **Catalogue functions and responsibilities.**
   - Summarize the responsibilities of major scripts or classes.
   - Note cross-cutting helpers (`resolve_project_root`, `run_start_suite`, etc.) and what features rely on them.
5. **Describe execution flow.**
   - Create swimlanes or ordered lists for core commands (`--baseline`, `--start`, `--improve`, `--modules`, `--additive`, etc.).
   - Highlight where state is persisted (metrics, context, prompts, responses, modules JSON) and which commands update each dataset.
6. **Surface weak points and recommendations.**
   - Mine logs from `cx --weakpoints`, `--modules=json`, `--additive=plan`, and `--depscan` for known gaps.
   - Translate findings into mitigation items categorized as Immediate, Plan Soon, or Monitor (mirroring module decision scoring).
   - Capture manual recommendations (tests to add, refactors to pursue, docs to refresh) tied to affected modules.

## Artifact Expectations
- **Architecture Overview (`architecture_overview.md`)** – living document that summarizes imports, key functions, requirements, module responsibilities, integration points, and execution flow.
- **Organizational Methodology (`organizational_methodology.md`)** – this playbook; keep it synchronized with the architecture overview and update per engagement.
- **Engagement Notes** – append relevant excerpts to `developer_notes.md`, `personal_notes.md`, or project-specific logs outlining takeaways and next actions.
- **Discovery delta log** – after every automation sweep (`--baseline`, `--improve`, `--additive`, etc.), capture what changed (new gaps, resolved items, updated recommendations) so the next run starts with fresh context.

## Methodology Summary Template
Before any automation runs, add or refresh a **Methodology Summary** section in this document that:

1. Lists the current imports, modules, and external requirements that matter for the engagement.
2. Highlights the high-value functions or entry points we must keep in mind, including how they compose across modules.
3. Describes the integration seams (APIs, CLIs, background jobs) and overall execution path CodexWrapper will influence.
4. Ends with curated recommendation categories (Immediate, Foundational, Exploratory) so stakeholders can validate the next actions at a glance.

This summary is the artifact the goals checklist now requires; treat it as the “green light” that the organizational methodology is complete enough for CodexWrapper to begin automated enhancements.

## Tooling Support
- Use `cx --metrics`, `--relations`, `--grid`, and `--topics` to enrich the qualitative write-up with quantitative usage data.
- Pull churn context from `cx --hotspots` and `--stale` to justify recommendations for modularization or cleanup.
- Attach excerpts or tables from `cx --inspect`, `--depscan`, and formatter logs to demonstrate evidence for each recommendation.

## Recommendations Template
When updating this playbook for a new repository, include a section summarizing:
- **Immediate actions** (blocking issues such as missing tests, failing formatters, outdated dependencies).
- **Foundational improvements** (module scaffolding, docs, CI enhancements that unlock future automation).
- **Exploratory ideas** (areas to monitor, experiments to validate, or metrics to collect).

This methodology should evolve with CodexWrapper. When we introduce new automation (e.g., additional scans or analyzers), extend the discovery checklist and recommendations template so teams have a repeatable process for understanding and improving their codebases.

## Current CodexWrapper Recommendations

### Immediate actions
- **Broaden regression coverage for wrapper commands.** Our current test suite (`tests/test_modules.py`) primarily exercises the module and additive workflows. Add targeted smoke tests for new lifecycle commands—`--doctor`, `--weakpoints`, `--backlog`, `--depscan`, `--enhance`, and `--baseline`—so future changes do not silently break these higher-level automations.
- **Capture formatter/diagnostic expectations.** Extend the tests to assert that `cx --format` and `cx --lint --fix` write logs under `${CX_HOME}/format` and `${CX_HOME}/audit` respectively, guarding against regressions in the hygiene tooling we rely on during `--improve` sweeps.
- **Publish onboarding checklists beside reports.** Bundle the discovery checklist outputs (architecture overview + this methodology) into the generated backlog/enhance reports so anyone reviewing automation artifacts can immediately see the latest architecture snapshot and methodology recommendations.
- **Automate methodology completion checks.** Implement a `cx --methodology` sanity check that verifies the Methodology Summary exists, is current (within a configurable age), and covers imports, functions, requirements, integration seams, execution flow, and recommendation categories before automation proceeds.

### Foundational improvements
- **Establish Windows CI coverage.** Add a lightweight GitHub Actions job that runs `Invoke-Codex.ps1` smoke tests on Windows. This ensures the PowerShell wrappers stay in lockstep with the Bash implementation when new functionality lands.
- **Codify environment bootstrapping checks.** Convert the manual guidance in `cx-env.sh` and `cx-env.ps1` into automated verifications (e.g., via `./cx --doctor`) during CI so missing prerequisites are detected early across supported platforms.
- **Produce engagement-specific methodology annexes.** For larger repositories, capture delta notes (new modules, integration shifts, third-party services) in `organizational_methodology.md` appendices so the main playbook remains concise but the institutional knowledge is preserved.
- **Surface summary deltas automatically.** Extend enhancement reports to embed the latest Methodology Summary so any drift between documentation and automation output is immediately obvious.

### Exploratory ideas
- **Surface data trends in enhancement reports.** Use the accumulated logs in `${CX_HOME}` (metrics, prompts, responses, relations, neuron grids) to generate optional analytics sections inside `--enhance` or `--additive` reports, giving contributors context on which symbols or automation steps drive the most savings.
- **Prototype scenario-focused dictionaries.** Experiment with storing curated dictionaries under `topics/` for recurring engagements (security reviews, refactors, onboarding) and teach the wrapper to auto-load them based on the `topic=` argument so new sessions inherit the accumulated expertise automatically.
- **Summarize methodology adherence automatically.** Explore adding a `cx --methodology` command that checks whether the architecture overview and this document were refreshed within the last N days and whether each checklist item has an associated artifact, nudging teams when documentation drifts.
- **Correlate methodology gaps with automation pain points.** Mine failure logs from `--start`, `--improve`, and `--modules` to see which undocumented areas cause the most friction, then feed the insights back into the Methodology Summary for the next iteration.
