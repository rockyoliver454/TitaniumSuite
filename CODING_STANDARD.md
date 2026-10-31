# Titanium Suite — Coding Standard

**Status:** Mandatory design philosophy (not a certification claim).  
**Applies to:** `TitaniumWM/`, `TitaniumRun/`, `TitaniumBG/`, `TitaniumLogin/`  
**Bars in spirit:** Ada 2012 / SPARK-oriented, MISRA-like Ada discipline, NASA-style defensive coding, DoD high-assurance mindset.

Formal machine proofs and third-party certification are **optional**. Writing code *as if* those bars apply is **required**.

---

## 1. Language & Build

| Rule | Requirement |
|------|-------------|
| Language | Ada 2012 (`-gnat2012`) |
| Warnings | `-gnatwa` on; treat new warnings as defects to clear or justify |
| Config | **Compile-time only** — no runtime config file parsers |
| Tools | Separate KISS binaries; no plugin/script engines |
| Platforms | Linux + FreeBSD first; avoid Linux-only APIs without a portable path |

## 2. SPARK Boundaries

| Zone | `SPARK_Mode` | Contents |
|------|--------------|----------|
| Pure logic / state policy | **On** | Indices, clamps, workspace math, bounded buffers |
| X11 / PAM / POSIX FFI | **Off** | All `Import`, unchecked conversions, OS calls |
| Main event / login loops | **Off** | Orchestration that must talk to FFI |

Contracts (`Pre`/`Post`/`Loop_Invariant`) on SPARK-facing APIs where practical. Prefer proveable shapes even without running GNATprove in CI yet.

## 3. MISRA-like Ada Discipline

1. No heap growth for long-lived client/session tables — fixed bounds (`Max_Clients`, etc.).
2. Explicit control flow; no hidden side effects across packages beyond documented globals.
3. Every pointer/FFI use isolated; no unchecked conversion without a comment why.
4. Bounded loops (`Max_Clients`, max screens, max PAM retries).
5. No recursion into the event loop (MapRequest storms) — override-redirect decorations, guards.
6. Prefer early return + recover over aborting the process.

## 4. NASA-style Defensive Coding

1. Check display open, geometry, and index validity before use.
2. Clamp ratios and sizes; never feed negative widths to X.
3. Survive BadWindow races via error handler (do not abort).
4. On display death: save session → try reconnect → exit with defined code for TitaniumLogin.
5. Keep functions small; one job per package where possible.

## 5. DoD / High-Assurance Mindset

1. Predictable builds (`build-all.sh` / per-tool `build.sh`).
2. Minimal attack surface: no scripting, no GUI config, no runtime theme engines.
3. Kill + safe-close for clients; never soft-only.
4. Session handoff codes are part of the contract (document them).
5. Reliability over features — refuse compositing, animations, Wayland, plugins.

## 6. Session Exit Codes (WM ↔ Login)

| Code | Meaning |
|------|---------|
| 0 | Normal quit (user requested) |
| 75 | Display/connection lost after session save attempt |
| 76 | Display open/reconnect failed |

TitaniumLogin must return to the console login prompt on any WM/session exit (including 75/76).

## 7. Multi-Monitor Invariants

1. Each screen is a separate world (clients, focus, layout, workspaces).
2. A client belongs to exactly one screen at a time.
3. Moving a client updates both screens’ invariants before retile.
4. Max screens is a compile-time bound.

## 8. Review Checklist (every change)

- [ ] No runtime config parser added  
- [ ] SPARK On/Off boundary respected  
- [ ] Bounds/clamps on new numeric paths  
- [ ] FFI isolated; errors cannot kill the WM loop  
- [ ] Docs/keybinds match code of truth  
- [ ] Linux + FreeBSD portability considered  

---

**North star:** A year of daily use without WM-caused crashes or emergency recompiles.
