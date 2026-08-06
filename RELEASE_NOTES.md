# Release Notes - THP Kiosk

## Version 1.1 - Antivirus Compatibility and Hardening

This release resolves reports of endpoint security products (such as CrowdStrike) flagging THP Kiosk as malicious. The kiosk functionality is unchanged for end users; the changes remove the behaviors and packaging patterns that most commonly trigger false positives.

* **Precompiled Key-Blocking Assembly:** The low-level keyboard hook is now shipped as a precompiled .NET assembly (`THPKioskHook.dll`) instead of being compiled from source at runtime. The kiosk no longer invokes a compiler at launch, which was the single strongest detection signal.
* **No Global Key Polling:** The hook now tracks modifier keys from its own event stream rather than reading global keyboard state, avoiding a keylogger-style access pattern.
* **Visible, Minimized Execution:** Scripts run minimized rather than fully hidden. The invisible-process patterns (`ShowWindow` hide, blanket `-WindowStyle Hidden`) have been removed.
* **No Security-Policy Registry Edits:** The kiosk no longer disables Task Manager via the `DisableTaskMgr` policy key. Task Manager is instead contained by closing it if launched and by intercepting `Ctrl+Shift+Esc`.
* **Cleaner Persistence:** Startup entries are no longer marked hidden or system, and the redundant registry Run key has been removed in favor of a single visible Startup shortcut.
* **No Machine-Wide Execution Policy Change:** The installer no longer sets a persistent CurrentUser execution policy; scripts run with a transient per-invocation policy.
* **Hashed Exit PIN:** The exit PIN is now stored as a SHA-256 hash instead of plain text. Existing plain-text PINs are migrated automatically.
* **Tighter Lock-down:** The process allowlist no longer broadly permits `cmd`, `powershell`, or `wscript` windows; spawned shells are closed, while genuine Windows shell surfaces (including the volume flyout host) are permitted so on-screen volume feedback works again.
* **Code Signing Guidance:** Documentation now covers free Authenticode signing via the SignPath Foundation for open-source projects, plus a self-signed path for managed fleets.

## Major Feature Additions
* **Complete System Invisibility:** Transitioned core execution completely away from visible terminal prompts. All launch actions, configuration GUI interactions, and startup scripts operate silently without flashing standard console windows.
* **Aggressive App Whitelisting:** Implemented an aggressive sub-second loop that hunts and kills unauthorized GUI applications and rogue executables. Only approved Kiosk software (and standard OS shells) are permitted to draw to the screen.
* **Auto-Canceling Idle Timers:** Idle timeouts now feature smart OS-level interrupt detection. If the warning popup is shown and a user interacts with the system, the timer seamlessly auto-cancels and resets tracking parameters in the background.
* **Customizable Security Exits:** Replaced hardcoded exit paths with a fully customizable dropdown matrix in the configuration menu. Administrators can now map exit combinations to specific keystrokes (`Ctrl+Shift+[Q, W, E, X, Z, ESC]`).

## Security & Reliability Improvements
* **Task Manager Exploit Patched:** Patched a critical bypass where users could invoke the `Ctrl+Alt+Del` hardware interrupt to spawn an elevated Task Manager instance. The Kiosk now aggressively modifies the Windows Registry to disable Task Manager entirely while running, preventing elevated takeovers.
* **Multi-Window Launcher Loop Fix:** Fixed an edge-case logic flaw where target applications that rely on immediate background handoffs (such as Microsoft Edge or custom Chromium wrappers) were incorrectly identified as crashed, causing an infinite process spawning loop. Application viability is now verified via visible window handle tracking instead of process ID persistence.
* **Cancel/Minimize State Recovery:** Patched an error where cancelling an exit attempt left the target application minimized or invisible. 
* **Startup Redundancy:** Reinforced auto-start mechanics by backing up the standard Windows Startup directory trigger with an active `HKCU...Run` Registry hook.
* **Explorer Recovery:** Resolved an issue where closing the Kiosk would occasionally spawn standard file-explorer directory windows rather than restoring the proper desktop shell.
