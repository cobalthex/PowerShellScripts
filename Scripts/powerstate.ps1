Add-Type -AssemblyName 'System.Windows.Forms'

function Set-PowerState {
    param (
        [System.Windows.Forms.PowerState]$PowerState = [System.Windows.Forms.PowerState]::Suspend,
        [switch]$DisableWake,
        [switch]$Force
    )

    if (!$DisableWake) { $DisableWake = $false; };
    if (!$Force) { $Force = $false; };

    [System.Windows.Forms.Application]::SetSuspendState($PowerState, $Force, $DisableWake);
}

function Show-ShutdownDialog {
    $shell = New-Object -ComObject "Shell.Application"
    $shell.ShutdownWindows()
}
