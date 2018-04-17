function Get-RemoteResourceInfo
{
    ##############################
    #.SYNOPSIS
    # Get Remote Server Stats
    #
    #.DESCRIPTION
    # Connects to remove servers that are provided and grabs memory utilization, current cpu average, and specified disk space usage
    #
    #.PARAMETER Credential
    # PsCredentials need to be passed to authenticate to remote servers ex. corp\joe.higgins
    #
    #.PARAMETER ComputerName
    # ComputerName, always good to specify fully qualified domain names ex. rdcvq0web01.rdc.l
    #
    #.PARAMETER Drive
    # Drive letter restricted to C and or D
    #
    #.EXAMPLE
    # Get-RemoteStats -Credentials $cred -ComputernName "rdcvq0web01.rdc.l", "rdcvq0bat01.rdc.l" -Drive "c","d"
    #
    #.NOTES
    #
    ##############################
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true)]
        [pscredential]
        $Credential,
        [Parameter(ValueFromPipeline=$true)]
        [String[]]
        $ComputerName,
        [Parameter(ValueFromPipeline=$true)]
        [ValidateSet("c","d","C","D", "all")]
        [String[]]
        $Drive
    )

    $ErrorActionPreference = "Stop"
    try {
        foreach($pc in $ComputerName){
            $csession = New-CimSession -ComputerName $pc -Credential $Credential
    
            # Memory
            $os = Get-CimInstance -CimSession $csession win32_operatingsystem
            # using MB since the win32_operatingsystem value is in KB so MB gives us the actual GB value
            $totalmem = $os.TotalVisibleMemorySize
            $freemem = $os.FreePhysicalMemory
            $pctfree = "{0:N2}" -f (($freemem/$totalmem)*100)
            
            # CPU
            $cpu = (Get-CimInstance -CimSession $csession Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            
            # Setting Default output
            [string[]]$defaultDisplaySet = @("PSComputerName", "CpuAvg", "MemPctFree") #, "C PctFree")
    
            # Creating return object
            $obj = [PSCustomObject]@{
                'PSComputerName' = $pc
                'CpuAvg' = $cpu
                'MemPctFree' = $pctfree
                'TotalMem(GB)' = ("{0:N}" -f ($totalmem/1MB))
                'FreeMem(GB)' = ("{0:N}" -f ($freemem/1MB))
            }
            
            # Disk Space
            $space = Get-CimInstance -CimSession $csession Win32_Volume
            foreach($c in $Drive){
                #$defaultDisplaySet += "$(${c}.ToUpper())PctFree"
                $d = $c.ToUpper()
                $driveinfo = $space | Where-Object{ $_.DriveLetter -like "${d}:"}
                $free = $driveinfo.FreeSpace
                $capacity = $driveinfo.Capacity                
                $drivepctfree = $capacity-$free
                $obj | Add-Member -MemberType NoteProperty -Name "${d} PctFree" -Value ("{0:N} %" -f ($drivepctfree/1GB))
                $obj | Add-Member -MemberType NoteProperty -Name "${d} Capacity(GB)" -Value ("{0:N}" -f ($capacity/1GB))
                $obj | Add-Member -MemberType NoteProperty -Name "${d} Free(GB)" -Value ("{0:N}" -f ($free/1GB))
                $defaultDisplaySet += "${d} PctFree"
                $defaultDisplaySet += "${d} Capacity(GB)"
                $defaultDisplaySet += "${d} Free(GB)"
            }

            # Default output settings
            $obj.PSObject.TypeNames.Insert(0, 'Server.Information')
            $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet", $defaultDisplaySet)
            $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
            $obj | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers

            # returning object
            $obj
        }
    }
    catch {
        "There was a problem: $(${_}.Exception.Message)"
    }
    
}
Export-ModuleMember -Function Get-RemoteResourceInfo