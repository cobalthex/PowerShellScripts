function Get-WindowLayerDllImports {
    try {
        return [Win32.WindowLayer]
    } catch {
        return Add-Type -MemberDefinition @'
            [DllImport('user32.dll")]
            public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

            [DllImport("user32.dll")]
            public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

            [DllImport("user32.dll")]
            public static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags);
'@ -Name WindowLayer -Namespace Win32 -PassThru
    }
}

function Set-WindowTransparency {
     param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Process', ValueFromPipeline = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Window', ValueFromPipeline = $true)]
        [System.IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(0.01, 1)]
        [float]$Opacity
    )

     $ov = [int]($Opacity * 255)

    $Win32Type = Get-WindowLayerDllImports

    $hwnd = if ($PSCmdlet.ParameterSetName -eq 'From Window') { $WindowHandle } else { $Process.MainWindowHandle }
    Write-Verbose "Setting opacity for HWND $hwnd to $ov"

    $GwlExStyle  = -20;
    $WsExLayered = 0x80000;
    $LwaAlpha    = 0x2; # LWA_ALPHA

    [void]$Win32Type::SetWindowLong($hwnd, $GwlExStyle, $Win32Type::GetWindowLong($hwnd,$GwlExStyle) -bor $WsExLayered)
    [void]$Win32Type::SetLayeredWindowAttributes($hwnd, 0, $ov, $LwaAlpha)
}

# clears layered attribute
function Reset-WindowTransparency {
     param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Process', ValueFromPipeline = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Window', ValueFromPipeline = $true)]
        [System.IntPtr]$WindowHandle
    )

    $Win32Type = Get-WindowLayerDllImports

    $hwnd = if ($PSCmdlet.ParameterSetName -eq 'From Window') { $WindowHandle } else { $Process.MainWindowHandle }
    Write-Verbose "Resetting window layering for HWND $hwnd"

    $GwlExStyle  = -20;
    $WsExLayered = 0x80000;
    $LwaAlpha    = 0x2;

    [void]$Win32Type::SetWindowLong($hwnd, $GwlExStyle, $Win32Type::GetWindowLong($hwnd,$GwlExStyle) -band -bnot $WsExLayered)
}

function Get-WindowCompositionDllImports {
    try {
        return [Win32.WindowComposition]
    } catch {
        return Add-Type -MemberDefinition @'
            // undocumented API
            [DllImport("user32.dll")]
            static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

            enum AccentState
            {
                ACCENT_DISABLED = 0,
                ACCENT_ENABLE_GRADIENT = 1,
                ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
                ACCENT_ENABLE_BLURBEHIND = 3,
                ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
                ACCENT_INVALID_STATE = 5
            }

            [StructLayout(LayoutKind.Sequential)]
            struct AccentPolicy
            {
                public AccentState AccentState;
                public uint AccentFlags;
                public uint GradientColor;
                public uint AnimationId;
            }

            [StructLayout(LayoutKind.Sequential)]
            struct WindowCompositionAttributeData
            {
                public WindowCompositionAttribute Attribute;
                public IntPtr Data;
                public int SizeOfData;
            }

            enum WindowCompositionAttribute
            {
                // ...
                WCA_ACCENT_POLICY = 19
                // ...
            }

            public static void EnableAcrylic(IntPtr hwnd, uint backgroundColor, byte opacity)
            {
                var accent = new AccentPolicy
                {
                    AccentState = AccentState.ACCENT_ENABLE_ACRYLICBLURBEHIND,
                    GradientColor = ((uint)(opacity << 24) | (backgroundColor & 0xFFFFFF)),
                };

                var accentStructSize = Marshal.SizeOf(accent);

                var accentPtr = Marshal.AllocHGlobal(accentStructSize);
                Marshal.StructureToPtr(accent, accentPtr, false);

                var attrData = new WindowCompositionAttributeData
                {
                    Attribute = WindowCompositionAttribute.WCA_ACCENT_POLICY,
                    SizeOfData = accentStructSize,
                    Data = accentPtr,
                };

                SetWindowCompositionAttribute(hwnd, ref attrData);

                Marshal.FreeHGlobal(accentPtr);
            }

            public static void DisableAcrylic(IntPtr hwnd)
            {
                var accent = new AccentPolicy
                {
                    AccentState = AccentState.ACCENT_DISABLED,
                };

                var accentStructSize = Marshal.SizeOf(accent);

                var accentPtr = Marshal.AllocHGlobal(accentStructSize);
                Marshal.StructureToPtr(accent, accentPtr, false);

                var attrData = new WindowCompositionAttributeData
                {
                    Attribute = WindowCompositionAttribute.WCA_ACCENT_POLICY,
                    SizeOfData = accentStructSize,
                    Data = accentPtr,
                };

                SetWindowCompositionAttribute(hwnd, ref attrData);

                Marshal.FreeHGlobal(accentPtr);
            }
'@ -Name WindowComposition -Namespace Win32 -PassThru
    }
}

function Set-WindowAcrylic {
     param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Process', ValueFromPipeline = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Window', ValueFromPipeline = $true)]
        [System.IntPtr]$WindowHandle,

        [uint]$Color = 0x002244,
        [ValidateRange(0.01, 1)]
        [float]$Opacity
    )

    $Win32Type = Get-WindowCompositionDllImports

    $hwnd = if ($PSCmdlet.ParameterSetName -eq 'From Window') { $WindowHandle } else { $Process.MainWindowHandle }
    Write-Verbose "Enabling acrylic blur-behind for HWND $hwnd"


    $Win32Type::EnableAcrylic($hwnd, $Color, [byte]($Opacity * 255))
}

function Reset-WindowAcrylic {
     param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Process', ValueFromPipeline = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'From Window', ValueFromPipeline = $true)]
        [System.IntPtr]$WindowHandle
    )

    $Win32Type = Get-WindowCompositionDllImports

    $hwnd = if ($PSCmdlet.ParameterSetName -eq 'From Window') { $WindowHandle } else { $Process.MainWindowHandle }
    Write-Verbose "Disabling acrylic blur-behind for HWND $hwnd"

    $Win32Type::DisableAcrylic($hwnd)
}

function Is-FileVirtual {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [System.IO.FileInfo]$File
    )

    $File.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)
}

function Get-SysMemoryUsage {
    param([Parameter(Position=0)] $ComputerName = $Env:COMPUTERNAME)

    $os = gcim win32_operatingsystem -ComputerName $ComputerName
    Write-Host ("    Total Memory: {0,5:N2} GiB" -f ($os.TotalVisibleMemorySize / 1MB))
    Write-Host ("     Used Memory: {0,5:N2} GiB" -f (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB))
    Write-Host (" Percentage Used: {0,5:N2}%" -f ((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100))
}
