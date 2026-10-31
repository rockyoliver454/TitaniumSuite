# Titanium Suite

Four **separate** KISS Ada tools. No shared libraries between them — process spawn / session scripts only.

| Tool | Directory | Binary | Role |
|------|-----------|--------|------|
| **TitaniumBG** | `TitaniumBG/` | `titaniumbg` | Procedural root wallpaper |
| **TitaniumRun** | `TitaniumRun/` | `titaniumrun` | Run launcher (**Alt+D**) |
| **TitaniumWM** | `TitaniumWM/` | `titanium` → `titaniumwm` | Tiling WM |
| **TitaniumLogin** | `TitaniumLogin/` | `titaniumlogin` | Console DM (before X) |

## Quick start

```bash
./build-all.sh
./TitaniumWM/launch_protocol.sh    # Xephyr: BG + WM + xterm
```

System install:

```bash
sudo ./install-all.sh
```

Console login path (root VT):

```bash
sudo titaniumlogin
```

## How they connect

```text
titaniumlogin → Xorg :N → /usr/lib/titanium/session.sh
                              ├─ titaniumbg &
                              └─ exec titaniumwm
                                    ├─ Alt+D → titaniumrun &
                                    └─ Alt+Enter → xterm &
```

Failure policy (WM): save session → reconnect attempt → exit **75/76** → Login returns to prompt.

## Key docs

| Doc | Purpose |
|-----|---------|
| `CODING_STANDARD.md` | DoD / NASA / MISRA / SPARK philosophy checklist |
| `AFTER-BUGFIX-PLAN.md` | Product roadmap (now implemented) |
| `TitaniumWM/CODE_OF_TRUTH.md` | Keybinds / exit codes |
| `TitaniumLogin/README.md` | DM usage |

## Design rules

- Compile-time configuration only  
- Kill + soft close (Alt+Q / Alt+Shift+Q)  
- Per-screen multi-monitor worlds (Xinerama; Alt+,/.)  
- No compositing, Wayland, GUI config, scripting/plugins  
