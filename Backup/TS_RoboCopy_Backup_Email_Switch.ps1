# Robocopy with email notification
# This variable at get-date -12 hours should determine the correct day eg. if it runs on Monday Night or Tuesday Morning it should return Monday
$Date = (Get-Date).AddHours(-12)
# With get the Day of the week the script is running and then be used in the switch statement below to determine the action to take
$ScriptDate = ($Date).DayOfWeek
# Formatting for Email Date to add to Email Subject
$EmailDate = "$($Date.Day)/$($Date.month)/$($Date.year)"
# This switch takes the scriptdate and will execute either the nightly or weekly robocopy depending on the days given in the switch values
switch ($ScriptDate) {
    { $_ -in "Monday", "Tuesday", "Wednesday", "Thursday" } {
        # Nightly Variables
        $NightlySourceFolder = "Y:\Source1\Nightly"
        $NightlySourceFolder2 = "Y:\Source2\Nightly"
        $NightlyDestinationFolder = "Z:\Destination1\Nightly"
        $NightlyDestinationFolder2 = "Z:\Destination2\Nightly"
        $NightlyLogfile = "C:\temp\NightlyBackupLog.txt"
        # Clear Nightly Folder // Will not delete Weekly as it is a different folder name
        Remove-Item -Path $NightlyDestinationFolder -Recurse -Force
        Remove-Item -Path $NightlyDestinationFolder2 -Recurse -Force
        # Copy Nightly Folder contents // Excludes full backup .vbk file
        Robocopy $NightlySourceFolder $NightlyDestinationFolder /MIR /E /V /NP /LOG:$NightlyLogfile /XF *.vbk /Z /R:3 /W:60
        Robocopy $NightlySourceFolder2 $NightlyDestinationFolder2 /MIR /E /NP /R:3 /W:60
        # Parses Log for Times : and then outputs them as strings and saves to variable
        $LogFileContents = Select-String -Path $NightlyLogfile -Pattern "Times :" -Context 4, 6 | ForEach-Object {
            $_.Context.PreContext
            $_.Line
            $_.Context.PostContext
        } | Out-String
        # Email Splat // Match these values to parameters of Send-MailMessage cmdlet
        $NightlyEmailSplat = @{
            From        = "Backup@domain.com"
            To          = "email1@domain.com"
            Subject     = "Nightly Robocopy Summary - $ScriptDate - $EmailDate"
            SMTPServer  = "smtpserver.domain.com"
            Body        = "$($logFileContents)"
            Attachments = "$NightlyLogfile"
        }
        # Sends email based on values in $NightlyEmailSplat
        Send-MailMessage @NightlyEmailSplat

    }
    { $_ -in "Friday", "Saturday", "Sunday" } {
        # Weekly Variables
        $WeeklySourceFolder = "Y:\Source1\Weekly"
        $WeeklyDestinationFolder = "Z:\Destination1\Weekly"
        $WeeklyLogfile = "C:\temp\WeeklyBackupLog.txt"
        #Clear Weekly Folder // Will not delete Nightly as it is a different folder name
        Remove-Item -Path $WeeklyDestinationFolder -Recurse -Force
        # copy
        Robocopy $WeeklySourceFolder $WeeklyDestinationFolder /MIR /E /V /NP /LOG:$WeeklyLogfile /Z /R:3 /W:60
        # Parses Log for Times : and then outputs them as strings and saves to variable
        $LogFileContents = Select-String -Path $WeeklyLogfile -Pattern "Times :" -Context 4, 6 | ForEach-Object {
            $_.Context.PreContext
            $_.Line
            $_.Context.PostContext
        } | Out-String
        # Email Splat // Match these values to parameters of Send-MailMessage cmdlet
        $WeeklyEmailSplat = @{
            From        = "Backup@domain.com"
            To          = "email1@domain.com"
            Subject     = "Weekly Robocopy Summary - $ScriptDate - $EmailDate"
            SMTPServer  = "smtpserver.domain.com"
            Body        = "$($logFileContents)"
            Attachments = "$WeeklyLogfile"
        }
        # Sends email based on values in $WeeklyEmailSplat
        Send-MailMessage @WeeklyEmailSplat

    }
    Default { }
}
