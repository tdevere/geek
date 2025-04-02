**Final Prompt:**

**Objective:**  
Develop a PowerShell script to replicate the functionality of the Azure SQL Execute Query task (as documented on [Azure SQL Execute Query](https://github.com/geeklearningio/gl-vsts-tasks-azure/wiki/Azure-SQL-Execute-Query)). This script will be used as a custom task in our Azure release pipeline.

**Requirements:**  
1. **SQL Query Execution:**  
   - The script should execute a SQL query against an Azure SQL Database.  
   - It must support two modes for specifying the SQL query:
      - **Inline Script:** The SQL query is provided directly as a parameter.
      - **Script File:** The SQL query is loaded from a file, with the file path specified as a parameter.
   - The script should allow for SQLCMD-style variable substitution (e.g., variables formatted as `$(Var1)`) using a parameterized approach.

2. **Azure Resource Manager Integration:**  
   - Accept connection parameters such as the Azure SQL Server name (e.g., `FabrikamSQL.database.windows.net`), database name, login, and password.
   - Use the current modules (e.g., the latest SqlServer module) with `Invoke-Sqlcmd` (no strong preference between methods, choose the most appropriate current approach).

3. **Firewall Rule Management:**  
   - Provide an option to manually specify firewall rule configuration via parameters.  
   - Parameters should include options for:
      - The external IP address (or start/end IP range) to be added to the Azure SQL Server firewall.
      - A flag to indicate whether the rule should be removed after the script execution.

4. **Parameterization and Usage:**  
   - The script should be fully parameterized. Provide clear examples in comments and documentation on how to invoke the script using command-line parameters.
   - Include parameters for all necessary inputs such as:
      - SQL script type (Inline or File)
      - SQL script content or file path
      - SQLCMD variable mappings (e.g., as a hashtable or multiple key/value pairs)
      - Azure SQL connection details (server, database, login, password)
      - Firewall configuration (IP addresses, removal flag)

5. **Error Handling & Logging:**  
   - Incorporate robust error handling and logging to capture any issues during query execution or firewall rule modifications.

6. **Compatibility:**  
   - Use current, up-to-date PowerShell modules and versions, as this solution is intended to replace an older system.

**Deliverable:**  
Provide a complete, self-contained PowerShell script that meets the above requirements. The script should be well-commented, modular, and include:

- Detailed inline comments explaining each section.
- Example usages in the comments (e.g., how to run the script from the command line with the required parameters).
- Clear instructions on any prerequisites (such as installation of the latest SqlServer module).

**Additional Notes:**  
- Use a generic script approach for executing SQL queries without embedding specific predefined operations.
- Ensure that the script is flexible enough to be integrated as a custom task in our Azure release pipeline.

**Example Usage:** 
 
```powershell
# Example: Execute an inline SQL query with variable substitution and manual firewall configuration
.\Invoke-AzureSqlQuery.ps1 `
   -SqlServerName "FabrikamSQL.database.windows.net" `
   -DatabaseName "MyDatabase" `
   -SqlLogin "MyUser" `
   -SqlPassword "MySecurePassword" `
   -QueryType "Inline" `
   -InlineQuery "SELECT * FROM Users WHERE Name = '$(UserName)'" `
   -SqlCmdVariables @{ UserName = "JohnDoe" } `
   -FirewallIP "196.21.30.50" `
   -RemoveFirewallRuleAfterExecution $true
```

```powershell
# Example: Execute a SQL script from a file with variable substitution
.\Invoke-AzureSqlQuery.ps1 `
   -SqlServerName "FabrikamSQL.database.windows.net" `
   -DatabaseName "MyDatabase" `
   -SqlLogin "MyUser" `
   -SqlPassword "MySecurePassword" `
   -QueryType "File" `
   -ScriptFilePath "C:\Scripts\MyQuery.sql" `
   -SqlCmdVariables @{ SomeVariable = "Value1"; AnotherVariable = "Value2" } `
   -FirewallIP "196.21.30.50" `
   -RemoveFirewallRuleAfterExecution $true
```

Ensure that the solution provides detailed logging and error messages, making it straightforward to integrate into our release pipeline.

---
