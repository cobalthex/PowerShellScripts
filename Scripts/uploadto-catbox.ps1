[CmdletBinding()]

param(
    [Parameter(Position=0)]
    [System.Drawing.Image]$Image,
    [string]$UserHash,
    [switch]$CopyUrl = $true
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (!$Image)
{
    $Image = [System.Windows.Forms.Clipboard]::GetImage()
}
if (!$Image)
{
    throw "Could not get clipboard image"
}

# Create memory stream for image data
$memStream = [System.IO.MemoryStream]::new()
try
{
    # Save image to memory stream as PNG
    $Image.Save($memStream, [System.Drawing.Imaging.ImageFormat]::Png) # opt png?
    $memStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
    $imageSizeBytes = $memStream.Length

    # Create stream content from memory
    $streamContent = [System.Net.Http.StreamContent]::new($memStream)

    $fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new('form-data')
    $fileHeader.Name = 'fileToUpload'
    $fileHeader.FileName = 'image.png'

    $streamContent.Headers.ContentDisposition = $fileHeader
    $streamContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('image/png')

    $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
    $multipartContent.Add($streamContent)

    # Add required fields
    $reqTypeContent = [System.Net.Http.StringContent]::new('fileupload')
    $multipartContent.Add($reqTypeContent, 'reqtype')

    if ($UserHash)
    {
        $userHashContent = [System.Net.Http.StringContent]::new($UserHash)
        $multipartContent.Add($userHashContent, 'userhash')
    }

    # Upload to catbox
    Write-Verbose "Uploading to catbox.moe..."
    $response = Invoke-WebRequest `
        -Uri 'https://catbox.moe/user/api.php' `
        -Method 'POST' `
        -Body $multipartContent `
        -ErrorAction Stop

    if ($response.StatusCode -eq 200)
    {
        $responseText = $response.Content.Trim()
        if ($responseText -match '^https://')
        {
            if ($CopyUrl)
            {
                Set-Clipboard -Value $responseText
                $imageSizeMiB = "{0:N2}" -f ($imageSizeBytes / 1MB)
                Write-Host -ForegroundColor Cyan "Upload [$imageSizeMiB MiB] successful! URL copied to clipboard!"
            }

            return $responseText
        }
        else
        {
            throw "Upload failed. Server response: $responseText"
        }
    }
    else
    {
        throw "HTTP error: $($response.StatusCode)"
    }
}
finally
{
    $streamContent.Dispose()
    $memStream.Dispose()
    $multipartContent.Dispose()
}
