# CleanKeeper (洁净管家 · 系统清理与优化技能)

> **AI-Powered, Human-Approved Disk Cleanup.**
> 面向所有用户的安全清理技能：AI 只建议，执行权永远在您手上。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2B-success.svg)](#compatibility)
[![Version](https://img.shields.io/badge/version-1.2.0-orange.svg)](CHANGELOG.md)
[![SkillHub](https://img.shields.io/badge/SkillHub-ready-8A2BE2.svg)](#installation)

---

## TL;DR

CleanKeeper is a **skill package** that brings safe, conversational disk cleanup to any desktop AI agent host. It turns years of Windows-cleanup experience into a **rules-first, human-approved** workflow:

- **Voice + click dual-channel** — wake word is configurable (e.g. say "管家，清理C盘"), or tap the floating card.
- **Suggest → Confirm → Execute → Rollback** — nothing is deleted without your explicit approval.
- **Never touches user data** — documents, chats, work files, antivirus cores, and D-drive core data are hard-blocked at the system level.

---

## Why CleanKeeper?

Most "cleanup tools" fall into two traps:

| Trap | Typical tool behavior | CleanKeeper |
|---|---|---|
| **Bloatware** | Ships 200MB of "PC manager" chrome, nags you | Lightweight skill package, no chrome |
| **Oversharing** | Deletes "junk" including your data | **Human-approval gate** + 3-level risk grading |
| **Black box** | You never know what got deleted | Every action generates a rollback script (last 3 runs recoverable) |
| **One-size-fits-all** | Same preset for everyone | Per-software rules in `cleanup_rules.json` (rules/logic separated) |

It was born from real pain: a C-drive that kept running out of space, and commercial cleaners that could not be trusted. We fixed both.

---

## Features

### 9-State State Machine (deterministic, testable)

```
①Wake → ②Command → ③Intent → ④Read-only Scan
→ ⑤Graded Report → ⑥User Approval (ONLY execution gate)
→ ⑦Execute + Rollback Script → ⑧Result Report → ⑨Undo (last 3)
```

### 3-Tier Risk Grading

| Tier | Label | Behavior |
|---|---|---|
| 🟢 Green | "可直接清理" | Regenerable caches (whitelist), listed in default cleanup — still needs session-level confirmation |
| 🟡 Yellow | "需要您确认" | Recycle bin, large files, **logs/session data (default-keep)** — per-item second confirmation |
| 🔴 Red | "永远不会碰" | User documents/chats/work files, antivirus cores, databases, D-drive core data — system-level hard block |

### Rules-First Architecture

- `SKILL.md` defines *how to judge, how to flow, what to guard*.
- `cleanup_rules.json` holds *which paths* — **adding a new software rule never touches the main file**.

### Logs / Session Data: Default-Keep (user-first, v1.1+)

- Logs and session data are **scanned and reported but kept by default**.
- They are deleted **only after explicit user approval**, with a separate confirmation.
- No "developer-preference" shortcuts. The decision always belongs to the user.

---

## Security First (8 Red Lines)

1. **Zero deletion without authorization** — State ⑥ is the only execution gate; authorization is not cached across sessions.
2. **Rollback effective** — last 3 cleanups recoverable, content verified after restore.
3. **User data never touched** — documents/chats/work files: scannable, but never in the execution list (hard block).
4. **Logs/session data default-keep** — deleted only on explicit user approval.
5. **D-drive core data never executed by default** — unless the user names items one by one.
6. **System32 etc. out of scan scope** — L3 blacklist, never executed.
7. **Speech-compliant** — always address the user as "您"; every report states who holds the execution right.
8. **Dual-channel consistency + graceful degradation** — voice ≡ click; cleanup-module errors are logged, never thrown into the main app.

---

## Installation

### From SkillHub / WorkBuddy (recommended)

1. Copy the whole `cleankeeper/` directory into your skill library (WorkBuddy-compatible).
2. Run `SKILL.md` self-check (the skill is recognized by its frontmatter `name: cleankeeper`).
3. Load into your desktop AI agent host — the voice module picks it up via the intent table (wake word configurable).

### From source (GitHub)

```powershell
git clone https://github.com/your-org/cleankeeper.git
# optional: run the PS1 syntax gate (repo-side tool, not bundled in the skill package)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1
```

---

## Quick Start

```text
User:  （唤醒词，可配置，例如"管家"）
Agent: 在的，您请说。
User:  清理C盘。
Agent: 好的。我先检查有哪些能安全清理的，不会删除任何文件。
       ...scanning...
Agent: 检查完成，可直接清理约1.8GB；需要您确认约600MB；
       日志类数据我默认保留。您说"确认"我才动手。
User:  确认。
Agent: 清理完成，释放2.3GB。最近3次清理都可撤销。
```

Or use fine-grained commands: `只清绿色` / `跳过回收站` / `别动D盘` / `只扫描不清理`.

---

## Architecture

```
cleankeeper/
├── SKILL.md                     # metadata + triggers + 9-state flow + red lines
├── assets/
│   ├── cleanup_rules.json       # whitelist rules (green/yellow/red, multi-drive)
│   ├── red_lines.md             # 8 red lines + 9 acceptance checks
│   ├── report_template.md       # 15 speech templates + compliance checklist
│   └── scripts/
│       ├── win_scan.ps1         # read-only scan, graded report (UTF-8 BOM)
│       ├── win_clean.ps1        # -DryRun preview → execute, whitelist guard, skip-in-use, rollback script
│       └── undo_template.ps1    # last-3 rollback template
```

### Script Conventions

- All `.ps1` saved as **UTF-8 with BOM** (Windows PowerShell 5.1 compatibility — prevents Chinese-text syntax breakage).
- Deletion is guarded: preview sizes, hard-block protected roots (drive roots, user profile areas, AppData roots, Windows/Program Files, **all D-drive paths**), never delete outside the whitelist.
- **Real rollback**: in execute mode, files are *moved* into an undo backup area (`%LOCALAPPDATA%\CleanKeeper\reports\undo\backup_<timestamp>`) with a per-file manifest; the undo script moves them back and verifies each item; only the last 3 batches are kept.
- In-use files are skipped and reported honestly — no fake success; partial restores are reported as partial, never as full success.

---

## Compatibility

| Item | Support |
|---|---|
| OS | Windows 10/11 (PowerShell 5.1+) |
| Host | Any desktop AI agent / assistant host — voice + click |
| Lang | zh-CN speech; EN docs |
| Integration | WorkBuddy skill library; SkillHub; standalone scripts |

---

## Roadmap

- [x] v1.0 — core skill package (scan/clean/undo, 8 red lines)
- [x] v1.1 — user-first log policy (default-keep, explicit approval)
- [x] v1.2 — open-source edition (de-branded, wake word configurable, real move-to-undo rollback)
- [ ] v1.3 — full voice pipeline integration (VAD→ASR→NLU→TTS)
- [ ] v2.0 — multi-drive dashboard + cleanup history UI

---

## Contributing

Issues and PRs are welcome. Design principle: **no silent downgrades** — if something can't be done safely, say so and explain why.

---

## License

**Apache License 2.0** — free for commercial and personal use with attribution.

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.2.0 | 2026-10-06 | Open-source edition: renamed **CleanKeeper（洁净管家）**, de-branded for public release, wake word made configurable |
| 1.1.1 | 2026-10-06 | Audit fixes: real move-to-undo rollback with manifest + verified restore; protected-path hard block incl. all D-drive paths; freed-size counts only successful items; log-class scan section in win_scan; no fake success messages |
| 1.1.0 | 2026-10-06 | User-first log policy: logs/session data default-keep, explicit user approval required |
| 1.0.0 | 2026-10-06 | Initial skill package: 9-state machine, 3-tier risk, dual-channel, rollback x3 |

---

**CleanKeeper（洁净管家）** ｜ AI 只建议，执行权永远在您手上。
