<#
.SYNOPSIS
Removes and application pool and website from a remote server.
.DESCRIPTION
The function will remove the application pool and the website specified on the servers provided.
.EXAMPLE
Remove-VMSAppPool -servers "VMSVC" -appPoolName "Test Pool" -siteName "Test Site" -environmentFile "VMSControl.ps1"
Removes any application pool named 'Test Pool' and site named 'Test Site' from the remote servers 
defined by the environment variable 'VMSVC'
.EXAMPLE 
Remove-VMSAppPool "WebServer1" 
Removes any application pool named 'VMSApi' and site named 'VMSApi' from the remote server 'WebServer1'
.PARAMETER ComputerName
A list of servers where the application pool resides.
.PARAMETER appPoolName
The name of the application pool to be removed.
.PARAMETER siteName
The name of the website to be removed. 
.PARAMETER Credential 
The credentials needed to execute the remote script.
.NOTES
This command needs to be run as an administrator if the VMSPSTools Event Log does not exist on the target machines.
#>
Function Remove-VMSAppPool {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string[]]$ComputerName,
        [Parameter(Mandatory=$true)][pscredential]$Credential,
        [string]$appPoolName = 'VMSApi',
        [string]$siteName = 'VMSApi'
    )

    if (Test-Path variable:$ComputerName) {
        # If the variable name is passed, instead of the values
        $remoteservers = Get-Variable -name $ComputerName -ValueOnly
    }
    else {
        $remoteservers = $ComputerName
    }

    $logDef = "function Log { $function:Log }"
    
    $scriptBlock = {
        Param( $logDef,
        [string]$appPoolName,
        [string]$siteName
        )
        . ([scriptblock]::Create($using:logDef))
        
        Import-Module WebAdministration

        # This is available as Confirm-EventLogSource, but was unable to get it to execute remotely.
        if (![bool](Get-EventLog -LogName Application -Source 'VMSPSTools' -ErrorAction SilentlyContinue)){
            New-EventLog -LogName 'Application' -Source 'VMSPSTools'
        }

        Log "Removing application pool `'$appPoolName`' with website application name `'$siteName`' on $env:COMPUTERNAME" 
        
        $pools = Get-ChildItem -Path IIS:\AppPools
        if ($pools.name -contains $appPoolName) {
            foreach($pool in $pools | Where-Object {$_.name -eq $appPoolName})
            {
                Log "Found API AppPool on $env:COMPUTERNAME."
                $applicationNames = @(Get-WebConfigurationProperty "/system.applicationHost/sites/site/application[@applicationPool=`'$($pool.name)`' and @path='/']/parent::*" machine/webroot/apphost -Name name).Value

                # Should only return a single application, but where-statement is used to ensure that we only remove site and files specified.
                foreach($appName in $applicationNames | Where-Object {$_ -eq $siteName }) 
                {
                    $site = Get-Website -Name $appName
                    Log "Found API Website on $env:COMPUTERNAME."
                    Remove-Website -Name $site.name
                    Log "Removed API Website on $env:COMPUTERNAME."
                    Log "Removing files on $env:COMPUTERNAME at location: $($site.physicalPath)"
                    Remove-Item -Path $site.physicalPath -Recurse
                    Log "Files removed on $env:COMPUTERNAME."
                }
                Remove-WebAppPool -Name $pool.name
                Log "Removed API AppPool."
            }    
        }
        else {
            Write-Error "Application pool `'$appPoolName`' not found on $env:COMPUTERNAME."
            # TODO: Figure out how to pass verbose output back to the user when executing remote scripts
            # Write-Verbose ''
            # foreach($pool in $pools)
            # {
            #     $applicationNames = @(Get-WebConfigurationProperty "/system.applicationHost/sites/site/application[@applicationPool=`'$($pool.name)`' and @path='/']/parent::*" machine/webroot/apphost -Name name).Value

            #     # As a help to the user, this lists the available application pools and the website(s) using it.
            #     # This should not really be logged in the event log, IMO.
            #     Write-Verbose -NoNewline "Applications for pool `'$($pool.name)`': "
            #     foreach($appName in $applicationNames) 
            #     {
            #         Write-Verbose -NoNewline "$appName "
            #     }
            #     Write-Verbose ''
            # }
        }
    }

    Invoke-Command -ComputerName $remoteservers -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $logDef,$appPoolName,$siteName -Verbose:$VerbosePreference
}

function Log ([string]$message) {
    # TODO: Figure out how to pass verbose output back to the user when executing remote scripts
    # Write-Verbose $message
    Write-EventLog -LogName 'Application' -EventId 1001 -Source 'VMSPSTools' -EntryType Information -Message $message
}
