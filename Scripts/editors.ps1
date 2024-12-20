function sublime { & "C:\Program Files\Sublime Text\sublime_text.exe" $args }

function Out-Notepad
{
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject
    )

    begin
    {
        $sb = [Text.StringBuilder]::new(128KB)

        $process = Start-Process notepad -PassThru
        $process.WaitForInputIdle() | Out-Null

        $sig = '
            [DllImport("user32.dll", EntryPoint = "FindWindowEx")]public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
            [DllImport("User32.dll")]public static extern int SendMessage(IntPtr hWnd, int uMsg, int wParam, string lParam);
        '

        $type = Add-Type -MemberDefinition $sig -Name APISendMessage -PassThru
        [IntPtr]$hwnd = $type::FindWindowEx($process.MainWindowHandle, [IntPtr]::Zero, "Edit", $null)
    }

    process
    {
        [void]$sb.Append($InputObject.ToString().TrimEnd())
        [void]$sb.Append([Environment]::NewLine)
        if ($sb.Length -gt ($sb.Capacity - 1KB))
        {
            [void]$type::SendMessage($hwnd, 0x00C2, 0, $sb.ToString())
            [void]$sb.Clear()
        }
    }
    end
    {
        [void]$type::SendMessage($hwnd, 0x00C2, 0, $sb.ToString())
        # cleanup?
    }
}

function Out-Editor
{
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        [Parameter()]
        [ValidateScript({Test-Path $_})]
        [string]$Executable = "C:\Program Files\Sublime Text\sublime_text.exe"
    )
    begin
    {
        $file = New-TemporaryFile
    }

    process
    {
        $InputObject >> $file
    }

    end
    {
        $process = Start-Process -FilePath $Executable -PassThru $file.FullName
        $process.WaitForInputIdle() | Out-Null
        Remove-Item $file.FullName -Force
    }
}

function Out-Temp
{
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject
    )

    begin
    {
        $file = New-TemporaryFile
    }

    process
    {
        $InputObject >> $file
    }

    end
    {
        $file
    }
}