function Enable-VMSServices  {

    
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,
        HelpMessage="Enter one or more computer names seperated by commas.")]
        [String[]]
        $ComputerName,

        [Parameter(ValueFromPipeline=$true)]
        [pscredential]
        $Credential,

        [Parameter(ValueFromPipeline=$true,
        HelpMessage="Enter DisplayNames of services")]
        [String[]]
        $Services
    )

    $file_prefix = "Enable-VMSServices-"
    $file_post = Get-Date -Format "yyyyMMdd-HHmmssffff"
    $file = $file_prefix + $file_post + ".txt"
    Start-Transcript -Path D:\Logs\Scripts\$file
        
    $before = ""
    $after = ""
        
    if(!$ComputerName){
        $services = Get-service | Where-Object {$_.DisplayName -like "*Peoplefluent*"}
        $before += $services | Out-String
        $before
        
        Start-Service -DisplayName ($services).DisplayName
        
        $services = Get-service | Where-Object {$_.DisplayName -like "*Peoplefluent*"}
        $after += $services | Out-String
        $after
    }
    else{
        foreach($server in $ComputerName){
            $services = Invoke-Command -ComputerName $server -Credential $Credential { Get-service | Where-Object {$_.DisplayName -like "*Peoplefluent*"} }
            $before += $services | Out-String
            $before

            Invoke-Command -ComputerName $server -Credential $Credential { Start-Service -DisplayName ($using:services).DisplayName} 

            $services = Invoke-Command -ComputerName $server -Credential $Credential { Get-service | Where-Object {$_.DisplayName -like "*Peoplefluent*"} }
            $after += $services | Out-String
            $after
        }
    }
        
    $from = "VMSService@peoplefluent.com"
    $to = "VMSOps@peoplefluent.com"
    #$to = "ben.grisafi@peoplefluent.com"
    $mailserver = "mail.prod.peopleclick.com"
    $body = "Before:`r`n`t $before `r`nAfter: `r`n`t $after"
    $subject = "Patching VMS Enable Services"
    Send-MailMessage -To $to -From $from -SmtpServer $mailserver -Subject $subject -Body $body
    Stop-Transcript
}