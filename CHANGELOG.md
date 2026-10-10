# Changelog

All notable changes to **cleankeeper** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-10-06

### Changed (open-source edition)
- Renamed to **CleanKeeper（洁净管家）**, de-branded from the internal project for public release.
- Wake word made configurable (host-defined) instead of a fixed name.
- Internal project references generalized: works with any desktop AI agent host, not a specific client.

## [1.1.1] - 2026-10-06

### Fixed (audit round 1)
- **Real rollback (red line 2)**: `win_clean.ps1` now *moves* files into an undo backup batch (`%LOCALAPPDATA%\CleanKeeper\reports\undo\backup_<timestamp>`) with a per-file `manifest.csv`; `undo_template.ps1` restores from the manifest, verifies each item, and reports partial restores honestly. Previously the undo script was a placeholder that printed fake success.
- Removed misleading "deleted files can be found in the recycle bin" output — `Remove-Item -Force` never goes to the recycle bin; the false-success line violated acceptance check #6.
- **Whitelist guard fix**: the guard previously blocked `$env:TEMP` itself, so the top green item (用户临时文件) could never be cleaned. The guard now blocks *protected roots only* (drive roots, user profile areas, AppData roots, Windows, Program Files).
- **D-drive hard block (red line 5)**: all `D:\` paths are rejected at script level; named-item cleanup goes through the app-layer authorization flow.
- **Honest freed-size**: `$totalFreed` now counts only files actually moved successfully; skipped in-use files are excluded.
- **Undo retention**: only the last 3 backup batches are kept (pruning implemented).
- `win_scan.ps1`: added log/session-class scan section (scannable + size report, default-keep); removed broken placeholder path; red-tier identification now counts protected user directories.
- `cleanup_rules.json`: removed developer-personal note ("已迁U盘 E:\BCUT_cache\datas") per user-first wording policy; report dir moved off the user Desktop to `%LOCALAPPDATA%\CleanKeeper\reports`.

## [1.1.0] - 2026-10-06

### Added
- **User-first log policy**: logs / session data now **default-keep** — scanned and reported, deleted only after explicit user approval with a separate confirmation.
- New speech template: "日志类发现" (log discovery) — states default-keep and offers separate deletion.
- New intent keywords: 删日志 / 清理日志 / 日志可以删 (log-directed, separate confirmation flow).
- Acceptance check #5: **log zero-deletion** (no deletion without explicit user approval).
- Design-stance section (§0): the skill serves all users, not a single developer — the decision always belongs to the user.

### Changed
- Red line #4: logs/session data moved from "never-touch" / "direct-clean" extremes to a unified **default-keep, user-approved** policy.
- Whitelist: log/session data reclassified into 🟡 yellow (confirm) tier, never auto-cleaned.

### Removed
- Developer-preference wording (e.g. "因为我是XX重度用户所以不删") — replaced with user-first rationale.

## [1.0.0] - 2026-10-06

### Added
- Initial skill package: `SKILL.md` + `assets/` (cleanup_rules.json, red_lines.md, report_template.md) + `assets/scripts/` (win_scan.ps1, win_clean.ps1, undo_template.ps1).
- 9-state state machine (Wake → Command → Intent → Scan → Report → Approval → Execute → Result → Undo).
- 3-tier risk grading (🟢 direct / 🟡 confirm / 🔴 never).
- Voice + click dual-channel confirmation, session-scoped authorization (not cached).
- Rollback: last 3 cleanups recoverable.
- 8 red lines (human-approval gate, user-data protection, multi-drive boundary, System32 out-of-scope, speech compliance, graceful degradation).
- Script conventions: UTF-8 BOM, -DryRun preview, whitelist guard, skip-in-use, honest failure reporting.
