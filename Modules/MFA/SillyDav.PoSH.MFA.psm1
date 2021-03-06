<#
.Synopsis
    Will Output a MFA report to the PS Console
.DESCRIPTION
    Displays by default the User, Status and Configured MFA Type of configured users
.PARAMETER Enabled
    to get users who have been enabled but not configured
.PARAMETER Enforced
    to get all OTP Methods available for configured users
.EXAMPLE
    Get-MFAReport
.EXAMPLE
    Get-MFAReport -Enforced
.EXAMPLE
    Get-MFAReport -Enabled
.EXAMPLE
    Get-MFAReport -Enabled -MS365AdminCred
#>
function Get-MFAReport {
    [cmdletbinding()]
    param(
        [Parameter()]
        [switch]$Enforced,
        [Parameter()]
        [switch]$Enabled,
        [parameter(Mandatory = $false)]
        [PSCredential]$MS365AdminCred
    )
    #region O365CredChecks
    if (!$PSBoundParameters['MS365AdminCred']) {
        $MS365AdminCred = Get-Credential -Message "Enter Office365 Admin Creds"
        try {
            Connect-AzureADFunction -MS365AdminCred $MS365AdminCred -ErrorAction Stop
        }
        catch {
            Connect-AzureADFunction
        }
    }
    else {
        Connect-AzureADFunction -MS365AdminCred $MS365AdminCred
    }
    #endregion O365CredChecks
    if ($PSBoundParameters['Enforced']) {
        $selection = "Full"
    }
    if ($PSBoundParameters['Enabled']) {
        $selection = "Enabled"
    }
    Connect-MsolService
    switch ($selection) {
        "Enabled" {
            Get-MsolUser -All |
            Where-Object { $null -eq $_.StrongAuthenticationMethods.isdefault -and $null -ne $_.StrongAuthenticationRequirements.State } |
            Select-Object userprincipalname, @{
                Name = 'isConfigured'; Expression = { $_.StrongAuthenticationMethods.isDefault }
            }, @{
                Name = 'Type'; Expression = { $_.StrongAuthenticationMethods.MethodType }
            }, @{
                Name = 'State'; Expression = { $_.StrongAuthenticationRequirements.State }
            }
        }
        "Full" {
            Get-MsolUser -All |
            Where-Object { $_.StrongAuthenticationMethods.isDefault -eq $true } |
            Select-Object UserPrincipalName, @{
                Name = 'isConfigured'; Expression = { $_.StrongAuthenticationMethods.isDefault }
            }, @{
                Name = 'Type'; Expression = { $_.StrongAuthenticationMethods.MethodType }
            }, @{
                Name = 'State'; Expression = { $_.StrongAuthenticationRequirements.State }
            }
        }
        Default {
            Get-MsolUser -All |
            Select-Object UserPrincipalName -ExpandProperty StrongAuthenticationMethods |
            Where-Object { $_.isDefault -eq $true } |
            Sort-Object UserPrincipalName |
            Select-Object UserPrincipalName, isDefault, MethodType
        }
    }
}
<#
.Synopsis
    Will send email explaining MFA and that it will be enabled for their user account
.DESCRIPTION
    Will take array of users and send them an email after looking up their details from AD
.PARAMETER Users
    Samaccountname or displayname of users in AD
.EXAMPLE
    Send-MFAInitialEmail -Users Bruce.Banner
.EXAMPLE
    Send-MFAInitialEmail -Users ("Bruce.Banner","Bruce.Wayne")
.EXAMPLE
    $users = ("Bruce.Banner","Bruce.Wayne")
    Send-MFAInitialEmail -Users $users
.EXAMPLE
    $Users = (Get-Aduser -Filter *).Samaccountname
    Send-MFAInitialEmail -Users $users
#>
function Send-MFAInitialEmail {
    [cmdletbinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory)]
        [String[]]$Users,
        [pscredential]$MailboxCred
    )
    #region Mailbox Creds
    if (!$PSBoundParameters['MailboxCred']) {
        $MailboxCred = Get-Credential -Message "Enter Mailbox Creds" -UserName $CurrentUserExtensionAttributes.ExtensionAttribute1
    }
    #endregion Mailbox Creds

    # Loop through users setting it
    foreach ($username in $users) {
        $Body = @"
<html>
<body>
<p>
Hello [firstname],
</p>
<p>
<b>Your Office 365 Account will have multifactor authentication (MFA) enabled tomorrow.</b> <br />
This email is intended to inform you of what is being done and the steps you will need to take after it is enabled. <br />
You will recieve another email once it has been enabled informing you to proceed with the setup by following the instructions.
</p>
<p>
<h4>What is MFA (Multi Factor Authentication) </h4>
Multi-Factor Authentication is a multi-step verification solution, it is intended to protect accounts by needing the <br />
multiple authentication methods usually a code in addition to the password to verify the user’s identity. <br />
This helps prevent the accounts from being hacked if the password is compromised in a breach or is otherwise poorly secured. <br />
It delivers strong authentication via a range of methods including phone call, SMS, mobile app code or push <br />
notification verification. We will be mainly using the mobile app code.
</p>
<p>
<h4>How MFA will work on your account? </h4>
Once MFA is setup on your account, when you sign in to your Office 365 apps such as Outlook, One Drive, Teams, Excel etc. <br />
MFA will require you to verify your account and you will be prompted for an MFA code. <br />
You can select the option &quot;60 day&quot; box so that it does not ask you again for an MFA code for 60 days.
</p>
<p>
<h4>What to do tomorrow after MFA has been enabled </h4>
The first thing you are going to need to do is complete the enrolment process. <br />
Please find below steps on how to enrol and setup MFA on your account.
</p>
<p style="color:red;">
Please follow the instructions <a href="insert link here">here</a> or open the attachment to complete the setup of MFA.<br />
Use the following username for logging onto Microsoft Services : <b>[userprincipalname]</b>
</p>
<p>
After setting up MFA please restart your Office 365 apps such as Outlook, One Drive, Teams, Excel etc.
</p>
<p>
If you have any problems please contact Help Desk by logging a ticket at <a href="insert link here">Help Desk Portal</a>
</p>
<div>
</div>
</body>
</html>
"@
        #region ADUserLookup
        # Will take the supplied UserName and lookup and prompt for re-entry if a user isn't found
        do {
            try {
                $ADUserDetails = Get-ADUser -Identity $UserName -ErrorAction Stop -Properties DisplayName, mail
            }
            catch {
                #If the $UserName fails we can try see if it was entered as "DisplayName"
                Write-Verbose "trying for 'DisplayName' for $UserName"
                $DisplayName = "*{0}*" -f $UserName
                $ADUserDetails = Get-ADUser -Filter { DisplayName -like $DisplayName } -Properties DisplayName, mail
            }
            # if no $ADUser Detais are pulled from the two checks we will prompt a re-enter
            if (!($ADUserDetails)) {
                Write-Verbose "No Users found please re-enter 'UserName' variable" -Verbose
                $UserName = Read-Host "Please re-enter 'UserName' variable"
            }
        } until (($ADUserDetails))
        #endregion ADUserLookup

        $Body = $Body.Replace("[firstname]", ($ADUserDetails).GivenName)
        $Body = $Body.Replace("[userprincipalname]", ($ADUserDetails).UserPrincipalName)
        $MFAMailSplat = @{
            Mailto      = ($ADUserDetails).UserPrincipalName
            MailFrom    = ($CurrentUserExtensionAttributes).ExtensionAttribute1
            MailSubject = "Multi-factor Authentication (MFA) will be enabled for your account"
            MailBody    = $Body
            SendAsHtml  = $True
            Credential  = $MailboxCred
            #Attachment  = "attachment.pdf" #remove comment if you want to send an attachment
        }
        if ($pscmdlet.ShouldProcess($MFAMailSplat.MailTo)) {
            # Send the email
            Send-Email @MFAMailSplat
        }
    }
}

<#
.Synopsis
enable MFA for a set of users
.Description
This script will connect to MSOnline, and enable MFA for each user in the supplied array then send an email to the user with a link to instructions on configuring MFA
.Parameter Users
A Username or Array of usernames that will be enabled
Samaccountname or Displayname of users in AD
.Parameter MS365AdminCred
A PSCredential object containing credentials for Microsoft 365 Admin
.Parameter MailboxCred
A PSCredential object containing credentials for Sending Emails
.Example
Enable-MFA -Users Bruce.Banner
Enforce MFA for Bruce Banner
.Example
$MS365AdminCred = get-credential
$MailboxCred = get-credential
Enable-MFA -Users Bruce.Wayne -MS365AdminCred $MS365AdminCred -MailboxCred $MailboxCred
Enforce MFA For Bruce Wayne, authenticating to Msol as the $MS365AdminCred Cred and sending an email using the $MailboxCred
.Example
Enable-MFA -Users @("Clark.Kent","Wally.West","Hal.Jordan") -MS365AdminCred $MS365AdminCred -MailboxCred $MailboxCred
Enable MFA for Clark Kent, Wally West and Hal Jordan and send them emails
.Example
$MS365AdminCred = get-credential
$MailboxCred = get-credential
(get-aduser -searchbase "OU=Users,OU=Company,DC=Company,DC=com" -filter *).samaccountname |
%{ Enable-MFA -Users $_  -MS365AdminCred $MS365AdminCred -MailboxCred $MailboxCred }
Runs Enable-MFA for each Samaccountname returned in get-aduser filter which is all users in Users OU of company.com domain
.Example
$MS365AdminCred = get-credential
$MailboxCred = get-credential
$x = (get-aduser -searchbase "OU=Users,OU=Company,DC=Company,DC=com" -filter *).samaccountname
Enable-MFA -Users $x  -MS365AdminCred $MS365AdminCred -MailboxCred $MailboxCred
Enable MFA for all users in $x which will return user Samaccountnames for users in Users OU
#>
function Enable-MFA {
    [cmdletbinding()]
    param (
        [parameter(Mandatory)]
        [String[]]$Users,
        [Parameter()]
        [pscredential]$MS365AdminCred,
        [Parameter()]
        [pscredential]$MailboxCred
    )
    #region ModuleImports
    If (!(Get-Module MSOnline)) {
        Import-Module MSOnline
    }
    #endregion ModuleImports

    #region O365CredChecks
    try {
        $null = Get-MsolAccountSku -ErrorAction Stop
    }
    catch {
        if (!$PSBoundParameters['MS365AdminCred']) {
            $MS365AdminCred = Get-Credential -Message "Enter Office365 Admin Creds" -UserName $CurrentUserExtensionAttributes.ExtensionAttribute3
            try {
                Connect-MsolServiceFunction -MS365AdminCred $MS365AdminCred -ErrorAction Stop
            }
            catch {
                Connect-MsolServiceFunction
            }
        }
        else {
            Connect-MsolServiceFunction -MS365AdminCred $MS365AdminCred
        }
    }
    #endregion O365CredChecks

    #region MailboxCredChecks
    if (!$PSBoundParameters['MailboxCred']) {
        $MailboxCred = Get-Credential -Message "Enter Mailbox Creds" -UserName $CurrentUserExtensionAttributes.ExtensionAttribute1
    }
    #endregion MailboxCredChecks

    #region ScriptStateChecks
    If ($null -eq $State) {
        $State = "Enabled"
    }
    #endregion ScriptStateChecks

    #region MFAStrongAuthObject
    # Create a Strong Auth Requirement object and configure it
    $StrongAuthOption = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
    $StrongAuthOption.RelyingParty = "*"
    $StrongAuthOption.State = $State
    $StrongAuth = @($StrongAuthOption)
    #endregion MFAStrongAuthObject

    #region ProcessforeachUser
    # Loop through users setting it
    foreach ($username in $users) {
        #region ADUserLookup
        # Will take the supplied UserName and lookup and prompt for re-entry if a user isn't found
        do {
            try {
                $ADUserDetails = Get-ADUser -Identity $UserName -ErrorAction Stop -Properties DisplayName, mail
            }
            catch {
                #If the $UserName fails we can try see if it was entered as "DisplayName"
                Write-Verbose "trying for 'DisplayName' for $UserName"
                $DisplayName = "*{0}*" -f $UserName
                $ADUserDetails = Get-ADUser -Filter { DisplayName -like $DisplayName } -Properties DisplayName, mail
            }
            # if no $ADUser Detais are pulled from the two checks we will prompt a re-enter
            if (!($ADUserDetails)) {
                Write-Verbose "No Users found please re-enter 'UserName' variable" -Verbose
                $UserName = Read-Host "Please re-enter 'UserName' variable"
            }
        } until (($ADUserDetails))
        #endregion ADUserLookup

        #region LogicSwitches
        $send_mail = $false
        $disable_mfa = $false
        #endregion LogicSwitches

        #region MsolUserMFA
        #region MsolUserExists
        # Check if UserPrincipalName is correct
        try {
            "Checking User {0}" -f ($ADUserDetails).UserPrincipalName
            $MsolUser = Get-MsolUser -UserPrincipalName ($ADUserDetails).UserPrincipalName
        }
        catch {
            throw "Unable to find user ($ADUserDetails).UserPrincipalName"
            $send_mail = $false
            continue
        }
        #endregion MsolUserExists

        #region MsolUserStrongAuthenticationRequirementsExists
        # Check if
        if ($MsolUser.StrongAuthenticationRequirements) {
            "User {0} is already MFA enabled. Authentication requirements are below" -f ($ADUserDetails).UserPrincipalName
            $MsolUser.StrongAuthenticationRequirements
            $prompt = Read-Host "Would you like to reset this? [y/n]"
            if ($prompt -ne "y") {
                continue
            }
            $disable_mfa = $true
        }
        if ($disable_mfa -eq $true) {
            "Disabling MFA for {0}" -f ($ADUserDetails).UserPrincipalName
            Reset-MsolStrongAuthenticationMethodByUpn -UserPrincipalName ($ADUserDetails).UserPrincipalName
        }
        #endregion MsolUserStrongAuthenticationRequirementsExists

        #region MsolUserSetMFA
        if ($disable_mfa -eq $false) {
            "Setting MFA to {0} for {1}" -f $state, ($ADUserDetails).UserPrincipalName
            try {
                Set-MsolUser -UserPrincipalName ($ADUserDetails).UserPrincipalName -StrongAuthenticationRequirements $StrongAuth
                $send_mail = $true
            }
            catch {
                $send_mail = $false
                Write-Error "Unable to enable MFA for $(($ADUserDetails).UserPrincipalName)"
            }
        }

        #endregion MsolUserSetMFA
        #endregion MsolUserMFA

        #region Mail
        #region MailBodyCompile
        $Body = @"
<html>
<body>
<p>
Hello [firstname],
</p>
<p>
<b>Your account [mail] has had Multi Factor Authentication Enabled</b> <br />
You will need to follow the steps provided to setup MFA for your account.
</p>
<p>
<h3>What you need to do </h3>
The first thing you are going to need to do is complete the enrolment process. <br />
Please find below steps on how to enrol and setup MFA on your account.
</p>
<p style="color:red;">
Please follow the instructions <a href="">here</a> or open the attachment to complete the setup of MFA. <br />
<b>Use the following username for logging onto Microsoft Services : [userprincipalname]</b>
</p>
<p>
After setting up MFA please restart your Office 365 apps such as Outlook, One Drive, Teams, Excel etc.
</p>
<p>
If you have any problems please contact Help Desk by logging a ticket at <a href="">Help Desk Portal</a>
</p>
<br />
<br />
<br />
<p>
<h4>What is MFA (Multi Factor Authentication) </h4>
Multi-Factor Authentication is a multi-step verification solution, it is intended to protect accounts by needing the <br />
multiple authentication methods usually a code in addition to the password to verify the user’s identity. <br />
This helps prevent the accounts from being hacked if the password is compromised in a breach or is otherwise poorly secured. <br />
It delivers strong authentication via a range of methods including phone call, SMS, mobile app code or push <br />
notification verification. We will be mainly using the mobile app code.
</p>
<p>
<h4>How MFA will work on your account? </h4>
Once MFA is setup on your account, when you sign in to your Office 365 apps such as Outlook, One Drive, Teams, Excel etc. <br />
MFA will require you to verify your account and you will be prompted for an MFA code. <br />
You can select the option &quot;60 day&quot; box so that it does not ask you again for an MFA code for 60 days.
</p>
<div>
</div>
</body>
</html>
"@
        #endregion MailBodyCompile

        #region MailBodyReplace
        # uses values from "#region ADUserLookup"
        $Body = $Body.Replace("[firstname]", ($ADUserDetails).GivenName)
        $Body = $Body.Replace("[mail]", ($ADUserDetails).Mail)
        $Body = $Body.Replace("[userprincipalname]", ($ADUserDetails).UserPrincipalName)
        #endregion MailBodyReplace

        #region MailSplatBuild
        $MFAMailSplat = @{
            Mailto      = ($ADUserDetails).UserPrincipalName
            MailFrom    = ($CurrentUserExtensionAttributes).ExtensionAttribute1
            MailSubject = "Please complete Multi-factor Authentication (MFA) setup"
            MailBody    = $Body
            SendAsHtml  = $True
            Credential  = $MailboxCred
            #Attachment  = "attachment.pdf" #remove comment if you want to send an attachment
        }
        #endregion MailSplatBuild

        #region SendMail
        if ($send_mail) {
            # Send the email
            Send-Email @MFAMailSplat
        }
        #endregion SendMail
        #endregion Mail
    }
    #endregion ProcessforeachUser
}
