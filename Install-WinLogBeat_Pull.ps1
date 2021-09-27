#Requires -RunAsAdministrator
<#
.SYNOPSIS
  A script to install winlogbeat and Sysmon

.DESCRIPTION
  This script is to be deployed by GPO and install both winlogbeat and Sysmon.
  By default, your winlogbeat installer should be named winlogbeat.msi. You will require a directory in root of C:\
  called Share. Place the winlogbeat.msi, sysmon64.exe sysmonconfig-export.xml and winlogbeat.yml in c:\Share
  This path can be changed by the $fileshare variable.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        0.1.0 Initial
  Author:         Acidcrash376
  Creation Date:  11/09/2021
  Last Update:	  11/09/2021
  Purpose/Change: Initial
  Web:            https://github.com/acidcrash376/Install-winlogbeat

.PARAMETER Verbosemode 
  Not Required
  No value required. Enables Verbose output for the script.

.EXAMPLE
  ./Install-winlogbeat.ps1

.EXAMPLE
  ./Install-winlogbeat.ps1 -Verbosemode


.TODO
  - Allow alternate filenames
#>

Param([switch] $verbosemode )
if ($verbosemode -eq $true)
{
    $VerbosePreference="Continue"
    Write-Verbose "Verbose mode is ON"
} else {
}

########################
# Edit these variables #
########################
$ErrorLogfile = "\\cydc01\Tools\$(gc env:computername)\Error.log"             # Path for Error Log, edit the path
$InstallLogfile = "\\cydc01\Tools\$(gc env:computername)\Install.log"         # Path for Install Log, edit the path
$fileshare = "\\cydc01\Tools\"                                                # Path for fileshare, edit the path
#$SplunkU = "splunk"                                                          # Define the local Splunk management user
#$SplunkP = "password"                                                        # Define the local Splunk management user password
$rindex = "192.168.59.199:5044"                                               # Define the Elasticsearch IP and port
$beatsver = "7.13.4"													      # Define the WinLogBeat version
#########################
# Don't edit after here #
#########################


Function Write-ErrorLogHead
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $ErrorLogfile -value $logstring
}

Function Write-InstallLogHead
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $InstallLogfile -value $logstring
}

Function Write-ErrorLog
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $ErrorLogfile -value $logstring
}

Function Write-InstallLog
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $InstallLogfile -value $logstring
}

Function Get-DTG
{
    $(((Get-Date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fffZ"))                       # Date Time Group suffix for logging, YYYY-MM-DD HH:mm:ss Zulu time
}

Function Test-winlogbeat () 
{
	Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-winlogbeat]"                      #                                   
    $software = "Beats winlogbeat-oss";                                                         # Defines the variable for winlogbeat
	$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -like $software }) -ne $null  # Check the registry for the existance of winlogbeat
    Write-Verbose "Testing to see if winlogbeat is installed"                                   # If Verbose is enabled, print to console status

	If(-Not $installed) {                                                                       # If WinLogBeat is not installed...
        Write-Verbose "winlogbeat is not installed"                                             # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat is not currently installed"        # Log it
        Install-winlogbeat                                                                      # Call the Install-winlogbeat function
	} else {                                                                                    # If WinLogBeat is installed... 
		Write-Verbose "winlogbeat is installed"                                                 # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat is installed"                      # Log it
	}
}

Function Test-SMBConnection () 
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-SMBConnection]"                    # Log it
	$test = Test-Path -Path $fileshare                                                           # Test whether the fileshare can be reached
	if($test) {
        Write-Verbose "$(fileshare) can be reached"                                              # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - $fileshare successfully reached"               # Log it successfully being able to reach the fileshare
	} else {
        Write-Verbose "$(fileshare) could not be reached"                                        # If Verbose is enabled, print to console status
		Write-ErrorLog -logstring "$(Get-DTG) - $fileshare fileshare could not be reached"       # Log it failing in the Error log and exit the script
        exit
	}
}

Function Check-ConfHash ()
{                                                           
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Check-ConfHash]"
    $winlogbeatconf = $fileshare+'winlogbeat.yml'                                                # Define the variable for the fileshare path to winlogbeat.yml
    $srvwinlogbeatconfHash = Get-FileHash -Path $winlogbeatconf -Algorithm SHA256                # SHA256 Hash the winlogbeat.yml on the 
    Write-InstallLog -logstring "$(Get-DTG) - $srvwinlogbeatconfHash"                            # Log the hash

    $winlogbeatconf= "C:\Program Files\elastic\Beats\"+$beatsver+"\winlogbeat\winlogbeat.yml"    # Define the variable for the local path to winlogbeat.yml

    $$testlocalwinlogbeatconf = Test-Path $                                                      # Test the path of the local winlogbeat.yml for the if statement:
	                                                                                             # If present, do the hashes match: Yes, move on. No, replace with file from server
                                                                                                 # If not present, copy from file server
                                                                                                  
    $srvWinLogBeatHashsha256 = ${srvInputsHash}.Hash                                             # Define the variable for the server winlogbeat.yml hash

    If($$testlocalwinlogbeatconf)                                                                # If the test of the local winlogbeat.yml is true...
    {
        
        Write-Verbose "WinLogBeat.yml exists"
        Write-InstallLog -logstring "$(Get-DTG) - WinLogBeat.yml exists"                         # Log it
        $localWinLogBeatHash = Get-FileHash -Path $winlogbeatconf-Algorithm SHA256               # Hash the local winlogbeat.yml and define as a variable for comparing
        Write-InstallLog -logstring "$(Get-DTG) - $localWinLogBeatHash"                          # Log it

        If($srvWinLogBeatHashsha256 -eq ${localWinLogBeatHash}.hash)                             # If winlogbeat.yml hashes match
        {
            Write-Verbose "winlogbeat.yml match, no action required"
            Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml match, no action required"  # Log it, no action required

        } else {
            
            Write-Verbose "winlogbeat.yml does not match, replacing the config"
            Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml do not match, replacing the config"  # If they don't match, log it
            Copy-Item $winlogbeatconf -Destination $winlogbeatconf -Force                        # Copy the file from the file server and overwrite the local version

        }
    } else {
        
        Write-Verbose "winlogbeat.yml is not present, copying over"
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml does not exist"                 # If winlogbeat.yml is not present, log it
        Copy-Item $winlogbeatconf -Destination $winlogbeatconf -Force                            # Copy the winlogbeat.yml from the fileserver to the local machine
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml copied from fileserver"         # Log it
    
    }
}

Function Install-winlogbeat ()
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Install-winlogbeat]"
    $winlogbeatmsi = $fileshare+"winlogbeat.msi"                                                 # Concatanate the fileshare and the filename for the Installer
    $msitest = Test-Path -Path $winlogbeatmsi                                                    # Test the patch exists
    if($msitest)                                                                                 # If yes, install splunk with the following values
    {
        Start-Process -FilePath $winlogbeatmsi #–Wait -Verbose –ArgumentList "AGREETOLICENSE=yes SPLUNKUSERNAME=`"$($splunkU)`" SPLUNKPASSWORD=`"$($splunkP)`" RECEIVING_INDEXER=`"$($rindex)`" WINEVENTLOG_APP_ENABLE=1 WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 WINEVENTLOG_FWD_ENABLE=1 WINEVENTLOG_SET_ENABLE=1 ENABLEADMON=1 PERFMON=network /quiet"
        Write-InstallLog -logstring "$(Get-DTG) - WinLogBeat has been installed"
        Write-Verbose "WinLogBeat has been installed"
    } else {
        Write-ErrorLog -logstring "$(Get-DTG) - WinLogBeat msi is not found."                    # If no, exit the script
        Write-Verbose "WinLogBeat install msi not found, exiting..."
        exit
    }
}

Function Install-Sysmon ()
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Install-Sysmon]"                        # Log it
    
    $sysmonexe = $fileshare+"sysmon64.exe"                                                       # Concatanate the fileshare and the filename for Sysmon
    $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                           # Concatanate the fileshare and the filename for Sysmon Config
    
    $sysmontest = Test-Path -Path $sysmonexe                                                     # Tests whether the Sysmon exe exists
    $sysmonconftest = Test-Path -Path $sysmonconf                                                # Tests whether the Sysmon conf exists
    
    If(($sysmontest) -and ($sysmonconftest))                                                     # If both the exe and the conf exist
    { 
        if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                              # Check if sysmon is already running, if no:
        { 
            New-Item -Path $env:ProgramFiles -Name Sysmon -ItemType Directory -Force | Out-Null  # Create the system directory in c:\Program Files
            $sysmon = $fileshare+"sysmon64.exe"                                                  # Define variable for remote path to the executable
            $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                   # Define variable for remote path to the config
            Copy-Item $sysmon -Destination $env:ProgramFiles\Sysmon -Force                       # Copy the executable from the share
            Copy-Item $sysmonconf -Destination $env:ProgramFiles\Sysmon\ -Force                  # Copy the config from the share
            Write-Verbose "Sysmon exe and conf has been copied over"
            & $env:ProgramFiles\Sysmon\sysmon64.exe -i $env:ProgramFiles\Sysmon\sysmonconfig-export.xml -accepteula > $null  # Run Sysmon with the specified config, accepting the EULA and outputing to $null
            if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                          # Checks if Sysmon started correctly
            { 
                Write-Verbose "Sysmon Not Running"
                Write-ErrorLog -logstring "$(Get-DTG) - Sysmon failed to start"                  # Logs it having failed
            } else {
                Write-Verbose "Sysmon is running"
                Write-InstallLog "$(Get-DTG) - Sysmon running"                                   # Logs it running successfully
            } 
        } else { 
            & $env:ProgramFiles\Sysmon\sysmon64.exe -u > $null                                   # Checked if sysmon was running and yes
            Write-Verbose "Stopping Sysmon"
            $sysmon = $fileshare+"sysmon64.exe"                                                  # Defines variable for remote path to the executable
            $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                   # Defines variable for remote path to the config
            Copy-Item $sysmon -Destination $env:ProgramFiles\Sysmon -Force                       # Copy the executable from the share
            Copy-Item $sysmonconf -Destination $env:ProgramFiles\Sysmon\ -Force                  # Copy the config from the share
            Write-Verbose "Copying and overwriting Sysmon exe and conf"
            & $env:ProgramFiles\Sysmon\sysmon64.exe -i $env:ProgramFiles\Sysmon\sysmonconfig-export.xml -accepteula > $null  # Run Sysmon with the specified config, accepting the EULA and outputting t $null
            if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                          # Checks if Sysmon started correctly
            { 
                Write-Verbose "Sysmon Not Running"                                  
                Write-ErrorLog -logstring "$(Get-DTG) - Sysmon failed to start"                  # Logs it having failed
            } else {
                Write-Verbose "Sysmon is running"
                Write-InstallLog "$(Get-DTG) - Sysmon running"                                   # Logs it running successfully
            }
        }
    } else {
        Write-Verbose "Sysmon and/or Sysmon config not found"
        Write-ErrorLog -logstring "$(Get-DTG) - Sysmon64 and sysmonconfig not found"             # Sysmon and/or Sysmon config not found, exiting script
        exit
    }
     
   
}

Function Restart-WinLogBeat ()
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Restart-WinLogBeat]"
    #Stop-Service SplunkForwarder                                                                # Stop-Service causes issues, using alternate method below
    $testWinlogBeat = Get-Service winlogbeat                                                     # Check if WinLogBeat is running
    If(($testWinlogBeat).Status -eq 'Running')                                                   # If yes...
    {
        #Restart-Service SplunkForwarder                                                         # Restart-Service causes issues, using alternate method
        & "C:\program files\Elastic\Beat\"+$beatsver+"winlogbeat\winlogbeat.exe" "restart" > $null           # Restart WinLogBeat service
        #Start-Service SplunkForwarder
        $testWinlogBeat1 = Get-Service winlogbeat                                                # Check whether WinLogBeat service has restarted successfully
        if(($testWinlogBeat1).Status -eq 'Running')
        {
            Write-Verbose "WinLogBeat has restarted successfully"
            Write-InstallLog -logstring "$(Get-DTG) - WinLogBeat has been restarted successfully"
        } else {
            Write-Verbose "WinLogBeat has failed to restart successfully"
            Write-ErrorLog -logstring "$(Get-DTG) - WinLogBeat could not be started" # WinLogBeat has failed to start, log it and exit script
            exit
        }
    } else {
        & "C:\program files\Elastic\Beat\"+$beatsver+"winlogbeat\winlogbeat.exe" "start" > $null             # WinLogBeat was not running, starting it now
        $testWinlogBeat2 = Get-Service WinLogBeat                                                # Checks if WinLogBeat has started successfully
        if(($testWinlogBeat2).Status -eq 'Running')
        {
            Write-Verbose "WinLogBeat has started successfully"
            Write-InstallLog -logstring "$(Get-DTG) - WinLogBeatr has been restarted successfully"
        } else {
            Write-Verbose "WinLogBeat has failed to start"
            Write-ErrorLog -logstring "$(Get-DTG) - WinLogBeat could not be started"             # WinLogBeat has failed to start, log it and exit script
            exit
        }
    }
}

Write-InstallLogHead -logstring "--------------------------------------------"
Write-InstallLogHead -logstring "|WinLogBeat installation script Install log|"
Write-InstallLogHead -logstring "--------------------------------------------`n"
Write-ErrorLogHead -logstring "------------------------------------------"
Write-ErrorLogHead -logstring "|WinLogBeat installation script Error log|"
Write-ErrorLogHead -logstring "------------------------------------------`n"

Write-Host "Installing WinLogBeat and Sysmon.`nThis will take a couple of minutes."
Test-winlogbeat
Test-SMBConnection
Check-ConfHash
Install-Sysmon
Restart-WinLogBeat
Write-Host "WinLogBeat and Sysmon have been installed"
