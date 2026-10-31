# Security — Titanium Suite

Threat model for the four-tool desktop stack.

## Surfaces

| Surface | Trust boundary |
|---|---|
| `titaniumlogin` | **Root**, before X. PAM auth, VT handoff to a spawned
Xorg, then `/usr/lib/titanium/session.sh` as the target user. |
| `titaniumwm` | Runs as the logged-in user. Grabs Alt-modifier keys
and buttons globally; handles raw X11 events via unchecked
conversions on the `XEvent` union — a malformed event stream is
the main attack surface. |
| `titaniumrun` | Launcher: completes and spawns commands as the
user — it inherits the user's full authority, like any run box. |
| `titaniumbg` | Root-window renderer: software vGPU writes into an
XImage on the root window only. |

## Design controls

- **Compile-time configuration only** — no runtime config parsers,
  no scripting/plugin engines; nothing to inject through.
- **KISS binaries, no shared state** — the four tools never share
  libraries; they compose by process spawn only.
- **`launch_auth.dat` gate** — `launch_protocol.sh` verifies a pinned
  SHA-256 checksum before starting the Xephyr test session and
  refuses to run on mismatch.
- **Bounded tables, SPARK policy** — workspace/window/pixel state is
  fixed-size; the vGPU core runs `SPARK_Mode => On` (bounds-checked
  pixels, no unchecked writes into the framebuffer).
- **Session exit codes** — WM exits 75/76 on session loss so the
  display manager returns to the login prompt instead of respawning
  into a broken state.

## Reporting

Report issues privately to **contact@alb-lang.org** — do not open
public issues for exploit-relevant findings.
