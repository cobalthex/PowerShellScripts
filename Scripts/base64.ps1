class AvailableEncodings : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        return [System.Text.Encoding]::GetEncodings().Name
    }
}
function ConvertFrom-Base64 {
    param(
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline=$true)]
        [string]$InputObject,
        [ValidateSet([AvailableEncodings])]
        [string]$Encoding = "Unicode"
    )
    $bytes = [System.Convert]::FromBase64String($InputObject)
    return [System.Text.Encoding]::GetEncoding($Encoding).GetString($bytes)
}
function ConvertTo-Base64 {
    param(
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline=$true)]
        [string]$InputObject,
        [ValidateSet([AvailableEncodings])]
        [string]$Encoding = "Unicode"
    )
    $bytes = [System.Text.Encoding]::GetEncoding($Encoding).GetBytes($InputObject)
    return [System.Convert]::ToBase64String($bytes)
}