# TitaniumWM — Manual Reliability Checklist

Run inside Xephyr via `./launch_protocol.sh` unless noted.  
Mark each item: **PASS** / **FAIL** / **WAIVE** (with note).

**Build under test:** `./build.sh` with `-gnat2012 -gnatwa` (zero warnings required).

---

## A. Startup / Shutdown

| # | Scenario | Result |
|---|----------|--------|
| A1 | Launch via `launch_protocol.sh` | |
| A2 | Quit with Alt+Shift+Esc | |
| A3 | Start with `DISPLAY` unset / bad display — process exits cleanly (no partial grab) | |
| A4 | Kill Xephyr while WM running — process exits (no zombie spin) | |

## B. Client lifecycle

| # | Scenario | Result |
|---|----------|--------|
| B1 | Alt+Enter spawn xterm; tab + border appear | |
| B2 | Alt+Q destroys focused client; tab gone; focus recovers | |
| B3 | Close client via its own UI; Unmap/Destroy cleans state | |
| B4 | `xkill` a managed window; WM survives; no ghost tab | |
| B5 | Rapid map/unmap storm (script or mash); no hang | |
| B6 | Open 64 clients; 65th maps but is unmanaged; no crash | |

## C. Focus / workspace

| # | Scenario | Result |
|---|----------|--------|
| C1 | Alt+Left/Right cycles only current workspace | |
| C2 | Switch to empty workspace; no crash; focus empty | |
| C3 | Switch back; previous clients visible | |
| C4 | Alt+Shift+N moves focused client; monocle shows correct focus | |
| C5 | Move last client off workspace; focus clears/recovers | |
| C6 | CapsLock ON — all binds still work | |
| C7 | NumLock ON — all binds still work | |

## D. Layout

| # | Scenario | Result |
|---|----------|--------|
| D1 | Alt+M monocle; only focused mapped; tabs visible | |
| D2 | Alt+H tiled; all tiled clients visible | |
| D3 | Alt+Ctrl+Space float; Alt+H clears float | |
| D4 | Resize mode: master factor clamps at edges | |
| D5 | Resize mode: stack ratio up/down clamps | |
| D6 | Floating client survives workspace leave/return (still mapped on return) | |

## E. Pointer

| # | Scenario | Result |
|---|----------|--------|
| E1 | Alt+LMB move floating | |
| E2 | Alt+RMB resize floating (min size honored) | |
| E3 | Destroy window mid-drag — loop exits; WM alive | |
| E4 | Release outside Xephyr — drag ends | |

## F. Screen geometry

| # | Scenario | Result |
|---|----------|--------|
| F1 | Resize Xephyr / root ConfigureNotify; layout updates | |
| F2 | Very small root size — no crash; minimum floors apply | |

## G. Soak (gate)

| # | Scenario | Result |
|---|----------|--------|
| G1 | ≥ 1 hour idle with periodic spawn/kill — no exit, no hang | |
| G2 | Key-repeat storm on focus keys — stable | |

---

## Sign-off

- Date:
- Tester:
- Binary sha256:
- Notes:
