<#
.SYNOPSIS
    Executes an SQL query against an Azure SQL Database with optional firewall rule management.

.DESCRIPTION
    This script executes an SQL query (either provided inline or loaded from a file) against an Azure SQL Database.
    It supports SQLCMD-style variable substitution and can add (and optionally remove) a temporary firewall rule
    to the Azure SQL Server to allow query execution from the current external IP address.

    **Firewall Rule Management:**  
    If the -FirewallIP parameter is provided, the script will attempt to add a temporary firewall rule to the Azure SQL Server.
    For firewall rule management, the -ResourceGroupName parameter must also be provided. If the -RemoveFirewallRuleAfterExecution
    flag is set, the firewall rule will be removed after executing the query.

.PARAMETER SqlServerName
    The fully-qualified domain name of the Azure SQL Server (e.g., FabrikamSQL.database.windows.net).

.PARAMETER DatabaseName
    The name of the Azure SQL Database to execute the query against.

.PARAMETER SqlLogin
    The SQL login username to authenticate against the database.

.PARAMETER SqlPassword
    The SQL login password to authenticate against the database.

.PARAMETER QueryType
    Specifies the type of query to execute. Accepts either "Inline" for an inline SQL query or "File" to load the query from a file.

.PARAMETER InlineQuery
    The SQL query provided directly as a string. Required if -QueryType is "Inline".

.PARAMETER ScriptFilePath
    The file path to a .sql file containing the query. Required if -QueryType is "File".

.PARAMETER SqlCmdVariables
    A hashtable containing key/value pairs for SQLCMD variable substitution. Variables in the SQL script should be formatted as $(VariableName).

.PARAMETER FirewallIP
    The external IP address (or start IP if using a range) to add to the Azure SQL Server firewall.
    If provided, the script will add a temporary firewall rule. Use the format "x.x.x.x" for a single IP.

.PARAMETER ResourceGroupName
    The name of the resource group that contains the Azure SQL Server.
    **Required** if -FirewallIP is provided.

.PARAMETER RemoveFirewallRuleAfterExecution
    A flag indicating whether the firewall rule added by the script should be removed after query execution.

.EXAMPLE
    # Execute an inline SQL query with variable substitution and manual firewall configuration.
    .\Invoke-AzureSqlQuery.ps1 `
        -SqlServerName "FabrikamSQL.database.windows.net" `
        -DatabaseName "MyDatabase" `
        -SqlLogin "MyUser" `
        -SqlPassword "MySecurePassword" `
        -QueryType "Inline" `
        -InlineQuery "SELECT * FROM Users WHERE Name = '$(UserName)'" `
        -SqlCmdVariables @{ UserName = "JohnDoe" } `
        -FirewallIP "196.21.30.50" `
        -ResourceGroupName "MyResourceGroup" `
        -RemoveFirewallRuleAfterExecution $true

.EXAMPLE
    # Execute a SQL script from a file with variable substitution.
    .\Invoke-AzureSqlQuery.ps1 `
        -SqlServerName "FabrikamSQL.database.windows.net" `
        -DatabaseName "MyDatabase" `
        -SqlLogin "MyUser" `
        -SqlPassword "MySecurePassword" `
        -QueryType "File" `
        -ScriptFilePath "C:\Scripts\MyQuery.sql" `
        -SqlCmdVariables @{ SomeVariable = "Value1"; AnotherVariable = "Value2" } `
        -FirewallIP "196.21.30.50" `
        -ResourceGroupName "MyResourceGroup" `
        -RemoveFirewallRuleAfterExecution $true

.PREREQUISITES
    - PowerShell 5.1 or later (or PowerShell Core)
    - Latest [SqlServer module](https://www.powershellgallery.com/packages/SqlServer) installed.
      Install using: Install-Module SqlServer -Force
    - If using firewall rule management, the latest [Az.Sql module](https://www.powershellgallery.com/packages/Az.Sql) installed.
      Install using: Install-Module Az.Sql -Force
    - Ensure you are connected to Azure with Connect-AzAccount (if using firewall rule management).

.NOTES
    This script is intended to be used as a custom task in an Azure release pipeline.
#>

[CmdletBinding()]
param(
    # Azure SQL connection details
    [Parameter(Mandatory = $true)]
    [string]$SqlServerName,

    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true)]
    [string]$SqlLogin,

    [Parameter(Mandatory = $true)]
    [string]$SqlPassword,

    # Query configuration
    [Parameter(Mandatory = $true)]
    [ValidateSet("Inline", "File")]
    [string]$QueryType,

    [Parameter(Mandatory = $false)]
    [string]$InlineQuery,

    [Parameter(Mandatory = $false)]
    [string]$ScriptFilePath,

    [Parameter(Mandatory = $false)]
    [hashtable]$SqlCmdVariables,

    # Firewall configuration
    [Parameter(Mandatory = $false)]
    [string]$FirewallIP,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [bool]$RemoveFirewallRuleAfterExecution = $false
)

# -------------------------------
# Module Imports and Validations
# -------------------------------

# Import the SqlServer module (required for Invoke-Sqlcmd)
try {
    Import-Module SqlServer -ErrorAction Stop
}
catch {
    Write-Error "SqlServer module is required. Please install it using 'Install-Module SqlServer' and try again."
    exit 1
}

# If firewall rule management is needed, import the Az.Sql module
if ($FirewallIP) {
    if (-not $ResourceGroupName) {
        Write-Error "When using -FirewallIP, the -ResourceGroupName parameter must be provided."
        exit 1
    }
    try {
        Import-Module Az.Sql -ErrorAction Stop
    }
    catch {
        Write-Error "Az.Sql module is required for firewall rule management. Please install it using 'Install-Module Az.Sql' and try again."
        exit 1
    }
}

# Validate QueryType parameters
switch ($QueryType) {
    "Inline" {
        if (-not $InlineQuery) {
            Write-Error "For QueryType 'Inline', the -InlineQuery parameter must be provided."
            exit 1
        }
    }
    "File" {
        if (-not $ScriptFilePath) {
            Write-Error "For QueryType 'File', the -ScriptFilePath parameter must be provided."
            exit 1
        }
        if (-not (Test-Path $ScriptFilePath)) {
            Write-Error "The specified SQL script file '$ScriptFilePath' does not exist."
            exit 1
        }
    }
}

# -------------------------------
# Function: Add-FirewallRule
# -------------------------------
function Add-FirewallRule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        [Parameter(Mandatory = $true)]
        [string]$FirewallIP
    )

    # Generate a unique rule name using the current timestamp.
    $ruleName = "TempRule_" + (Get-Date -Format "yyyyMMddHHmmss")
    try {
        Write-Host "Adding firewall rule '$ruleName' for IP '$FirewallIP' on server '$ServerName' in resource group '$ResourceGroupName'..."
        New-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -FirewallRuleName $ruleName `
            -StartIpAddress $FirewallIP `
            -EndIpAddress $FirewallIP `
            -ErrorAction Stop
        Write-Host "Firewall rule '$ruleName' added successfully."
        return $ruleName
    }
    catch {
        Write-Error "Failed to add firewall rule. Error: $_"
        throw $_
    }
}

# -------------------------------
# Function: Remove-FirewallRule
# -------------------------------
function Remove-FirewallRule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        [Parameter(Mandatory = $true)]
        [string]$RuleName
    )
    try {
        Write-Host "Removing firewall rule '$RuleName' from server '$ServerName' in resource group '$ResourceGroupName'..."
        Remove-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -FirewallRuleName $RuleName `
            -Force -ErrorAction Stop
        Write-Host "Firewall rule '$RuleName' removed successfully."
    }
    catch {
        Write-Error "Failed to remove firewall rule '$RuleName'. Error: $_"
    }
}

# -------------------------------
# Main Execution Block
# -------------------------------

# Initialize variables for later cleanup.
$firewallRuleName = $null
$serverShortName = $SqlServerName.Split('.')[0]

try {
    # Add firewall rule if FirewallIP is provided
    if ($FirewallIP) {
        $firewallRuleName = Add-FirewallRule -ResourceGroupName $ResourceGroupName -ServerName $serverShortName -FirewallIP $FirewallIP
        # Allow some time for the firewall rule to propagate (optional)
        Start-Sleep -Seconds 10
    }

    # Load SQL query from the appropriate source
    switch ($QueryType) {
        "Inline" {
            $query = $InlineQuery
        }
        "File" {
            Write-Host "Loading SQL query from file '$ScriptFilePath'..."
            $query = Get-Content -Path $ScriptFilePath -Raw
        }
    }

    Write-Host "Executing SQL query on database '$DatabaseName' at server '$SqlServerName'..."

    # Execute the SQL query using Invoke-Sqlcmd
    # Pass SQLCMD variables if provided
    if ($SqlCmdVariables) {
        $result = Invoke-Sqlcmd `
            -ServerInstance $SqlServerName `
            -Database $DatabaseName `
            -Username $SqlLogin `
            -Password $SqlPassword `
            -Query $query `
            -Variable $SqlCmdVariables `
            -ErrorAction Stop
    }
    else {
        $result = Invoke-Sqlcmd `
            -ServerInstance $SqlServerName `
            -Database $DatabaseName `
            -Username $SqlLogin `
            -Password $SqlPassword `
            -Query $query `
            -ErrorAction Stop
    }

    Write-Host "SQL query executed successfully."
    
    # If there is any output from the query, display it.
    if ($result) {
        Write-Output "Query Results:"
        $result | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred during execution: $_"
}
finally {
    # Remove the firewall rule if it was added and the removal flag is true.
    if ($firewallRuleName -and $RemoveFirewallRuleAfterExecution) {
        Remove-FirewallRule -ResourceGroupName $ResourceGroupName -ServerName $serverShortName -RuleName $firewallRuleName
    }
}