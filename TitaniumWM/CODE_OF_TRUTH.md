# Code of Truth — TitaniumWM (Suite)

Compile-time behavior as implemented in `TitaniumWM/src/`. Docs must match this file when they disagree with marketing text.

## Binaries

| Name | Role |
|------|------|
| `titanium` / `titaniumwm` | Window manager |
| `titaniumrun` | Launcher (Alt+D) |
| `titaniumbg` | Root wallpaper (session start) |
| `titaniumlogin` | Console DM (before X) |

## Modifier

Mod1 = Alt. Grabs should include Lock/NumLock variants where implemented.

## Keybinds

| Binding | Action |
|---------|--------|
| Alt+Enter | `xterm &` |
| Alt+D | `titaniumrun &` |
| Alt+Q | Soft close (WM_DELETE_WINDOW if supported, else destroy) |
| Alt+Shift+Q | Force kill focused client |
| Alt+Shift+Esc | Quit WM (save session, exit 0) |
| Alt+R | Toggle resize mode |
| Alt+M | Monocle |
| Alt+H | Tiled + clear floating |
| Alt+Ctrl+Space | Toggle floating |
| Alt+Arrows | Focus / resize-mode adjust |
| Alt+Shift+Arrows | Reorder stack |
| Alt+[1-9,0,-,=] | Switch workspace (active screen) |
| Alt+Shift+[1-9,0,-,=] | Move client to workspace |
| Alt+, / Alt+. | Focus previous/next screen |
| Alt+Shift+, / Alt+Shift+. | Move focused client to previous/next screen |
| Alt+LMB / RMB | Float move / resize |

## Session files

- Path: `/tmp/titaniumwm.session` (compile-time constant)
- Not a user config language — bounded recovery blob only

## Exit codes

0 normal · 75 display lost · 76 reconnect/open failed
