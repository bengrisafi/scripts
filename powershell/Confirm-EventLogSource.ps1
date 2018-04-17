function Confirm-EventLogSource {
    
##############################
#.SYNOPSIS
# Checks if VMSPSTools EventLogSource Exists
#
#.DESCRIPTION
# Checks if VMSPSTools EventLog Source exists and if it does not it creates it
#
#.EXAMPLE
# Check-EventLogSource
#
#.NOTES
# This simply checks if the source exists and creates it if it does not.
# Needs to be run as an admin to create the source
##############################
    [CmdletBinding()]
    param()
    #Requires -RunAsAdministrator    
    PROCESS {
        try {
            
            if(![System.Diagnostics.EventLog]::SourceExists('VMSPSTools')){
                Write-Verbose "VMSPSTools EventLog Source does not exist. Creating source"
                New-EventLog -LogName 'Application' -Source 'VMSPSTools'
            }
            else {
                Write-Verbose "VMSPSTools is an EventLog Source."
            }
        }
        catch {
            Write-Error "Could not create Source. Please rerun as admin: $_.Exception"
        }
    }
}
Export-ModuleMember -Function 'Confirm-EventLogSource'