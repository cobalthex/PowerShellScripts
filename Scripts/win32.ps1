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
