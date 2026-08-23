function Get-User32Imports
{
    try {
        return [Win32.User32]
    } catch {
        return (Add-Type -MemberDefinition @'
        [return: MarshalAs(UnmanagedType.Bool)]
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [return: MarshalAs(UnmanagedType.SysInt)]
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(
            IntPtr hWnd,
            IntPtr hWndInsertAfter,
            int X,
            int Y,
            int cx,
            int cy,
            uint flags);

        [DllImport("user32.dll")]
        public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

        [DllImport("user32.dll")]
        public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);

        [DllImport("user32.dll")]
        public static extern bool EnumDisplayMonitors(
            IntPtr hdc,
            IntPtr lprcClip,
            MonitorEnumProc lpfnEnum,
            IntPtr dwData);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, IntPtr rect, IntPtr data);

        public const uint SWP_NOZORDER = 0x0004;
        public const uint SWP_NOACTIVATE = 0x0010;

        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        public struct MONITORINFO
        {
            public int cbSize;
            public RECT rcMonitor;
            public RECT rcWork;
            public uint dwFlags;
        }

        public static System.Collections.Generic.List<IntPtr> GetMonitors()
        {
            var monitors = new System.Collections.Generic.List<IntPtr>();

            EnumDisplayMonitors(
                IntPtr.Zero,
                IntPtr.Zero,
                (h, dc, r, d) => {
                    monitors.Add(h);
                    return true;
                },
                IntPtr.Zero);

            return monitors;
        }
'@ -Name User32 -Namespace Win32 -PassThru)[0]
    }
}

<#
.SYNOPSIS
Post (don't wait for it to be handled) a message to a window

.EXAMPLE
Invoke-WindowCommand -Hwnd 0x10000 -Command 0x007B
#>
function Invoke-WindowCommand
{
    param(
        [Parameter(Mandatory, Position=0)]
        [IntPtr]$Hwnd,
        [Parameter(Mandatory, Position=1)]
        [uint]$Command,
        [IntPtr]$WParam = 0,
        [IntPtr]$LParam = 0,
        [Switch]$Wait
    )

    $user32 = Get-User32Imports

    if ($Wait)
    {
        $user32::SendMessage($Hwnd, $Command, $WParam, $LParam)
    }
    else
    {
        $user32::PostMessage($Hwnd, $Command, $WParam, $LParam)
    }
}

function Convert-MouseToLParam
{
    param(
        [Parameter(Mandatory, Position=0)]
        [uint]$X,
        [Parameter(Mandatory, Position=1)]
        [uint]$Y
    )

    return ($X -band 0xFFFF) + (($Y -band 0xFFFF) -shl 16);
}

function Open-FilePropertiesDialog
{
    param(
        [Parameter(Mandatory,  Position=0)]
        [string]$Path
    )

    $entry = Get-Item -Path $Path

    $o = new-object -com Shell.Application

    if ($entry -is [IO.FileInfo])
    {
        $folder = $o.NameSpace([IO.Path]::GetDirectoryName($entry.FullName))
        $fo = $folder.ParseName($entry.Name)
        $fo.InvokeVerb("Properties")
    }
    else
    {
        $folder = $o.NameSpace($entry.FullName)
        $folder.Self.InvokeVerb("Properties")
    }
}

function Gather-ProcessWindows
{
    param(
        [Parameter(Mandatory, Position=0)]
        $Process,
        [Parameter(Position=1)]
        [int]$MonitorIndex = -1
    )

    $user32 = Get-User32Imports

    $procPid = switch ($Process.GetType())
    {
        ([System.Diagnostics.Process]) { $_.Id }
        ([string]) { (Get-Process $Process | Select-Object -First 1).Id }
        default { [int]$_ }
    }

    $monitors = $user32::GetMonitors()

    if ($MonitorIndex -ge 0)
    {
        if ($MonitorIndex -ge $monitors.Count)
        {
            throw "Monitor index out of range"
        }
        $targetMonitor = $monitors[$MonitorIndex]
    }
    else
    {
        $fgWin = $user32::GetForegroundWindow()
        $targetMonitor = $user32::MonitorFromWindow($fgWin, 2)
    }

    $targetMI = New-Object Win32.User32+MONITORINFO
    $targetMI.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($targetMI)
    $user32::GetMonitorInfo($targetMonitor, [ref]$targetMI) | Out-Null

    Write-Verbose "Gathering all windows for PID $procPid on monitor $targetMonitor"

    $tLeft   = $targetMI.rcWork.Left
    $tTop    = $targetMI.rcWork.Top
    $tWidth  = $targetMI.rcWork.Right  - $targetMI.rcWork.Left
    $tHeight = $targetMI.rcWork.Bottom - $targetMI.rcWork.Top

    $user32::EnumWindows(
    {
        param($hwnd, $l)

        if (-not $user32::IsWindowVisible($hwnd)) { return $true }

        $winPid = 0
        $user32::GetWindowThreadProcessId($hwnd, [ref]$winPid) | Out-Null
        if ($winPid -ne $procPid) { return $true }

        $rect = New-Object Win32.User32+RECT
        $user32::GetWindowRect($hwnd, [ref]$rect) | Out-Null

        $srcMon = $user32::MonitorFromWindow($hwnd, 2)

        $srcMI = New-Object Win32.User32+MONITORINFO
        $srcMI.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($srcMI)
        $user32::GetMonitorInfo($srcMon, [ref]$srcMI) | Out-Null

        $sLeft   = $srcMI.rcWork.Left
        $sTop    = $srcMI.rcWork.Top
        $sWidth  = $srcMI.rcWork.Right  - $srcMI.rcWork.Left
        $sHeight = $srcMI.rcWork.Bottom - $srcMI.rcWork.Top

        # maintain relative position
        $relX = ($rect.Left - $sLeft) / [double]$sWidth
        $relY = ($rect.Top  - $sTop ) / [double]$sHeight

        $newX = [int]($tLeft + $relX * $tWidth)
        $newY = [int]($tTop  + $relY * $tHeight)

        $w = $rect.Right - $rect.Left
        $h = $rect.Bottom - $rect.Top

        $user32::SetWindowPos(
            $hwnd,
            [IntPtr]::Zero,
            $newX,
            $newY,
            $w,
            $h,
            $user32::SWP_NOZORDER -bor $user32::SWP_NOACTIVATE
            ) | Out-Null

        return $true
    }, [IntPtr]::Zero) | Out-Null
}