Import-Module $PSScriptRoot\Scripts\editors.ps1
Import-Module $PSScriptRoot\Scripts\git.ps1
Import-Module $PSScriptRoot\Scripts\win32.ps1
Import-Module $PSScriptRoot\Scripts\powerstate.ps1
if ($PSVersionTable.PSVersion.Major -ge 6) { Import-Module "$PSScriptRoot\Scripts\base64.ps1" }

function UploadTo-Catbox { & "$PSScriptRoot\Scripts\UploadTo-Catbox.ps1" @args }

trap
{
	Import-Module 'D:\Code\oss\vcpkg\scripts\posh-vcpkg'
	oh-my-posh init pwsh | Invoke-Expression
}

function Reload-EnvPath
{
	param(
		[switch]$Verbose
	)

	$env:Path = @(
		[System.Environment]::GetEnvironmentVariable("Path","Machine")
		[System.Environment]::GetEnvironmentVariable("Path","User")
	) | Join-String

	if ($Verbose) {
		Write-Host $env:Path
	}
}

function Shell-Edit {
	param(
		[Parameter(ValueFromPipeline=$true, Position=0, Mandatory)]
		$InputObject
	)
	Start-Process -Verb edit $InputObject
}