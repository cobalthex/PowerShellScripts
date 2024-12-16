function Get-User32Imports
{
    try {
        return [Win32.User32]
    } catch {
        return Add-Type -MemberDefinition @'
        [return: MarshalAs(UnmanagedType.Bool)]
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
        [return: MarshalAs(UnmanagedType.SysInt)]
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
'@ -Name User32 -Namespace Win32 -PassThru
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
        [Parameter(Mandatory=$true,Position=0)]
        [IntPtr]$Hwnd,
        [Parameter(Mandatory=$true,Position=1)]
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
        [Parameter(Mandatory=$true,Position=0)]
        [uint]$X,
        [Parameter(Mandatory=$true,Position=1)]
        [uint]$Y
    )

    return ($X -band 0xFFFF) + (($Y -band 0xFFFF) -shl 16);
}

function Open-FilePropertiesDialog
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
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