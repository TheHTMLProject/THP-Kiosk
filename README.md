# THP Kiosk

THP Kiosk is a robust, security-focused Windows kiosk lock-down utility designed to enforce single-application usage while seamlessly handling idle session management and authorized exits. THP Kiosk also does not require any type of Windows admin approval, which allows it to be run and installed as a standard user.

**MacOS support coming soon!**

## Features

- **Application Lock-down:** Runs Microsoft Edge (or any designated custom executable) in a persistent, foreground-locked state.
- **Rogue Process Termination:** A background scanning loop closes unauthorized application windows (such as spawned command prompts or file viewers) if they attempt to display over your kiosk, while explicitly permitting the Windows shell surfaces needed for normal feedback like the volume flyout.
- **Task Manager Containment:** While the kiosk is running, Task Manager is closed on sight if launched, and the exit shortcut and standard task-switch combinations are intercepted. This is done without modifying Windows security policy keys, so no defense-evasion registry changes are made.
- **Smart Idle Detection:** Tracks actual hardware input (mouse and keyboard) across the entire OS. Automatically terminates and safely restarts your target application after a designated period of inactivity, protecting user privacy and resetting application states for the next user.
- **Idle Warning Auto-Cancel:** Before resetting an idle session, users are shown a 30-second warning popup. If they begin using the kiosk again, the popup auto-dismisses and safely resets the timers.
- **Secure PIN Exit Mechanism:** A customizable exit shortcut (`Ctrl+Shift+Key`) allows authorized administrators to enter a PIN to securely close the application and restore the full Windows Desktop. The PIN is stored only as a SHA-256 hash, never in plain text.
- **Restart Grace Periods:** In environments where a PIN is not required to exit, a warning popup notifies the user of the exit, and a system-level reboot can be scheduled to ensure session security upon departure.
- **Minimal Footprint:** Core execution scripts and startup triggers run minimized rather than hidden, so the tool stays out of the way without using the invisible-process patterns that security tools flag as malicious.

## Key Blocking Component

The key-combination blocking (Windows key, Alt+Tab, Alt+F4, Ctrl+Shift+Esc, and the configured exit shortcut) is provided by a small precompiled .NET assembly, `THPKioskHook.dll`, which ships alongside the scripts. Because it is precompiled, the kiosk never invokes a compiler at runtime, and it tracks modifier keys from its own event stream rather than polling global keyboard state. Both behaviors sharply reduce false-positive detections from endpoint security products.

To rebuild the assembly from source (`src/THPKioskHook.cs`), run:

```
powershell -ExecutionPolicy Bypass -File src\build-hook.ps1
```

This uses the in-box .NET Framework compiler, so no additional tooling is required.

## Application Control (WDAC and Smart App Control)

On systems that enforce Windows Defender Application Control (WDAC) or Smart App Control, an unsigned DLL may be blocked from loading. To keep the kiosk working everywhere, `kiosk.ps1` loads the precompiled `THPKioskHook.dll` first, and if Application Control blocks it, falls back to compiling the shipped `THPKioskHook.cs` at runtime. On fully locked-down fleets the correct fix is to sign the assembly (see below) or add it to the WDAC allow list, which removes the need for the runtime fallback.

## Testing in Windows Sandbox

`sandbox-test.wsb` launches the kiosk inside a disposable Windows Sandbox so it can be exercised without locking down your real desktop. Before using it, update the `HostFolder` path inside the `.wsb` to the location of your clone. The sandbox enforces Application Control, so it also exercises the runtime fallback described above. The test config uses exit PIN `1234`; press your exit shortcut (`Ctrl+Shift+Q`) and enter it to leave the kiosk.

## Endpoint Security and Code Signing

Kiosk lock-down tools use system APIs (a low-level keyboard hook, shell management) that can resemble malware to endpoint detection products such as CrowdStrike. This build removes the behaviors that most commonly drive false positives (runtime code compilation, hidden execution, security-policy registry edits, and stealth persistence).

For managed deployments, the most effective additional step is Authenticode signing:

- **Open-source projects** can obtain a free code-signing certificate through the SignPath Foundation, which then signs the release artifacts.
- **Self-owned or managed fleets** can use a self-signed certificate imported into the machine's Trusted Publishers store.

To sign the scripts and assembly with an installed certificate:

```
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Set-AuthenticodeSignature -FilePath src\kiosk.ps1 -Certificate $cert
Set-AuthenticodeSignature -FilePath src\config-gui.ps1 -Certificate $cert
Set-AuthenticodeSignature -FilePath src\THPKioskHook.dll -Certificate $cert
```

When the scripts are signed, launch them with `-ExecutionPolicy RemoteSigned` instead of `Bypass`.

## Installation

Run `THP Kiosk Setup-v1.0-windows-x86_64.exe` to deploy the required PowerShell scripts and key-blocking assembly, and to generate start menu and desktop shortcuts. The installer runs as a standard user and does not change the machine-wide PowerShell execution policy.

## Configuration

A fully visual Configuration GUI is provided (search for **THP Kiosk Config** in the Start Menu) to customize:
- Target Application (Edge Browser vs Custom `.exe`)
- Launch Arguments
- The specific `Ctrl+Shift+...` Exit Key mapping
- PIN requirements and the PIN itself
- Inactivity Timeout limits (in minutes)
- Post-exit automatic restart behaviors
