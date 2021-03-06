# MS 365 Admin connections will try find an existing session and if it can't it will attempt to login
function Connect-AzureADFunction {
    param (
        [pscredential]$MS365AdminCred
    )
    #region AzureADConnect
    If (!(Get-Module AzureAD)) {
        Import-Module AzureAD
    }
    #Connect to AzureAD
    try {
        # tries to find if active session
        $null = Get-AzureADTenantDetail -ErrorAction Stop
    }
    catch {
        # if no credential parameter is passed will bring up the MS login page
        if (!$PSBoundParameters['MS365AdminCred']) {
            Connect-AzureAD
        }
        else {
            try {
                # Will try connect with supplied credentials
                Connect-AzureAD -Credential $MS365AdminCred -ErrorAction Stop
            }
            catch {
                # if creds fail or if MFA is required
                Connect-AzureAD
            }
        }
    }
    #endregion AzureADConnect
}
function Connect-MSOLServiceFunction {
    param (
        [pscredential]$MS365AdminCred
    )
    #region MsolServiceConnect
    If (!(Get-Module MSOnline)) {
        Import-Module MSOnline
    }
    #Connect to MsolService
    try {
        $null = Get-MsolAccountSku -ErrorAction Stop
    }
    catch {
        # if no credential parameter is passed will bring up the MS login page
        if (!$PSBoundParameters['MS365AdminCred']) {
            Connect-MsolService
        }
        else {
            try {
                # Will try connect with supplied credentials
                Connect-MsolService -Credential $MS365AdminCred -ErrorAction Stop
            }
            catch {
                # if creds fail or if MFA is required
                Connect-MsolService
            }
        }
    }
    #endregion MsolServiceConnect
}
function Connect-Office365SecurityandCompliance {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [pscredential]$MS365AdminCred
    )
    If (!(Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement
    }
    #region Connect-ExchangeOnline
    try {
        try {
            # Will see if there is an available session for 365 Security and Compliance to connect to
            $null = Get-ActivityAlert -ErrorAction Stop
        }
        catch {
            # If there is no session available it will see if there is a Exchange Online session available
            $null = get-mailbox -ResultSize 1 -ErrorAction Stop
        }
    }
    # This catch will run if there is no sessions for either of the commands
    catch {
        # If no MS365AdminCred passes will run connect-ExchangeOnline
        if (!$PSBoundParameters['MS365AdminCred']) {
            Connect-ExchangeOnline
        }
        # Runs this section is there is a MS365AdminCred value
        else {
            try {
                # Tries connect-ExchangeOnline with passed MS365AdminCred
                Connect-ExchangeOnline -Credential $MS365AdminCred -ErrorAction Stop
            }
            catch {
                # If MS365AdminCred passed fails to connect will run manual connect-ExchangeOnline
                Connect-ExchangeOnline
            }
        }
    }
    #endregion Connect-ExchangeOnline
    #region Connect-Office365Compliance
    if ($global:CurrentUserExtensionAttributes.ExtensionAttribute3) {
        $IPPSessionUser = $global:CurrentUserExtensionAttributes.ExtensionAttribute3
    }
    else {
        (Write-Verbose -Message "No Value in property ExtensionAttribute3 found for current AD User $global:UserSecurityIdentity" -Verbose)
    }
    if ($IPPSessionUser) {
        try {
            Connect-IPPSSession -UserPrincipalName $IPPSessionUser -ConnectionUri "https://ps.compliance.protection.outlook.com/powershell-liveid/" -ErrorAction Stop
        }
        catch {
            Connect-IPPSSession -ConnectionUri "https://ps.compliance.protection.outlook.com/powershell-liveid/"
        }
    }
    else {
        Connect-IPPSSession -ConnectionUri "https://ps.compliance.protection.outlook.com/powershell-liveid/"
    }
    #endregion Connect-Office365Compliance
}

function Connect-ExchangeOnlineFunction {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [pscredential]$MS365AdminCred
    )
    If (!(Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement
    }
    #region Connect-ExchangeOnline
    try {
        # If there is no session available it will see if there is a Exchange Online session available
        $null = get-mailbox -ResultSize 1 -ErrorAction stop
    }
    # This catch will run if there is no sessions for either of the commands
    catch {
        # If no MS365AdminCred passes will run connect-ExchangeOnline
        if (!$PSBoundParameters['MS365AdminCred']) {
            Connect-ExchangeOnline
        }
        # Runs this section is there is a MS365AdminCred value
        else {
            try {
                # Tries connect-ExchangeOnline with passed MS365AdminCred
                Connect-ExchangeOnline -Credential $MS365AdminCred -ErrorAction Stop
            }
            catch {
                # If MS365AdminCred passed fails to connect will run manual connect-ExchangeOnline
                Connect-ExchangeOnline
            }
        }
    }
    #endregion Connect-ExchangeOnline
}
