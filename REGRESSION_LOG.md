# TitaniumWM — Regression Log

Append-only log from the bugfix / polish pass.  
**Code of truth for keybinds:** `src/wm_keys.adb` (docs must match code).

---

### ID: S1 / C3
**Title:** Focus index corruption after `Remove_Client` compaction  
**Reproducer:** Focus client 3; remove client 1 or 2; focus pointer no longer matches intended window / workspace.  
**Expected:** Focus tracks the same logical client, or recovers to a valid client on the current workspace.  
**Actual:** Focus stayed at a stale index or snapped to slot 1 blindly.  
**Root cause:** Array compact shifted clients down; focus was not decremented when `Focused_Client > Idx`.  
**Fix approach:** Adjust focus relative to removed index; call `Recover_Focus` / workspace-aware `Next_Focus`.  
**Risk to reliability:** Critical (wrong window receives keys; possible BadWindow).  
**Status:** fixed

---

### ID: C6 / H1
**Title:** Nested drag/resize loop can hang forever  
**Reproducer:** Alt+drag a window; destroy the client (xkill / Alt+Q from another path) before ButtonRelease.  
**Expected:** Drag ends; WM continues event loop.  
**Actual:** Nested `XNextEvent` waited indefinitely for release.  
**Root cause:** Loop only exited on ButtonRelease (type 5).  
**Fix approach:** Exit on DestroyNotify/Unmap of target, missing client, or ButtonRelease; then retile.  
**Risk to reliability:** Critical (WM stops responding).  
**Status:** fixed

---

### ID: C2
**Title:** Tab label `Character'Val(48 + I)` invalid for I > 9  
**Reproducer:** Map 10+ clients; inspect tab titles.  
**Expected:** Readable label for every index.  
**Actual:** Non-decimal / invalid character values for indices ≥ 10.  
**Root cause:** Single-digit ASCII assumption.  
**Fix approach:** `Integer'Image` based label.  
**Risk to reliability:** High (exception potential / garbage UI).  
**Status:** fixed

---

### ID: S8
**Title:** `Height_Ratio` unbounded on resize-mode Down  
**Reproducer:** Alt+R, hold Alt+Down.  
**Expected:** Ratio stays within a defined clamp (symmetric with lower bound).  
**Actual:** Grew without upper bound → layout jitter / extreme geometry.  
**Root cause:** Only lower clamp existed.  
**Fix approach:** `Clamp_Height_Ratio` with max 10.0; `Clamp_Master_Factor` helper.  
**Risk to reliability:** High (unpredictable geometry).  
**Status:** fixed

---

### ID: X5
**Title:** Key/button grabs fail when CapsLock/NumLock active  
**Reproducer:** Enable NumLock; try Alt+Enter / Alt+arrows.  
**Expected:** Bindings work regardless of Lock/Mod2.  
**Actual:** Grabs missed; input appeared “randomly broken.”  
**Root cause:** Grabbed only exact modifier masks.  
**Fix approach:** Grab LockMask/Mod2Mask variants for keys and buttons.  
**Risk to reliability:** High (unpredictable control).  
**Status:** fixed

---

### ID: C5
**Title:** Unsafe geometry / unsigned casts on tiny screens  
**Reproducer:** Root ConfigureNotify with very small W/H; or extreme master factor.  
**Expected:** Minimum safe sizes; no negative widths fed to X.  
**Actual:** Possible degenerate sizes.  
**Fix approach:** Floor display size at 64px in layout/init; `Safe_Unsigned`; master width clamps.  
**Risk to reliability:** Critical.  
**Status:** fixed

---

### ID: C10
**Title:** `Text_GC` initialized from `Global_Display` before open  
**Reproducer:** Elaboration order / misuse before `Init_Graphics`.  
**Expected:** GC null until created.  
**Actual:** Display address cast to GC.  
**Fix approach:** Initialize to `System.Null_Address`.  
**Risk to reliability:** High.  
**Status:** fixed

---

### ID: D1 / D2 / D3
**Title:** Docs and install path mismatched code/layout  
**Reproducer:** Follow README floating bind; run `release/install.sh` looking for `./bin/titanium`.  
**Expected:** Docs match code; install finds `release/bin/titanium`.  
**Actual:** Alt+Space documented (code is Alt+Ctrl+Space); install path wrong; stack reorder undocumented.  
**Root cause:** Doc drift; relative path from `release/`.  
**Fix approach:** README sync; script-relative paths.  
**Risk to reliability:** High (operator unpredictability).  
**Status:** fixed

---

### ID: C4
**Title:** Alt+Q destroy + Remove_Client vs late DestroyNotify  
**Reproducer:** Alt+Q focused window.  
**Expected:** Single cleanup; second DestroyNotify is harmless.  
**Actual:** Already mostly safe (`Find_Client` → 0); clarified with stable Victim id + Apply_Focus after.  
**Root cause:** Ordering sensitivity.  
**Fix approach:** Capture window id; Remove_Client idempotent; retile + focus recover.  
**Risk to reliability:** High.  
**Status:** fixed

---

### ID: H4
**Title:** Focus scan with empty/invalid start index  
**Reproducer:** Switch to empty workspace; Next/Prev focus.  
**Expected:** Deterministic empty focus or first client when present.  
**Actual:** Edge cases around `Focused_Client = 0`.  
**Root cause:** Start index assumptions.  
**Fix approach:** Normalize start; bound scans to `Client_Count`; `Focus_Is_Valid` / `Recover_Focus`.  
**Risk to reliability:** High.  
**Status:** fixed

---

### ID: C7 / C1
**Title:** XEvent storage vs Xlib 192-byte union  
**Reproducer:** Platform FFI audit (`sizeof(XEvent)=192` on LP64).  
**Expected:** Ada object ≥ 192 bytes; header fields match XAnyEvent.  
**Actual:** Layout matched header; padding oversized (safe). Added size assert.  
**Root cause:** Hand-rolled bindings.  
**Fix approach:** Keep ≥ 24 longs padding; `pragma Assert` on size; reuse `X11.XDestroyWindowEvent`.  
**Risk to reliability:** Critical if undersized (not observed).  
**Status:** fixed

---

### ID: R4
**Title:** Behavior at Max_Clients (64)  
**Reproducer:** Map 65th window.  
**Expected:** No crash; defined behavior.  
**Actual:** Window mapped but unmanaged (intentional KISS).  
**Root cause:** Fixed table.  
**Fix approach:** Documented in checklist; Add_Client guards; still maps for visibility.  
**Risk to reliability:** High if crashed (does not).  
**Status:** fixed (documented; no crash)

---

### ID: Exception survival
**Title:** Unhandled Ada exception terminates WM  
**Reproducer:** Any unexpected exception in handler.  
**Expected:** Loop continues after safe retile attempt.  
**Actual:** Process abort.  
**Root cause:** No handler around event dispatch.  
**Fix approach:** Exception frame per iteration + nested safe retile.  
**Risk to reliability:** Critical.  
**Status:** fixed

---

### ID: Display death
**Title:** X IO error default abort path  
**Reproducer:** Kill Xephyr under running WM.  
**Expected:** Controlled process exit (reconnect is AFTER-BUGFIX).  
**Actual:** Default Xlib abort behavior.  
**Root cause:** No IO error handler.  
**Fix approach:** `XSetIOErrorHandler` → set Running false + `exit(1)` (must not return).  
**Risk to reliability:** High.  
**Status:** fixed (clean exit; reconnect deferred)
