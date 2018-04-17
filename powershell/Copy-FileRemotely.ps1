function Copy-FileRemotely 
{
    ##############################
    #.SYNOPSIS
    # Copy files to remote hosts
    #
    #.DESCRIPTION
    # Wrapper script to Copy-Item, this function takes in a path and destination path and copies the file in the path to the destination path on the remote hosts provided.
    #
    #.PARAMETER ComputerName
    # List of Computers you want to copy files to
    #
    #.PARAMETER Destination
    # Destination Path on the server you want the file copied to, non unc path. ex D:\Test
    #
    #.PARAMETER SourceFile
    # Source file name or path of the file you would like to copy
    #
    #.EXAMPLE
    # Copy-FileRemotely -Computername RDCVC1WEB01 -File C:\Test\Test.txt -Destination D:\Test\filename.txt
    #
    #.NOTES
    # This creates a PSDrive to mount the destination directory locally to copy the item.
    # The psdrive is nonpersistent and should clean up after errors. 
    ##############################    
    [Cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true,
        HelpMessage="Enter one or more computer names seperated by commas.")]
        [String[]]
        $ComputerName,

        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [String]
        $Destination,

        [Parameter(ValueFromPipeline=$true, Mandatory=$true,
        HelpMessage="Enter file you would like to copy to destination")]
        [ValidateScript({Test-path $_ })]
        [String]
        $SourceFile,

        [Parameter(ValueFromPipeline=$true)]
        [pscredential]
        $Credential
    )

    # Check for eventlog source
    try{
        $ErrorActionPreference="SilentlyContinue"
        Confirm-EventLogSource
    }
    catch {
        Write-Verbose "Running from a non-Admin console"
        $eventlog=$false
    }
    $ErrorActionPreference="Stop"

    $drive = (Split-Path $Destination -Qualifier).Trim(":").ToLower()
    
    $path = Split-Path $Destination -NoQualifier

    foreach($server in $ComputerName){
        if(Test-Connection $server -Quiet){
            try {
                
                $root = "\\$server\$drive$"
                Write-Verbose "Creating PSDrive at $root"
                New-PSDrive -Name Q -PSProvider FileSystem -Root $root -Credential $Credential > $null
                Write-Verbose "Q drive created"
                
                $test = Test-Path Q:\$path
                Write-Verbose "Q Drive Path Test: $test"
                
                if(Test-Path Q:\$path){
                    
                    Write-Verbose "Copying $SourceFile to Q:\$path"
                    Copy-Item -Path $SourceFile -Destination Q:\$path
                    
                    Write-Verbose "Checking Path"
                    $filename = (Get-Item -Path $SourceFile).Name

                    # Output information
                    Get-ChildItem Q:\$path\$filename
                    $message = "`r`n$SourceFile copied to $Destination Sucessfully"
                    Write-Output $message
                    if ($eventlog) {
                        Write-EventLog -LogName "Application" -Source "VMSPSTools" -EntryType Information -Message $message
                    }
                }
                else {
                    Write-Error "$path doesn't exist, cannnot copy file to this destination"
                }
            }
            catch {
                "An error occured trying to copy the files: $_"
                if ($eventlog) {
                    Write-EventLog -LogName "Application" -Source "VMSPSTools" -EntryType Error -Message "Error in Copy-FileRemotely : $_.Exception.Message" -RawData $_.Exception   
                }
                break
            }
            finally {
                if(Get-PSDrive -Name Q){
                    Write-Verbose "Removing Q drive"
                    Remove-PSDrive -Name Q -Force
                }
            }
        }
        else {
            if($eventlog){
                Write-EventLog -LogName "Application" -Source "VMSPSTools" -EntryType Error -Message "Error in Copy-FileRemotely : Connection was unsuccessul to $server"
            }
            Write-Error "Unable to connect to $server"
        }
    }
}
Export-ModuleMember -Function 'Copy-FileRemotely'