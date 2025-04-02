
# Information

The project at https://github.com/geeklearningio/gl-vsts-tasks-azure is not being updated. If you run into a problem with this task, you may need an alternative.

This is a [pure ChatGPT 03-mini response](/Prompt.md) scoped to reproduce a solution built in PowerShell to replicate the behavior of the Azure SQL Execute Query task.

```markdown
# Invoke-AzureSqlQuery

## Overview

**Invoke-AzureSqlQuery** is a PowerShell script designed to execute SQL queries against an Azure SQL Database. It supports both inline queries and SQL scripts loaded from a file, with SQLCMD-style variable substitution. In addition, the script can temporarily configure the Azure SQL Server firewall to allow access from a specified IP address, and optionally remove the rule after execution.

This tool is intended to be integrated as a custom task in Azure release pipelines.

## Features

- **SQL Query Execution:**  
  Execute SQL queries either provided inline or read from a file.
  
- **SQLCMD Variable Substitution:**  
  Substitute variables in the SQL query using SQLCMD syntax (e.g., `$(VariableName)`) by providing a hashtable of key/value pairs.

- **Azure Resource Manager Integration:**  
  Connect to your Azure SQL Database using specified connection parameters such as server name, database name, SQL login, and password.

- **Firewall Rule Management:**  
  Optionally add a temporary firewall rule to allow your IP (or a specified IP) to access the Azure SQL Server.  
  You can choose to automatically remove the firewall rule after executing the query.

## Prerequisites

- **PowerShell Version:**  
  PowerShell 5.1 or later (or PowerShell Core).

- **Required Modules:**  
  - [SqlServer](https://www.powershellgallery.com/packages/SqlServer)  
    Install using:  
    ```powershell
    Install-Module SqlServer -Force
    ```
  - [Az.Sql](https://www.powershellgallery.com/packages/Az.Sql) (only required if using firewall rule management)  
    Install using:  
    ```powershell
    Install-Module Az.Sql -Force
    ```
  - Ensure you are authenticated to Azure if you plan to manage firewall rules:  
    ```powershell
    Connect-AzAccount
    ```

## Parameters

| Parameter                         | Description                                                                                                              | Required When                    |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------- |
| `-SqlServerName`                  | Fully-qualified domain name of the Azure SQL Server (e.g., `FabrikamSQL.database.windows.net`).                         | Always required                  |
| `-DatabaseName`                   | The Azure SQL Database name.                                                                                             | Always required                  |
| `-SqlLogin`                       | SQL login username for authentication.                                                                                 | Always required                  |
| `-SqlPassword`                    | SQL login password for authentication.                                                                                 | Always required                  |
| `-QueryType`                      | Specifies the query type: `"Inline"` for an inline SQL query or `"File"` to load from a file.                             | Always required                  |
| `-InlineQuery`                    | The SQL query string (required if `-QueryType` is `"Inline"`).                                                           | When `-QueryType` is Inline      |
| `-ScriptFilePath`                 | Path to the SQL script file (required if `-QueryType` is `"File"`).                                                      | When `-QueryType` is File        |
| `-SqlCmdVariables`                | A hashtable of SQLCMD variables for substitution (e.g., `@{ Var1 = "Value1"; Var2 = "Value2" }`).                         | Optional                         |
| `-FirewallIP`                     | The IP address (or start IP for a range) to add to the Azure SQL Server firewall.                                        | Optional (if provided, see below)|
| `-ResourceGroupName`              | The name of the resource group containing the Azure SQL Server. **Required if** `-FirewallIP` is provided.                 | Required with `-FirewallIP`      |
| `-RemoveFirewallRuleAfterExecution` | A boolean flag indicating whether to remove the temporary firewall rule after query execution.                           | Optional (default: `$false`)     |

## Example Usages

### Execute an Inline SQL Query

```powershell
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
```

### Execute a SQL Script from a File

```powershell
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
```

## Integration in Azure Release Pipeline

To integrate this script into your Azure release pipeline:

1. **Include the Script in Your Repository:**  
   Add the `Invoke-AzureSqlQuery.ps1` file to your source control.

2. **Configure the Pipeline Task:**  
   Use a PowerShell task in your pipeline that calls this script with the appropriate parameters.  
   Ensure that the agent has the required modules installed or include a step to install them.

3. **Authentication for Firewall Management:**  
   If using firewall rule management, make sure the pipeline agent is authenticated to Azure (e.g., using an Azure service connection).

## Error Handling & Logging

- The script includes robust error handling using try/catch blocks.  
- Detailed error messages are logged using `Write-Error` for easier troubleshooting.
- Temporary firewall rules are cleaned up in the `finally` block if the `-RemoveFirewallRuleAfterExecution` flag is set.

## Additional Notes

- **Propagation Delay:**  
  After adding a firewall rule, there might be a short delay before the rule is effective. The script waits 10 seconds by default; you can adjust this delay as needed.

- **Module Versions:**  
  This script uses the latest versions of the SqlServer and Az.Sql modules. Ensure that your environment is updated to avoid compatibility issues.

---

Feel free to contribute or raise issues if you encounter any problems.

Happy querying!
```

---

You can now add these files to your repository and integrate the script into your Azure release pipeline as needed. If you have any questions or need further modifications, please let me know!