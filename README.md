# THP Kiosk

THP Kiosk is a robust, security-focused Windows kiosk lock-down utility designed to enforce single-application usage while seamlessly handling idle session management and authorized exits.

## Features

- **Application Lock-down:** Runs Microsoft Edge (or any designated custom executable) in a persistent, foreground-locked state.
- **Aggressive Rogue Process Termination:** Employs an aggressive background scanning loop that actively seeks out and kills unauthorized applications (e.g., Task Manager, Command Prompts, random executables) if they attempt to display windows over your kiosk.
- **Task Manager Exploitation Prevention:** Explicitly modifies the Windows Registry to disable Task Manager entirely while the Kiosk is running, plugging standard `Ctrl+Alt+Del` bypasses.
- **Smart Idle Detection:** Tracks actual hardware input (mouse and keyboard) across the entire OS. Automatically terminates and safely restarts your target application after a designated period of inactivity, protecting user privacy and resetting application states for the next user.
- **Idle Warning Auto-Cancel:** Before resetting an idle session, users are shown a 30-second warning popup. If they begin using the kiosk again, the popup auto-dismisses and safely resets the timers.
- **Secure PIN Exit Mechanism:** A completely customized exit shortcut (`Ctrl+Shift+Key`) allows authorized administrators to enter a PIN to securely close the application and restore the full Windows Desktop.
- **Restart Grace Periods:** In environments where a PIN is not required to exit, a warning popup notifies the user of the exit, and a system-level reboot is automatically scheduled to ensure session security upon departure.
- **Hidden Footprint:** Core execution scripts and startup triggers are hidden and operate completely invisibly, minimizing visual distractions and system interference.

## Installation

Run `THPKiosk-Setup.exe` to deploy the required PowerShell scripts, modify standard execution policies safely, and generate start menu and desktop shortcuts.

## Configuration

A fully visual Configuration GUI is provided (search for **THP Kiosk Config** in the Start Menu) to customize:
- Target Application (Edge Browser vs Custom `.exe`)
- Launch Arguments
- The specific `Ctrl+Shift+...` Exit Key mapping
- PIN requirements and the PIN itself
- Inactivity Timeout limits (in minutes)
- Post-exit automatic restart behaviors
