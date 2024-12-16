Import-Module $PSScriptRoot\Scripts\editors.ps1
Import-Module $PSScriptRoot\Scripts\git.ps1
Import-Module $PSScriptRoot\Scripts\win32.ps1
Import-Module $PSScriptRoot\Scripts\powerstate.ps1
Import-Module $PSScriptRoot\Scripts\base64.ps1

Import-Module 'D:\Code\oss\vcpkg\scripts\posh-vcpkg'

oh-my-posh init pwsh | Invoke-Expression

function Open-FilePropertiesDialog {
	param(
		[Parameter(Mandatory=$true, Position=0)]
		[string]$Path
	)

	$entry = Get-Item -Path $Path

	$o = new-object -com Shell.Application

	if ($entry -is [IO.FileInfo])
	{
		$folder = $o.NameSpace([IO.Path]::GetDirectoryName($entry.FullName))
		$fo = $folder.ParseName($entry.Name)
		$fo.InvokeVerb("Properties")
	}
	else
	{
		$folder = $o.NameSpace($entry.FullName)
		$folder.Self.InvokeVerb("Properties")
	}
}

function Reload-EnvPath {
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