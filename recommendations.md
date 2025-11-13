# Recommendations Backlog

This backlog captures medium- and long-range enhancements for CodexWrapper. Each recommendation includes quick sub-notes so that automation can mine next steps while humans review priorities. Entries are numbered for easy reference.

## R-001: Surface the recommendations backlog through the CLI
Status: ✅ Completed (2025-09-05)
Sub-notes:
- Added a `--recommendations` flag in both wrappers so remote and local agents can review the backlog non-interactively.
- Emit a parsed summary before the raw Markdown to support downstream automation and quick health checks.

## R-002: Autogenerate recommendation summaries after every `--improve` sweep
Status: 🚧 In Progress (auto-summaries appended after each sweep)
Sub-notes:
- Hook into the existing `--improve` pipeline to append newly discovered items directly to this file.
- Consider diff-based heuristics so repetitive entries are merged automatically.
- Summaries now append outcome snippets after each `cx --improve` run; next iteration should condense repetitive insights.

## R-003: Prioritize recommendations based on recent audit hotspots
Status: ⏳ Planned
Sub-notes:
- Reuse `--hotspots` data to auto-tag recommendations with churn scores.
- Expose a CLI filter to focus on urgent components first.

## R-004: Correlate recommendations with module mitigation plans
Status: ⏳ Planned
Sub-notes:
- Map each module weak point to at least one recommendation to tighten feedback loops.
- Highlight recommendations that unblock mitigation tasks for rapid closure.

## R-005: Add automated recommendation aging warnings
Status: ⏳ Planned
Sub-notes:
- Track the last updated timestamp per recommendation and surface stale entries during CLI summaries.
- Provide optional pruning guidance for superseded ideas.

## R-006: Integrate recommendations with context logging
Status: ⏳ Planned
Sub-notes:
- When prompts mention recurring gaps, auto-suggest new recommendations referencing the topic logs.
- Cross-link context log entries from this document for richer discovery.

## R-007: Support remote synchronization of recommendations between machines
Status: ⏳ Planned
Sub-notes:
- Allow exporting/importing recommendation deltas for distributed teams working offline.
- Provide conflict resolution guidance when multiple edits collide.

## R-008: Build a recommendation scoring dashboard
Status: ⏳ Planned
Sub-notes:
- Aggregate scores from metrics, hotspots, and module analyses to visualize backlog health.
- Render the dashboard via `cx --recommendations --summary` once implemented.

## R-009: Automate recommendation-to-task creation for `--additive`
Status: ⏳ Planned
Sub-notes:
- Convert high-priority recommendations into additive module scaffolds automatically.
- Maintain traceability between recommendation IDs and generated tasks.

## R-010: Expand recommendations with security-specific insights
Status: ⏳ Planned
Sub-notes:
- Review audit logs for security markers and create dedicated security backlog entries.
- Coordinate with domain tags to ensure compressed prompts capture the new guidance.

## R-011: Deliver recommendation completion analytics
Status: ⏳ Planned
Sub-notes:
- Track completion velocity and visualize trends to ensure backlog growth remains healthy.
- Alert when completion pace threatens to outstrip new discovery.

## R-012: Streamline recommendation editing via config-aware templates
Status: ⏳ Planned
Sub-notes:
- Extend config templating so backlog updates can be seeded from standardized snippets.
- Provide quick commands to append new entries with consistent metadata.

## R-013: Cross-link recommendations with enhancement plans
Status: ⏳ Planned
Sub-notes:
- Embed pointers to the latest `--enhance` Markdown reports so reviewers can jump to detailed automation plans.
- Highlight recommendations that already have enhancement tasks queued.

## R-014: Teach recommendations to capture remote analysis signals
Status: ⏳ Planned
Sub-notes:
- Mirror summaries from remote automation runs (for example CI or scheduled jobs) into this backlog.
- Note when remote sweeps diverge from local findings to trigger reconciliation.

## R-015: Expose recommendation filters in the CLI
Status: 🚧 In Progress (initial filtering & search shipped)
Sub-notes:
- ✅ Added `--recommendations-filter=<status>` support in both wrappers so Planned/In Progress/Completed slices are one flag away.
- ✅ Implemented `--recommendations-search=<term>` to combine free-text matching with status filters for remote/local analysis.
- Next iteration: surface saved filter presets and allow exporting filtered views for CI bots.

## R-016: Automate recommendation deduplication
Status: ⏳ Planned
Sub-notes:
- Detect overlapping entries when new automation summaries are appended and prompt for consolidation.
- Record canonical IDs for merged items so historical references stay valid.

## R-017: Generate recommendation snapshots for retrospectives
Status: ⏳ Planned
Sub-notes:
- Periodically export the backlog to `${CX_HOME}/recommendations/<project>-<timestamp>.md` for change tracking.
- Include delta summaries comparing the latest snapshot to the previous one.

## R-018: Tie recommendations to module mitigation scores
Status: ⏳ Planned
Sub-notes:
- Sync severity data from the module regression guard into each recommendation entry.
- Surface the highest-risk modules at the top of the backlog summary output.

## R-019: Generate recommendation presets for CI bots
Status: ⏳ Planned
Sub-notes:
- Define preset filter bundles (e.g., "🔥 Hotspots", "🛠 Mitigation") stored in config for automation agents.
- Teach `cx --recommendations` to accept `--recommendations-filter=@preset` syntax.

## R-020: Link recommendations to enhancement artifacts
Status: ⏳ Planned
Sub-notes:
- Cross-reference matching entries in `~/.cx/enhance` so reviewers can jump from backlog items to enhancement plans.
- Include enhancement excerpt summaries directly under each recommendation.

## R-021: Add recommendation ownership metadata
Status: ⏳ Planned
Sub-notes:
- Support optional `Owner:` lines for distributed teams and expose `--recommendations-search=@owner/<name>` shortcuts.
- Update CLI summaries to show per-owner counts for better workload balancing.

## R-022: Surface remote vs local drift warnings
Status: ⏳ Planned
Sub-notes:
- Compare recommendations synced from remote automation runs with local backlog entries to flag mismatches.
- Provide a `--recommendations-search=drift` convenience filter once drift markers exist.

## R-023: Attach telemetry to recommendation completions
Status: ⏳ Planned
Sub-notes:
- Log completion timestamps to `${CX_HOME}/recommendations/<project>.metrics` for trend analysis.
- Extend `--recommendations-summary` output with completion velocity charts.

## R-024: Embed module quick tasks beneath recommendations
Status: ⏳ Planned
Sub-notes:
- When module analysis highlights quick wins, auto-insert them as nested bullets so backlog grooming stays actionable.
- Let `--recommendations-search=module` surface only entries with attached quick tasks.

## Auto-generated Summaries

- (auto summaries will be appended here after `cx --improve` runs)
