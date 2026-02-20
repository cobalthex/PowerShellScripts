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
            }
            'Error' {
                $job | Format-List *
                Remove-BitsTransfer $job
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
            Write-Host -Foreground Yellow "Canceled file copy"
        }
    }
}
Set-Alias -Name bcp -Value Wait-BITSCopy
