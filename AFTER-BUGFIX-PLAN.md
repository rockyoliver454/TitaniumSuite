# TitaniumWM — After Bugfix Plan

**Status: COMPLETE** (2026-09-06)  
**Prerequisite:** `BUGFIX_POLISH_PLAN.md` (pre-suite) + suite import of WM/Run/BG.  
**North star:** Reliability — never crash; predictable recovery; year-scale daily-driver bar.

---

## Implementation status

| Phase | Status | Delivered |
|-------|--------|-----------|
| **A — Freeze & Gate** | Done | Suite layout; `CODE_OF_TRUTH.md`; reliability patterns in suite WM |
| **B — Session Resilience** | Done | `session_persist` (`/tmp/titaniumwm.session`); IO handler → exit 75; open fail → 76; save on quit |
| **C — Client Contract** | Done | `wm_icccm`: Alt+Q soft close, Alt+Shift+Q kill; WM_DELETE_WINDOW; ConfigureRequest kept |
| **D — TitaniumLogin** | Done | `TitaniumLogin/` console DM + PAM + session.sh; returns to login on any WM exit |
| **E — Multi-Monitor** | Done | Per-screen worlds (Xinerama); Alt+,/. focus; Alt+Shift+,/. move |
| **F — Assurance** | Done | `CODING_STANDARD.md`; SPARK On/Off boundaries; compile-time config only |

---

## Product identity (locked)

| Piece | Role |
|-------|------|
| **TitaniumWM** | Window manager |
| **TitaniumRun** | Launcher (Alt+D) |
| **TitaniumBG** | Root wallpaper (session start) |
| **TitaniumLogin** | Console DM before X |

```text
boot → TitaniumLogin → X → titaniumbg & → titaniumwm
         ↑                                    │
         └──── exit 0/75/76 always returns ───┘
```

---

## Standing orders (still binding)

1. Reliability first  
2. Compile-time configuration only  
3. KISS + SPARK-shaped Ada  
4. Linux + FreeBSD primary  
5. WM ≠ DM  
6. Kill + safe close  
7. No compositing / animations / Wayland / GUI config / plugins  
8. Multi-monitor = per-screen worlds + movable clients  
9. Formal bars in spirit (see `CODING_STANDARD.md`)  
10. Year-scale daily-driver is the human acceptance test  

---

## How to run

```bash
./build-all.sh
./TitaniumWM/launch_protocol.sh
sudo ./install-all.sh
sudo titaniumlogin   # on a free VT
```

---

## One-line summary

Compile-time-only SPARK-minded Ada suite for Linux/FreeBSD: console TitaniumLogin, save→exit-to-login failure policy, light ICCCM kill+soft-close, per-screen multi-monitor, companions BG/Run — ready for daily-driver soak.
