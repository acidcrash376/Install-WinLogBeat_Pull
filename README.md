# Deploy-WinLogBeat-Pull
A Splunk Forwarder deployment tool to pull the installer rather than push via WinRM

# Usage
## ~Batchfile~ [NO LONGER REQUIRED]
~@ECHO OFF~
~PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"\\Path\To\Share\Install-SplunkForwarder.ps1"""" -verbosemode' -Verb RunAs}";~

## GPO
New Group Policy Object
Computer Configuration > Preferences > Control Panel Settings > Scheduled Task
- New Task
- New Immediate Task (Windows 7)

### General
  Name: Install-SplunkForwarder
  User: NT AUTHORITY\System
### Actions
  Start a Program: 
    Script: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    Arguments: -executionpolicy Bypass -command "& \\Host\share\install-winlogbeat.ps1"
### Conditions
  
### Settings
[x]  Stock the task if it runs longer than: 1 Hour
### Common
[x]  Apply once and do not reapply.

 
Apply the GPO to the appropriate Org Unit, then either Gpupdate /force or let the Group Policy sync itself over time
