param(
    [Parameter(Mandatory, Position = 0)]
    [string]$TestHost,
    [ushort]$TestPort = 443
)

try
{
    $tcpClient = [System.Net.Sockets.TcpClient]::new($TestHost, $TestPort)
    $sslStream = [System.Net.Security.SslStream]::new($tcpClient.GetStream(), $false, ({ $true }))

    $sslStream.AuthenticateAsClient($TestHost)

    $certChain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    $certChain.Build($sslStream.RemoteCertificate) | Out-Null

    Write-Host -ForegroundColor Cyan "Certificate chain for ${TestHost}:${TestPort}"
    $certChain.ChainElements.Certificate | Format-List Subject,Issuer,Thumbprint,NotBefore,NotAfter
}
finally
{
    $sslStream.Dispose()
    $tcpClient.Dispose()
}
