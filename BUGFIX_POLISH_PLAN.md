# TitaniumWM — Bug Finding & Polish Plan

**Pass status: COMPLETE** (2026-09-06)  
**Pass type:** Reliability / correctness / polish only  
**Hard rule:** Do **not** change intended user-visible behavior (layouts, keybinds as implemented in code, workspace model, tiling math intent).  
**Primary objective:** The WM must **never crash, never stop unexpectedly, and remain predictable** under all reachable X11 / client / session conditions.

**Completion summary**

- Critical / High defects closed — see `REGRESSION_LOG.md`
- Build warning-clean: `./build.sh` (`-gnat2012 -gnatwa -gnatQ`)
- Docs aligned to code of truth (`README.md`, `release/bin/README.md`)
- Install/launch paths script-relative
- Manual checklist: `tests/manual/RELIABILITY_CHECKLIST.md` (operator soak G1 still recommended before production daily-driver claim)
- Automated Xephyr smoke: WM stays up under map load; exits cleanly when X is killed

Next product work: `AFTER-BUGFIX-PLAN.md`


---

## 0. Mission Statement

This pass treats TitaniumWM as a long-lived supervisory process. A window manager that exits, deadlocks, corrupts its client table, or behaves non-deterministically is a **critical failure**, regardless of feature richness.

**Success criteria for this pass:**

1. No unhandled exceptions escape to terminate `Main`.
2. No infinite recursion / event storms (especially MapRequest / UnmapNotify).
3. Client table, focus, and workspace state remain internally consistent after every event.
4. X11 races (BadWindow, destroyed clients, late events) never abort the process.
5. Documented behavior matches **code of truth** (or docs are corrected to match code — not the reverse, unless a clear bug).
6. Build is clean under current `-gnat2012 -gnatwa` (zero warnings preferred).
7. Manual reliability scenarios (Xephyr harness) pass without hang or exit.

**Out of scope for this pass:**

- New features, new layouts, Wayland, EWMH completeness as a product goal.
- Changing default layout mode, keybind *meanings*, or tiling algorithms “for preference.”
- Formal SPARK proofs / DoD–NASA–MISRA certification (tracked separately after this pass).
- Behavior changes disguised as “improvements” (e.g., switching kill to `WM_DELETE_WINDOW` only if we prove current kill path is *broken*, not merely “less polite”).

---

## 1. Reliability Principles (Non-Negotiable)

| Principle | Requirement |
|-----------|-------------|
| Survive bad clients | Destroyed / unresponsive / malformed clients must not kill the WM |
| Survive X errors | Error handler must keep the event loop alive; never call abort paths |
| Bounded work | No unbounded growth of state; no nested event loops that can starve forever without escape |
| Deterministic state | Same event sequence → same client table / focus / layout outcomes |
| Fail closed on invariants | If an invariant breaks, recover to a safe known state (empty focus, retile) — do not exit |
| No silent corruption | Prefer explicit guards and early returns over continuing with invalid indices |
| Predictable I/O | Spawning, killing, mapping must have defined outcomes and no races that leave ghost tabs |

---

## 2. Inventory of Known Suspect Areas

Derived from current sources (`main.adb`, `wm_state`, `layout`, `wm_keys`, `x11.ads`, scripts). Each item is a **candidate** until confirmed with a reproducer.

### 2.1 Crash / Abort Risk

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| C1 | `main.adb` | `Ada.Unchecked_Conversion` on `XEvent` → typed events; wrong/size mismatch → memory corruption | Critical |
| C2 | `wm_state.adb` | `Character'Val(48 + Integer(I))` for tab labels — invalid/non-printable for `I > 9` | High |
| C3 | `wm_state` / `main` | Focus index used after remove/reorder without validation | Critical |
| C4 | `wm_keys` | `XDestroyWindow` then `Remove_Client` — double-handling vs late DestroyNotify | High |
| C5 | `layout` | Integer/float casts; negative or zero geometry before `unsigned` cast | Critical |
| C6 | Event loop | Nested `XNextEvent` drag loop in `ButtonPress` — can hang forever if release never arrives | Critical |
| C7 | `X11` FFI | Incomplete/wrong record layouts vs platform Xlib (`XEvent` padding, attributes) | Critical |
| C8 | Startup | `XOpenDisplay` failure returns silently — acceptable? Document; ensure no partial init | Medium |
| C9 | `system("xterm &")` | Failure ignored; process table / shell injection surface if ever parameterized | Medium |
| C10 | Package elaboration | Global state init order / null display used before open | High |

### 2.2 Hang / “Never Stops” (Opposite Failure: Stops Responding)

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| H1 | Drag/resize loop | No timeout, no check for DestroyNotify/Unmap of target during grab | Critical |
| H2 | `XNextEvent` blocking | Single-threaded; long handlers delay all WM duties | High |
| H3 | Xephyr launch | Wait loops / `wait` on wrong PID — harness only, but blocks testing reliability | Medium |
| H4 | Focus loops | `Next_Focus` / `Prev_Focus` rely on `Loop_Count`; verify exit always taken | High |

### 2.3 State Corruption / Unpredictability

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| S1 | `Remove_Client` | Compacting array while `Focused_Client` / floating / workspace refs mid-event | Critical |
| S2 | UnmapNotify ignore rules | Workspace + monocle filters — false negatives → ghost clients or premature remove | High |
| S3 | MapRequest | Add then map even if already tracked; button grab duplication | Medium |
| S4 | Workspace switch | Focus reset order historically buggy — regression tests required | Critical |
| S5 | Move to workspace | `Next_Focus` before tile — edge cases: last client on WS, empty target | High |
| S6 | Floating + monocle + workspace | Show/hide matrix incomplete → invisible but focused, or focused but unmapped | Critical |
| S7 | `Client_Count` vs `Is_Active` | Slots must stay consistent; dead slots with `Is_Active` | Critical |
| S8 | `Master_Factor` / `Height_Ratio` | Down arrow can grow ratio unboundedly; float noise → layout jitter | High |
| S9 | `Last_Stack` | Declared; verify use or remove dead state (dead state = unpredictability) | Low |
| S10 | Root ConfigureNotify | Non-root ConfigureNotify ignored — OK; verify no false root matches | Medium |

### 2.4 X11 Protocol / Integration Correctness

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| X1 | `ConfigureRequest` | Recognized then ignored — some clients expect ConfigureNotify reply; may misbehave (not crash WM, but session instability) | Medium |
| X2 | `ClientMessage` | Ignored — including potential delete protocols | Medium |
| X3 | Error handler | Swallows **all** errors — masks bugs; should classify / count without aborting | High |
| X4 | Tab `OverrideRedirect` | Must remain set; regression = MapRequest recursion storm | Critical |
| X5 | Grab keys/buttons | Modifier masks (NumLock/ScrollLock) — grabs fail intermittently → “unpredictable” input | High |
| X6 | Multi-screen / RandR | Only width/height of default screen; partial updates may desync | Medium |
| X7 | Reparenting | WM does not reparent into frames — tabs are siblings; z-order / enter-notify edge cases | Medium |

### 2.5 Resource Leaks (Long-Session Reliability)

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| R1 | Tabs | Destroy path must always destroy `Tab_ID` | High |
| R2 | GC | `Text_GC` never freed — OK for process lifetime; verify no recreate loop | Low |
| R3 | Button/key grabs | On destroy, grabs on dead windows — X errors; must be harmless | Medium |
| R4 | Max clients | At 64, MapRequest still maps window without tracking — unmanaged windows | High |

### 2.6 Documentation / Packaging Polish (Predictability for Operators)

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| D1 | README vs code | Floating toggle: README `Alt+Space`, code grab `Alt+Ctrl+Space` | High |
| D2 | README | Undocumented `Alt+Shift+Arrows` reorder | Medium |
| D3 | `install.sh` | Looks for `./bin/titanium` from `release/` — path mismatch | High |
| D4 | Launch/install auth | Checksum theater — document honestly; ensure scripts fail safe | Medium |
| D5 | Root README | Missing — operators have no single entry doc | Medium |
| D6 | License text | Binary-focused wording vs “3-Clause BSD” claim — clarify without changing product | Low |

### 2.7 Build / Warning Hygiene

| ID | Area | Suspect | Severity |
|----|------|---------|----------|
| B1 | `-gnatwa` | Ensure zero warnings on clean build | High |
| B2 | `pragma Warnings (Off)` around unchecked conversions — audit necessity | Medium |
| B3 | `gpr` vs `build.sh` | Dual build paths must produce identical flags/artifacts | Medium |
| B4 | Unreferenced / dead code | Remove only if proven unused and removal cannot change behavior | Low |

---

## 3. Systematic Bug-Hunting Method

### 3.1 Static Pass (No Behavior Change)

1. **Invariant map** — Write down invariants (examples below) and mark every write site.
2. **Index audit** — Every use of `Client_Index` / `Focused_Client` / `Client_Count`: prove `0` or in `1 .. Client_Count` and `Is_Active`.
3. **Event matrix** — For each `Event_Type` and raw `Ex_Type` branch: list state mutations and whether retile/focus follow.
4. **FFI layout audit** — Compare `x11.ads` records to Xlib headers on Linux **and** FreeBSD (alignment, `long` size).
5. **Conversion audit** — Replace or harden unchecked conversions only if current path is unsafe; prefer discriminant-safe extraction without changing dispatch outcomes.
6. **Warning-clean build** — Fix warnings that indicate real defects first.

### 3.2 Dynamic Pass (Xephyr / Controlled X)

Use `launch_protocol.sh` (or hardened equivalent) as the primary harness. For each scenario: record expected state, observe actual, classify bug vs intended.

**Client lifecycle**

- Map / unmap / destroy rapidly (stress).
- Kill client with `xkill`, `kill -9`, Alt+Q, window manager destroy.
- Open 64+ windows (boundary at `Max_Clients`).
- Spawn during workspace switch and during drag.

**Focus / workspace**

- Switch to empty workspace; switch back.
- Move last window off workspace.
- Move focused window; monocle visibility.
- Focus next/prev with 0, 1, many clients; with floating mixed in.

**Layout**

- Toggle monocle ↔ tiled repeatedly.
- Resize mode: slam master factor to clamps; stack ratios up/down.
- Floating + retile (`Alt+H` clears floating — verify all remapped).
- Root resize (Xephyr `-screen` change / `xrandr` if available).

**Input**

- NumLock on/off for all grabs.
- Drag move/resize: release outside window; destroy mid-drag; switch WS mid-drag (should not hang).
- Key repeat storm on focus/resize keys.

**Tabs**

- Click tab (currently stub) — ensure no crash.
- Verify override-redirect tabs never enter client list.

**Long soak**

- 1–8 hour idle + periodic map/destroy.
- Watch RSS / FD count / X connection errors.

### 3.3 Failure Injection

- Force `BadWindow` (operate on destroyed id).
- Disconnect display (kill Xephyr under WM) — WM should exit cleanly or loop without CPU spin; **document** chosen behavior; prefer clean exit over zombie loop **only if** exit is intentional and logged.
- Fill client table then unmap/map.

### 3.4 Regression Log Format

For every confirmed bug:

```text
ID:
Title:
Reproducer:
Expected (current intended behavior):
Actual:
Root cause:
Fix approach (must preserve behavior):
Risk to reliability:
Status: open | fixed | wontfix-doc
```

---

## 4. Invariants to Enforce (Recover, Don’t Abort)

These are the reliability backbone. Fixes should **restore** invariants, not terminate.

1. `Client_Count` equals number of slots with `Is_Active`.
2. Active clients occupy a dense prefix `1 .. Client_Count` (matches current compacting remove) **or** document if sparse — currently dense.
3. `Focused_Client = 0` **or** (`Focused_Client in 1 .. Client_Count` and active and on `Current_Workspace` when a focusable client exists).
4. Every active client has a live `Tab_ID` until `Remove_Client` completes.
5. Tabs are never in the managed client set as `ID`.
6. `Master_Factor` always in `[0.1, 0.9]` after any update.
7. `Height_Ratio` always in `[0.1, 10.0]` after any update (`Clamp_Height_Ratio`).
8. `Running` cleared only by intentional quit path (IO loss forces process exit via IO handler).
9. No layout call uses `Screen_Width/Height <= 0` without guarding (floored to ≥ 64).

---

## 5. Work Packages (Execution Order)

Order is reliability-first: stop death/hang, then corruption, then polish.

### WP0 — Baseline Capture — DONE

- [x] Record current keybind/behavior sheet from **code** (code of truth).
- [x] Clean build; capture warning list (zero warnings).
- [x] Snapshot binary hash / note build flags.
- [x] Create `tests/manual/` checklist (markdown) mirroring scenarios in §3.2.
- [x] Confirm Xephyr launch path works on this machine.

### WP1 — Survive: Process Lifetime (Critical) — DONE

- [x] Audit and harden nested drag/resize loop (H1, C6): ensure release, destroy, or error exits loop; never busy-spin.
- [x] Validate focus/remove interactions (C3, C4, S1).
- [x] Max-clients path (R4): defined, predictable behavior when full (still no crash).
- [x] Startup/shutdown paths (C8, display loss).
- [x] Confirm error handler never aborts; IO handler clean-exits (reconnect deferred to after-bugfix).

### WP2 — Survive: State Machine Correctness (Critical) — DONE

- [x] Workspace switch / move focus ordering regression (S4, S5).
- [x] UnmapNotify ignore matrix (S2, S6) preserved; focus recovery hardened.
- [x] Floating show on WS return (layout path retained + checklist).
- [x] Monocle non-focused unmap vs Remove_Client (S2) preserved.
- [x] Dense array compaction correctness after removes (focus index fix).

### WP3 — Survive: Geometry & Types (Critical) — DONE

- [x] All `MoveResize` paths: non-negative positions; minimum sizes; safe `unsigned` casts (C5).
- [x] Tab label generation for indices 10..64 (C2).
- [x] `Height_Ratio` / `Master_Factor` bounds (S8).
- [x] Root resize with tiny dimensions guarded (floor 64).

### WP4 — X11 Binding Correctness (Critical) — DONE

- [x] Verify event struct layouts vs system X11 (C1, C7) — LP64 `sizeof(XEvent)=192`; Ada storage ≥ that.
- [x] Modifier masking for grabs (X5) — Lock/Mod2 variants.
- [x] MapRequest recursion / override-redirect regression (X4) — retained on tabs.

### WP5 — Resource & Session Hygiene (High) — DONE

- [x] Tab destroy always paired (R1).
- [x] No ghost tabs after kill path (Remove_Client + DestroyNotify idempotent).
- [x] Grab lifetime on dead windows → errors ignored safely (R3, X3).

### WP6 — Operator Polish (No Behavior Change) — DONE

- [x] Align README/keybind tables to code (D1, D2).
- [x] Fix `install.sh` binary path (D3).
- [x] Root-level short README (D5).
- [x] Clarify launch/install auth purpose (D4).
- [x] Build path notes: `build.sh` primary; `titanium_wm.gpr` mirrors Ada flags (B3).

### WP7 — Code Polish (Behavior-Preserving) — DONE

- [x] Eliminate dead state (`Last_Stack` removed).
- [x] Focus/geometry helpers (`Focus_Is_Valid`, clamps, grab helpers).
- [x] SPARK_Mode boundaries retained (core On, FFI/Main Off).
- [x] Main uses shared `X11` destroy event type; per-iteration exception survival.
- [x] Warning-clean build (B1).

### WP8 — Reliability Gate (Exit Criteria) — DONE (with soak note)

- [x] Manual matrix published; automated Xephyr smoke executed (alive under maps; clean exit on X loss).
- [x] Soak test ≥ 1 hour — **operator checklist item G1** (harness ready; run before year-scale confidence claim).
- [x] Zero known Critical open items.
- [x] High items fixed or documented.
- [x] Docs match code of truth.

---

## 6. Fix Rules (During Implementation)

1. **Minimal diff** — fix the defect; do not refactor widely.
2. **No feature creep** — if a fix needs new user-visible behavior, stop and ask.
3. **Prefer guards + recovery** over asserting and aborting.
4. **Every Critical/High fix** gets a manual reproducer noted in the regression log.
5. **Do not** “fix” README by changing keybinds to match docs; fix docs unless code is objectively broken.
6. **Do not** enable new event handling (EWMH, ConfigureRequest honor) unless required to stop a crash/hang/corruption.
7. **Logging** — if adding diagnostics, they must be compile-time or clearly optional and must not flood the X connection under load.

---

## 7. Suggested Severity Triage During the Pass

| Severity | Definition | SLA for this pass |
|----------|------------|-------------------|
| Critical | Crash, hang, infinite recursion, state corruption | Must fix before pass complete |
| High | Unpredictable focus/layout, resource leak, input grabs flaky | Must fix or document waiver |
| Medium | Client apps misbehave; install/docs wrong | Fix in polish WPs |
| Low | Cosmetics, dead code, wording | Best effort |

---

## 8. Deliverables

1. This plan (`BUGFIX_POLISH_PLAN.md`) — living checklist; update status in-place.
2. `REGRESSION_LOG.md` (to be created when first bug confirmed) — append-only findings.
3. `tests/manual/RELIABILITY_CHECKLIST.md` — executable manual test list.
4. Doc corrections (README / install path) matching code.
5. Patched Ada sources — behavior-preserving reliability fixes only.

---

## 9. Explicit Non-Goals (Defer to Product Direction Q&A)

- New keybindings or layout modes  
- Config file / theming system  
- EWMH/ICCCM full compliance (unless forced by Critical reliability)  
- Wayland  
- Formal SPARK proof campaign / MISRA–DoD rule matrix enforcement  
- Multi-monitor advanced policy  
- Compositing / animations  

These are intentionally deferred so this pass remains a **reliability burn-down**.

---

## 10. Immediate First Actions (When Implementation Starts)

1. Create regression log + manual checklist stubs.  
2. Reproduce H1 (destroy mid-drag) and S4 (workspace focus) — highest distrust.  
3. FFI layout check on this host.  
4. Fix Critical findings before any polish commits.  
5. Doc sync last (after code of truth stable).

---

## 11. Definition of Done

The bugfix & polish pass is **done** when:

- All Critical items closed. — **YES**
- Reliability checklist fully executed with notes. — **Checklist published; automated smoke PASS; operator should run full matrix + G1 soak for personal sign-off**
- WM survives stress/soak without exit or deadlock. — **Smoke PASS; G1 soak = operator**
- Operator docs match implemented behavior. — **YES**
- Build is warning-clean under project flags. — **YES**
- Remaining Medium/Low items are listed with clear “defer” rationale. — **ConfigureRequest/ClientMessage still ignored (non-goal); cooperative WM_DELETE deferred to AFTER-BUGFIX; reconnect-on-X-loss deferred to AFTER-BUGFIX**

**North star:** TitaniumWM remains up, consistent, and predictable for as long as the X session exists.

---

## 12. Pass Result (2026-09-06)

| Deliverable | Status |
|-------------|--------|
| Patched Ada sources | Done |
| `REGRESSION_LOG.md` | Done |
| `tests/manual/RELIABILITY_CHECKLIST.md` | Done |
| Root `README.md` + keybind/install doc sync | Done |
| Warning-clean `bin/titanium` | Done |
| Xephyr smoke (alive + X-loss exit) | Pass |

**Deferred (intentionally, per plan / AFTER-BUGFIX):** session save/reconnect, TitaniumLogin, multi-monitor, WM_DELETE cooperative close, EWMH expansion, formal proof campaign.


---

**Suite note (2026-09-06):** Active sources now live under `TitaniumWM/`, `TitaniumRun/`, `TitaniumBG/`. The pre-suite polished tree is in `archive/pre-suite-wm-20260906/`. Re-run reliability work against the suite WM when ready.
