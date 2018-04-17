function Disable-VMSServices  {

    
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,
        HelpMessage="Enter one or more computer names seperated by commas.")]
        [String[]]
        $ComputerName,

        [Parameter(ValueFromPipeline=$true)]
        [pscredential]
        $Credential
    )

    $file_prefix = "Disable-VMSServices-"
    $file_post = Get-Date -Format "yyyyMMdd-HHmmssffff"
    $file = $file_prefix + $file_post + ".txt"
    Start-Transcript -Path D:\Logs\Scripts\$file
        
    $before = ""
    $after = ""
    $getservicecommand = 'Get-service | Where-Object {$_.DisplayName -like "*Peoplefluent*"}'

    if(!$ComputerName){
        $servicestatus = Invoke-Expression $getservicecommand
        $before += $servicestatustatus | Out-String
        $before
        
        Stop-Service -DisplayName ($servicestatus).DisplayName
        
        $servicestatus = Invoke-Expression $getservicecommand
        $after += $servicestatus | Out-String
        $after
    }
    else{
        foreach($server in $ComputerName){
            $servicestatus = Invoke-Command -ComputerName $server -Credential $Credential { $using:getservicecommand }
            $before += $servicestatus | Out-String

            Invoke-Command -ComputerName $server -Credential $Credential { Stop-Service -DisplayName ($using:services).DisplayName} 

            $servicestatus = Invoke-Command -ComputerName $server -Credential $Credential { Get-service | Where-Object {$_.DisplayName -like "*Peoplefluent*"} }
            $after += $servicestatus | Out-String
        }
    }
        
    $from = "VMSService@peoplefluent.com"
    $to = "VMSOps@peoplefluent.com"
    #$to = "ben.grisafi@peoplefluent.com"
    $mailserver = "mail.prod.peopleclick.com"
    $body = "Before:`r`n`t $before `r`nAfter: `r`n`t $after"
    $subject = "Patching VMS Disable Services"
    Send-MailMessage -To $to -From $from -SmtpServer $mailserver -Subject $subject -Body $body
    Stop-Transcript
}