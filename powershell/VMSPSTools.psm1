Write-Warning "Trying to source all the environment variables from $PSScriptRoot\Env" 
Get-ChildItem -Path "${PSScriptRoot}\ENV\*\*.ps1" | ForEach-Object{.$_}
Get-ChildItem -Path "${PSScriptRoot}\*.ps1" | ForEach-Object{.$_}
Export-ModuleMember -Function @("*-*") -Verbose
Export-ModuleMember -Variable * -Verbose