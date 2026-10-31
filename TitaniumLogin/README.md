# TitaniumLogin

Console / terminal **display manager** for the Titanium suite. Runs **before X**, authenticates a user, starts an X server, hands off to the Titanium session (`titaniumbg` + `titaniumwm`), and when the WM exits (including failure codes 75 / 76), returns to the login prompt. Never abandons the user on a dead graphical session.

```text
boot → console → TitaniumLogin → Xorg :N → session.sh → titaniumbg & / exec titaniumwm
                      ↑                                              │
                      └──────────── WM exit / display lost ──────────┘
```

## Requirements

- **Must typically run as root** (PAM conversation + `setuid`/`setgid` into the authenticated user).
- Linux or FreeBSD; Ada 2012 (`gnatmake`); `libpam` at link time.
- Xorg or `/usr/bin/X`, and ideally `xdpyinfo` for readiness probes.
- No GUI config, no Wayland — compile-time constants only (`src/config.ads`).

## Build

```bash
./build.sh
# → bin/titaniumlogin
```

Links `-lpam` (and `-lutil` when available). PAM C headers (`pam_appl.h`) are **not** required: bindings are hand-written in Ada (`pam_thin.ads`).

If the build machine lacks a PAM development package (`libpam.so` symlink), `build.sh` falls back to linking `libpam.so.0` by soname. Prefer installing `libpam0g-dev` (Debian/Ubuntu) or equivalent so `-lpam` resolves normally.

## PAM service

Compile-time service name defaults to `titaniumlogin` (`Config.Pam_Service`). Until a dedicated stack exists, rebuild with `"login"` or install e.g. `/etc/pam.d/titaniumlogin` (Linux) mirroring `login`.

## Session script

`session.sh` is shipped here and is expected at the compile-time path:

`/usr/lib/titanium/session.sh`

Override by editing `Config.Session_Script` and rebuilding. `install-all` will copy the script later. Contents:

```sh
titaniumbg &
exec titaniumwm
```

## Run (conceptual)

```bash
sudo ./bin/titaniumlogin   # on a free VT, before a graphical login manager
```

## Exit code contract (with TitaniumWM)

| Code | Meaning (WM side) | Login behavior |
|------|-------------------|----------------|
| 75 | Display lost | Return to login prompt |
| 76 | Session failure | Return to login prompt |
| other | Normal or other exit | Return to login prompt |

## Layout

| Path | Role |
|------|------|
| `src/main.adb` | Login loop |
| `src/config.ads` | Compile-time constants |
| `src/pam_thin.*` | libpam FFI (no pam_appl.h) |
| `src/posix_thin.*` | fork/exec/termios/setuid |
| `src/auth.*` | PAM authenticate sequence |
| `src/display_mgr.*` | Free display, start/stop X |
| `src/session.*` | User session handoff |
| `session.sh` | Session helper (install target) |
| `bin/` `obj/` | Build outputs |

## CODING notes

- **KISS / Ada 2012** — small packages, explicit control flow, FFI at clear SPARK Off boundaries.
- **Compile-time config only** — no runtime conf files, no plugins.
- **Portable structure** — POSIX + PAM habits shared by Linux and FreeBSD; isolate OS-specific constants in thin packages.
- **Warnings** — build with `-gnatwa`; treat warnings as signal.
- **Security surface** — password echo disabled via termios; scrub password buffers after use; drop privileges before session exec.
- **Reliability** — outer loop always returns to the banner after session/X teardown.

## License

Same suite license as TitaniumWM (`TitaniumWM/release/bin/LICENSE.md`).
