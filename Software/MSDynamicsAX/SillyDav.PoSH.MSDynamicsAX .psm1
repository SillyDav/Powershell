<#
.Synopsis
   Loads AX Powershell Modules required for AX cmdlets to work
.DESCRIPTION
   Loads AX Powershell Modules required for AX cmdlets to work
   Note: This is mostly the script installed by AX located at "C:\Program Files\Microsoft Dynamics AX\60\ManagementUtilities\Microsoft.Dynamics.ManagementUtilities.ps1"
   This is just a wrapper for that scripts contents
.EXAMPLE
   Connect-AX
#>
function Connect-AX {
    #-----------------------------------------------------------------------------------------------------
    #<copyright file="Microsoft.Dynamics.ManagementUtilities.ps1" company="Microsoft">
    #    Copyright (c) Microsoft Corporation.  All rights reserved.
    #</copyright>
    #<summary>
    #    This script imports modules required for AX management in Powershell.
    #</summary>
    #-----------------------------------------------------------------------------------------------------

    #<summary>
    # Import specified module in Powershell
    #</summary>
    #<param name="$axModuleName">Module to be imported</param>
    #<param name="$disableNameChecking">Disables name checking for cmdlet verbs.</param>
    function Import-AXModule($axModuleName, $disableNameChecking, $isFile) {
        try {
            $outputmessage = "Importing " + $axModuleName
            Write-Output $outputmessage

            if ($isFile -eq $true) {
                $dynamicsSetupRegKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Dynamics\6.0\Setup"
                $sourceDir = $dynamicsSetupRegKey.GetValue("InstallDir")
                $axModuleName = "ManagementUtilities\" + $axModuleName + ".dll"
                $axModuleName = Join-Path $sourceDir $axModuleName
            }
            if ($disableNameChecking -eq $true) {
                Import-Module $axModuleName -DisableNameChecking
            }
            else {
                Import-Module $axModuleName
            }
        }
        catch {
            $outputmessage = "Could not load file " + $axModuleName
            Write-Output $outputmessage
        }
    }

    $dynamicsSetupRegKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Dynamics\6.0\Setup"
    $sourceDir = $dynamicsSetupRegKey.GetValue("InstallDir")
    $dynamicsAXModulesPath = Join-Path $sourceDir "ManagementUtilities\Modules"

    $env:PSModulePath = $env:PSModulePath + ";" + $dynamicsAXModulesPath

    Import-AXModule "AxUtilLib" $false $true

    #AxUtil uses "Optimize" verb.
    #Therefore we use -DisableNameChecking to suppress warning about uncommon verb being used.
    Import-AXModule "AxUtilLib.PowerShell" $true $false

    Import-AXModule "Microsoft.Dynamics.Administration" $false $false
    Import-AXModule "Microsoft.Dynamics.AX.Framework.Management" $false $false
}

<#
.Synopsis
    Gets AXDomain and AXCompany
.DESCRIPTION
    Gets AD Domain for AX Domain
    AX company has static value in script alter to what yours is or write a lookup
.EXAMPLE
    Get-AXVariables -AXDomain -AXCompany
#>
function Get-AXVariables {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [switch] $AXDomain,
        [Parameter()]
        [switch] $AXCompany
    )
    Begin {
        #region ModuleImport
        Import-Module ActiveDirectory
        #endregion ModuleImport
    }
    Process {
        #region GetPassedSwitches
        $PSBoundParameters.Keys | ForEach-Object {
            Write-Verbose -Message "Checking $_"
            switch ($_) {
                "AXDomain" {
                    (Get-ADDomainController).Domain
                }
                "AXCompany" {
                    "DAT"
                    #$DomainLookup = ((Get-ADDomainController).Domain)
                    ## Array starts at 0 so add 1
                    #$FindSubDomainPeriod = $DomainLookup.indexof(".") + 1
                    #$DomainLookup.Remove(0, $FindSubDomainPeriod)
                }
                Default {}
            }
        }
        #endregion GetPassedSwitches
    }
    End {
    }
}
<#
.Synopsis
   Creates a new AX User
.DESCRIPTION
   Creates a new User in AX
   Requires Dynamics AX 2012, AX 2012 Management Utilities and the Business Connector to be installed
   Makes user with AXusername of 5 characters long by default
.EXAMPLE
   New-AXUserFunction -SAMAccountName MJack
#>

function New-AXUserFunction {
    [CmdletBinding()]
    Param (
        # Active Directory SAMAccountName (needed for creating new user) eg JSmith
        [Parameter()]
        [string] $SAMAccountName
    )
    Begin {
        #region ConnectAX
        try {
            Connect-AX -erroraction Stop
        }
        catch {
            Write-Output "Microsoft Dynamics AX 2012 Management Utilities is not installed. Please install it. If you do not, the AX part of this script will not work. Press Enter to continue or close script."
        }
        #endregion ConnectAX
        #region GetAXVariables
        $AXVariables = Get-AXVariables -AXDomain -AXCompany
        #endregion GetAXVariables
    }
    Process {
        #region FormatSamAccountName
        $AXUsername = if ($SAMAccountName.Length -gt 5) {
            $SAMAccountName.SubString(0, 5)
        }
        else {
            $SAMAccountName
        }
        # If AXUserID less 5 characters searching for
        if ($AXUserName.Length -lt 5) {
            $LookupAXUser = "{0}" -f $AXUsername
        }
        else {
            $LookupAXUser = "{0}*" -f $AXUsername
        }
        #endregion FormatSamAccountName
        #region ExistingAXUserLookup
        if (!(Get-AXUser -AXUserID $LookupAXUser)) {
            #region CreateAXUser
            $AXUserSplat = @{
                AccountType   = "WindowsUser"
                Company       = $AXVariables[1] #If fails use "DAT"
                AxUserID      = $AXUsername
                UserName      = $SAMAccountName
                UserDomain    = $AXVariables[0]
                ErrorVariable = $NewAXError
            }
            New-AXUser @AXUserSplat
            #endregion CreateAXUser
        }
        else {
            Write-Verbose -Message "User Already Exists, please verify details" -Verbose
        }
        #endregion ExistingAXUserLookup
    }
    end {
    }
}

<#
.Synopsis
   Creates/Copies a new AX User and applies permissions
.DESCRIPTION
   Creates a new User in AX and applies permissions based off another user.
   Can be used to copy permissions to an already created account.
   Requires Dynamics AX 2012, AX 2012 Management Utilities and the Business Connector to be installed
.EXAMPLE
   Copy-AXUser -SAMAccountName MJack -CopyUser BRoss
#>
function Copy-AXUser {
    [CmdletBinding()]
    Param (
        # Active Directory SAMAccountName (needed for creating new user) eg JSmith
        [string] $SAMAccountName,
        # Copy User's AX ID eg KSmith
        [string] $CopyUser
    )
    Begin {
        #region ConnectAX
        try {
            Connect-AX -erroraction Stop
        }
        catch {
            Write-Output "Microsoft Dynamics AX 2012 Management Utilities is not installed. Please install it. If you do not, the AX part of this script will not work. Press Enter to continue or close script."
        }
        #endregion ConnectAX
    }
    Process {
        #region ExistingAXUserLookup
        #region FormatSamAccountName
        $AXUsername = if ($SAMAccountName.Length -gt 5) {
            $SAMAccountName.SubString(0, 5)
        }
        else {
            $SAMAccountName
        }
        # If AXUserID less 5 characters searching for
        if ($AXUserName.Length -lt 5) {
            $LookupAXUser = "{0}" -f $AXUsername
        }
        else {
            $LookupAXUser = "{0}*" -f $AXUsername
        }
        #endregion FormatSamAccountName
        do {
            #region New-AXUserCheck
            try {
                # Find out if user already exists
                if (!(Get-AXUser -AXUserID $LookupAXUser)) {
                    $AXNewUser = Read-Host "Can't find AX User with id $AXUsername. Make new user?"
                    #if user typed anything starting with y will process new-axuserfunction
                    switch ($AXNewUser) {
                        { $_ -match "^y" } { New-AXUserFunction -SAMAccountName $SAMAccountName -ErrorAction Stop }
                        Default { Write-Verbose -Message "Read-Host passed - $AXNewUser" -Verbose }
                    }
                }
            }
            catch {
                $Error[0]
            }
            #endregion New-AXUserCheck

            #region FindExistingUser
            try {
                $AXUser = Get-AXUser -AXUserId $LookupAXUser -ErrorAction stop
            }
            catch {
                $AXUser = Get-AXUser |
                Where-Object { $_.Name -like "*$LookupAXUser*" }
            }
            if (!$AXUser) {
                $LookupAXUser = Read-Host -Prompt "No User $SAMAccountName found please re-enter a AXUserID or DisplayName"
            }
            #endregion FindExistingUser
        } until ($AXUser)

        #endregion ExistingAXUserLookup

        #region CopyUser
        #region FormatCopyUser
        $AXCopyUsername = if ($CopyUser.Length -gt 5) {
            $CopyUser.SubString(0, 5)
        }
        else {
            $CopyUser
        }
        # If AXUserID less 5 characters searching for
        if ($AXCopyUsername.Length -lt 5) {
            $LookupAXCopyUser = "{0}" -f $AXCopyUsername
        }
        else {
            $LookupAXCopyUser = "{0}*" -f $AXCopyUsername
        }
        #endregion FormatCopyUser

        #region LookupCopyUser
        do {
            try {
                $AXCopyUser = Get-AXUser -AXUserId $LookupAXCopyUser -ErrorAction stop
            }
            catch {
                $AXCopyUser = Get-AXUser |
                Where-Object { $_.Name -like "*$LookupAXCopyUser*" }
            }
            if (!$AXCopyUser) {
                $LookupAXCopyUser = Read-Host -Prompt "No CopyUser found please re-enter a AXUserID or DisplayName"
            }
        } until ($AXCopyUser)
        #endregion LookupCopyUser

        #region CopyRoles
        $Roles = Get-AXSecurityRole -AxUserID $AXCopyUser.AXUserId -ErrorVariable $AXError | Select-Object -ExpandProperty AOTName
        ForEach ($Role in $Roles) {
            Add-AXSecurityRoleMember -AxUserID $AXUser.AXUserId -AOTName $Role
            Write-Output "Assigning $Role to $($AXUser.AXUserId)"
        }
        #endregion CopyRoles
        #endregion CopyUser
    }
}