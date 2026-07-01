# Release Notes - THP Kiosk

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
