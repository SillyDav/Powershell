#region JIRA Variables
# Variables to check
#$JiraProject = Change in line 82 of module
#$JIRAServer - Change in line 25 of module
#region JIRA Variables
#region JIRA Functions
<#
.Synopsis
   Connects to Atlassian Jira Help Desk
.DESCRIPTION
   Connects to the JIRA Help Desk to be able to update tickets when scripts are run.
.EXAMPLE
   Connect-JIRA
#>
function Connect-Jira {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [PSCredential]$JIRACred
    )
    Begin {
        Import-Module JiraPS
        $JIRAServer = "https://your.JIRASITE.com"
        if ((Get-JiraConfigServer) -ne $JIRAServer) {
            Set-JiraConfigServer -Server $JIRAServer
        }
        if (!$PSBoundParameters['JIRACred']) {
            # See ReadME and SillyDav.PoSH.Variables for configuring -Username variable
            $JIRACred = Get-Credential -UserName $CurrentUserExtensionAttributes.ExtensionAttribute2 -Message "Enter JIRA credentials"
        }
        do {
            try {
                New-JiraSession -Credential $JIRACred -ErrorAction Stop
            }
            catch {
                Write-Output "Unable to Connect with credentials Given please re-enter valid credentials"
                $JIRACred = Get-Credential -UserName $CurrentUserExtensionAttributes.ExtensionAttribute2 -Message "Enter JIRA credentials"
                New-JiraSession -Credential $JIRACred
            }
        } until (Get-JiraSession)
    }
}

<#
.Synopsis
   Comments on and adds a worklog to the Atlassian Jira Help Desk
.DESCRIPTION
   Connects to the JIRA Help Desk to be able to comment and add work logs to tickets. Collects variables from central file to run.
.EXAMPLE
   Comment-JIRA
.EXAMPLE
   Comment-JIRA -JiraTicket "TEST-203" -JiraComment "Almost done" -JiraWorklog "Working on it" -JiraTimeSpent "00:10"
#>
function Write-JiraComment {
    [CmdletBinding()]
    Param (
        # Jira Ticket Number eg "TEST-201"
        [Parameter(Mandatory = $true)]
        [string]$JiraTicket,
        # The comment you wish to add to the ticket eg "comment example here"
        # Visible to ticket creator/end user
        [Parameter(Mandatory = $false)]
        [string]$JiraComment,
        # The Worklog you wish to add to the ticket eg "Work done"
        [Parameter(Mandatory = $false)]
        [string]$JiraWorkLog,
        # The amount of time spent you wish to add to the ticket eg "00:15"
        # Format is hh:mm
        [Parameter(Mandatory = $false)]
        [string]$JiraTimeSpent
    )
    Begin {
        if (!(Get-JiraSession)) {
            Connect-Jira
        }
    }
    Process {
        # Enter Default Jira Project if only using ticket # and not jiraproject-ticket# format
        $JiraProject = "TEST"
        # This if statement is for if only the ticket # is specified it will add correct the format
        if ($JiraTicket -notmatch "^$JiraProject") {
            # Note: This is our format for tickets you may need to alter this
            # example "TEST" + - + "203"
            $JiraTicket = $JiraProject + "-" + $JiraTicket
        }
        # Visible comment to end user
        Add-JiraIssueComment -Issue $JiraTicket -Comment $JiraComment
        # Logging work done and time spent
        Add-JiraIssueWorklog -Issue $JiraTicket -TimeSpent $JiraTimeSpent -Comment $JiraWorkLog -DateStarted (Get-Date)
    }
}
#endregion JIRA Functions

#region Jira Comments
<# Example of how to do multiline comments
$JiraComment = @"
            $User account has been created.
            Add anything here you want the end user to see
            It will appear multiline in JIRA
"@
#>
#endregion Jira Comments