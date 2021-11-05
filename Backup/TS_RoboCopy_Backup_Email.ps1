<#
.SYNOPSIS
This Script is designed to run via Task Scheduler.
This is a simple Robocopy and email script.
.DESCRIPTION
RoboCopy and Email based on variables supplied
#>
# set variables
$Date = Get-Date -Format dd/MM/yyyy
$EmailDate = "$($date.Day)/$($date.month)/$($date.year)"
$SourceFolder = "W:\Source\Path"
$SourceFolder2 = "X:\Source\Path2"
$DestinationFolder = "Y:\Destination\Path"
$DestinationFolder2 = "Z:\Destination\Path2"
$Logfile = "C:\Temp\Log1Name.txt"
$Logfile2 = "C:\Temp\Log2Name.txt"
$EmailFrom = "Backup@domain.com"
$EmailTo = "YourEmail@domain.com"
$EmailSubject = "Robocopy Summary - $EmailDate"
$SMTPServer = "smtpserver.domain.com"
$SMTPPort = "25"


# Tobocopy commands
Robocopy $SourceFolder $DestinationFolder /MIR /FFT /V /NP /ZB /LOG:$Logfile /R:3 /W:60 /COPYALL
Robocopy $SourceFolder2 $DestinationFolder2 /MIR /FFT /V /NP /ZB /LOG:$Logfile2 /R:3 /W:60 /COPYALL

#send email
$LogFileContents = Select-String -Path $Logfile -Pattern "Times :" -Context 4, 6 | ForEach-Object {
    $_.Context.PreContext
    $_.Line
    $_.Context.PostContext
} | Out-String
$LogFileContents2 = Select-String -Path $Logfile2 -Pattern "Times :" -Context 4, 6 | ForEach-Object {
    $_.Context.PreContext
    $_.Line
    $_.Context.PostContext
} | Out-String
$LogFileContentsFull = "$LogFileContents" + "`n" + "$LogFileContents2"
# generate mail splat
# for info on splatting see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7.1
$MailSplat = @{
    To          = $EmailTo
    From        = $EmailFrom
    Subject     = $EmailSubject
    Body        = "$($logFileContentsFull)"
    SmtpServer  = $SMTPServer
    Port        = $SMTPPort
    Attachments = $Logfile, $Logfile2

}
Send-MailMessage @MailSplat