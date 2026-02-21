function Format-FileSize {
    param([ulong]$Bytes)

    switch ($Bytes) {
        { $_ -ge 1PB } { "{0:N2} PiB" -f ($Bytes / 1PB); break }
        { $_ -ge 1TB } { "{0:N2} TiB" -f ($Bytes / 1TB); break }
        { $_ -ge 1GB } { "{0:N2} GiB" -f ($Bytes / 1GB); break }
        { $_ -ge 1MB } { "{0:N2} MiB" -f ($Bytes / 1MB); break }
        { $_ -ge 1KB } { "{0:N2} KiB" -f ($Bytes / 1KB); break }
        default        { "$Bytes B" }
    }
}

function Wait-BITSCopy {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$Source,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Destination
    )

    $job = Start-BitsTransfer `
        -Source $Source `
        -Destination $Destination `
        -Asynchronous `
        -DisplayName "BITS File Copy"

    try
    {
        while ($job.JobState -in @('Connecting', 'Transferring'))
        {
            $percent = if ($job.BytesTotal -gt 0) { [int](100 * $job.BytesTransferred / $job.BytesTotal) } else { 0 }
            $timeTaken = ((Get-Date) - $job.CreationTime).TotalMinutes
            $timeLeft = if ($job.BytesTransferred -gt 0) { [int](($job.BytesTotal - $job.BytesTransferred) * ($timeTaken / $job.BytesTransferred)) } else { '∞' }

            Write-Progress `
                -Activity "Copying files" `
                -Status ('  {0} / {1} ({2}%) {3} minutes remaining' -f @((Format-FileSize $job.BytesTransferred), (Format-FileSize $job.BytesTotal), $percent, $timeLeft) ) `
                -PercentComplete $percent

            Start-Sleep -Milliseconds 300
        }

        switch ($job.JobState)
        {
            'Transferred' {
                $size = $job.BytesTotal
                Complete-BitsTransfer $job
                Write-Progress -Activity "Copying files" -Completed
                Write-Host -ForegroundColor Green "File copy complete! ($(Format-FileSize $size))"
                Remove-Variable $job
            }
            'Error' {
                $job | Format-List *
                Remove-BitsTransfer $job
                Remove-Variable $job
                exit 1
            }
        }
    }
    # can catch CTRL+C
    finally
    {
        if ($job -and $job.JobState -notin @('Transferred', 'Acknowledged'))
        {
            Remove-BitsTransfer $job -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor Yellow "Canceled file copy"
        }
    }
}
Set-Alias -Name bcp -Value Wait-BITSCopy
