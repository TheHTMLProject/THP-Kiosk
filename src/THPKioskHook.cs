using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public static class KioskKeyboardHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;

    private const int VK_SHIFT = 0x10;
    private const int VK_CONTROL = 0x11;
    private const int VK_MENU = 0x12;
    private const int VK_LSHIFT = 0xA0;
    private const int VK_RSHIFT = 0xA1;
    private const int VK_LCONTROL = 0xA2;
    private const int VK_RCONTROL = 0xA3;
    private const int VK_LMENU = 0xA4;
    private const int VK_RMENU = 0xA5;

    private static IntPtr hookId = IntPtr.Zero;
    private static Thread pumpThread;
    public static bool ExitRequested = false;

    private static int exitVk = 0x51;

    private static bool ctrlDown = false;
    private static bool shiftDown = false;
    private static bool altDown = false;

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static LowLevelKeyboardProc _proc = HookCallback;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT { public int vkCode; public int scanCode; public int flags; public int time; public IntPtr dwExtraInfo; }

    public static void Configure(int exitVirtualKey) {
        exitVk = exitVirtualKey;
    }

    private static bool IsCtrl(int vk) { return vk == VK_CONTROL || vk == VK_LCONTROL || vk == VK_RCONTROL; }
    private static bool IsShift(int vk) { return vk == VK_SHIFT || vk == VK_LSHIFT || vk == VK_RSHIFT; }
    private static bool IsAlt(int vk) { return vk == VK_MENU || vk == VK_LMENU || vk == VK_RMENU; }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int msg = (int)wParam;
            KBDLLHOOKSTRUCT hookStruct = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            int vk = hookStruct.vkCode;

            bool isKeyDown = (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN);
            bool isKeyUp = (msg == WM_KEYUP || msg == WM_SYSKEYUP);

            if (IsCtrl(vk)) { if (isKeyDown) ctrlDown = true; else if (isKeyUp) ctrlDown = false; }
            else if (IsShift(vk)) { if (isKeyDown) shiftDown = true; else if (isKeyUp) shiftDown = false; }
            else if (IsAlt(vk)) { if (isKeyDown) altDown = true; else if (isKeyUp) altDown = false; }

            if (isKeyDown) {
                if (ctrlDown && shiftDown && vk == exitVk) { ExitRequested = true; return CallNextHookEx(hookId, nCode, wParam, lParam); }
                if (altDown && vk == 0x73) return (IntPtr)1;
                if (ctrlDown && shiftDown && vk == 0x1B) return (IntPtr)1;
                if (vk == 0x5B || vk == 0x5C) return (IntPtr)1;
                if (altDown && vk == 0x09) return (IntPtr)1;
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }

    public static void Install() {
        pumpThread = new Thread(() => {
            try {
                using (Process curProcess = Process.GetCurrentProcess())
                using (ProcessModule curModule = curProcess.MainModule) {
                    hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
                }
                Application.Run();
            } catch {}
        });
        pumpThread.IsBackground = true;
        pumpThread.SetApartmentState(ApartmentState.STA);
        pumpThread.Start();
        Thread.Sleep(200);
    }

    public static void Uninstall() {
        if (hookId != IntPtr.Zero) { UnhookWindowsHookEx(hookId); hookId = IntPtr.Zero; }
        Application.ExitThread();
    }
}

public static class NativeWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}

public static class IdleDetector {
    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetLastInputTime() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        if (GetLastInputInfo(ref info)) { return info.dwTime; }
        return 0;
    }

    public static int GetIdleSeconds() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        if (GetLastInputInfo(ref info)) {
            uint idleMs = (uint)Environment.TickCount - info.dwTime;
            return (int)(idleMs / 1000);
        }
        return 0;
    }
}
