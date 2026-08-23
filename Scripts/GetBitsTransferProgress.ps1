# based on https://gist.github.com/ciphertxt/9612181/

param(
    # [Parameter(Position=0, ValueFromPipeline=$true)]
    # [Microsoft.BackgroundIntelligentTransfer.Management.BitsJob]$Job,
    [double]$RefreshDelaySeconds = 0.1,
    [Switch]$Complete = $true
)

while ((Get-BitsTransfer | ? { $_.JobState -eq "Transferring" }).Count -gt 0)
{
    $totalbytes = 0;
    $bytestransferred = 0;
    $timeTaken = 0;

    foreach ($job in (Get-BitsTransfer | ? { $_.JobState -eq "Transferring" } | Sort-Object CreationTime))
    {
        $totalbytes += $job.BytesTotal;
        $bytestransferred += $job.bytestransferred
        if ($timeTaken -eq 0) {
            #Get the time of the oldest transfer aka the one that started first
            $timeTaken = ((Get-Date) - $job.CreationTime).TotalMinutes
        }
    }

    #TimeRemaining = (TotalFileSize - BytesDownloaded) * TimeElapsed/BytesDownloaded
    if ($totalbytes -gt 0)
    {
        [int]$timeLeft = ($totalBytes - $bytestransferred) * ($timeTaken / $bytestransferred)
        [int]$pctComplete = $(($bytestransferred*100)/$totalbytes);
        Write-Progress -Status "Transferring $bytestransferred of $totalbytes ($pctComplete%). $timeLeft minutes remaining." -Activity "Dowloading files" -PercentComplete $pctComplete
    }

    Start-Sleep -Seconds $RefreshDelaySeconds
}

if ($Complete)
{
    Get-BitsTransfer | Complete-BitsTransfer
}

Write-Host -ForegroundColor Green "BITS Transfer(s) complete!"
