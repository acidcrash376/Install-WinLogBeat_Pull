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
  Version:        1.0.2 Beta
  Author:         Acidcrash376
  Creation Date:  11/09/2021
  Last Update:	  12/10/2021
  Purpose/Change: Change logs to go to a separate directory. Fileshare should be read only and Logshare should be read, write & modify. To restrict malicious changes to the script by un-authorised users. 
  Web:            https://github.com/acidcrash376/Install-WinLogBeat_Pull
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
$ErrorLogfile = "\\cydc01\Share2\$(gc env:computername)\Error.log"                               # Path for Error Log, edit the path
$InstallLogfile = "\\cydc01\Share2\$(gc env:computername)\Install.log"                           # Path for Install Log, edit the path
$fileshare = "\\cydc01\Share\"                                                                  # Path for fileshare, edit the path
$logshare = "\\cydc01\Share2"                                                                   # Path for Log share, edit the path
$installermsi = "winlogbeat-oss-7.13.4-windows-x86_64.msi"                                      # Define the filename of the installer msi
$beatsver = "7.13.4"													                        # Define the WinLogBeat version
#########################
# Don't edit after here #
#########################


Function Write-ErrorLogHead
{
   Param ([string]$logstring)
   New-Item -Path $logshare -Name "$(gc env:computername)" -ItemType "directory" -Force > $null
   Add-content $ErrorLogfile -value $logstring
}

Function Write-InstallLogHead
{
   Param ([string]$logstring)
   New-Item -Path $logshare -Name "$(gc env:computername)" -ItemType "directory" -Force > $null
   Add-content $InstallLogfile -value $logstring
}

Function Write-ErrorLog
{
   Param ([string]$logstring)
   New-Item -Path $logshare -Name "$(gc env:computername)" -ItemType "directory" -Force > $null
   Add-content $ErrorLogfile -value $logstring
}

Function Write-InstallLog
{
   Param ([string]$logstring)
   New-Item -Path $logshare -Name "$(gc env:computername)" -ItemType "directory" -Force > $null
   Add-content $InstallLogfile -value $logstring
}

Function Get-DTG
{
    $(((Get-Date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fffZ"))                       # Date Time Group suffix for logging, YYYY-MM-DD HH:mm:ss Zulu time
}

Function Test-winlogbeat () 
{
	Write-Host "[Test-Winlogbeat]" -Foregroundcolor Green
	Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-winlogbeat]"                       #                                   
    $software = "Beats winlogbeat-oss";                                                          # Defines the variable for winlogbeat
	$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -like $software }) -ne $null  # Check the registry for the existance of winlogbeat
    Write-Verbose "Testing to see if winlogbeat is installed"                                    # If Verbose is enabled, print to console status

	If(-Not $installed) {                                                                        # If WinLogBeat is not installed...
        Write-Verbose "winlogbeat is not installed"                                              # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat is not currently installed"         # Log it
        $installedtest = $true
		Test-SMBConnection                                                                       # Call the Test-SMBConnection function
		#Install-winlogbeat                                                                      # Call the Install-winlogbeat function
	} else {                                                                                     # If WinLogBeat is installed... 
		Write-Verbose "winlogbeat is installed"                                                  # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat is installed"                       # Log it
		Test-SMBConnection1																		 # Call the Test-SMBConnection1 function
	}
}

Function Test-SMBConnection () 
{
    Write-Host "[Test-SMBConnection]" -Foregroundcolor Green
	Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-SMBConnection]"                    # Log it
	$test = Test-Path -Path $fileshare                                                           # Test whether the fileshare can be reached
	if($test) {
        Write-Verbose $fileshare" can be reached"                                                # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - $fileshare successfully reached"               # Log it successfully being able to reach the fileshare
		if($installedtest) {
			Install-winlogbeat
		} else {
		}
	} else {
        Write-Verbose $fileshare "could not be reached"                                          # If Verbose is enabled, print to console status
		Write-ErrorLog -logstring "$(Get-DTG) - $fileshare fileshare could not be reached"       # Log it failing in the Error log and exit the script
        exit
	}
}

Function Test-SMBConnection1 () 
{
	Write-Host "[Test-SMBConnection1]" -Foregroundcolor Green    
	Write-Host $fileshare
	Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-SMBConnection]"                    # Log it
	$test = Test-Path -Path $fileshare                                                           # Test whether the fileshare can be reached
	if($test) {
        Write-Verbose "$fileshare can be reached"                                                # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - $fileshare successfully reached"               # Log it successfully being able to reach the fileshare
		Check-ConfHash
	} else {
        Write-Verbose "$(fileshare) could not be reached"                                        # If Verbose is enabled, print to console status
		Write-ErrorLog -logstring "$(Get-DTG) - $fileshare fileshare could not be reached"       # Log it failing in the Error log and exit the script
        exit
	}
}

Function Check-ConfHash ()
{                                                           
	Write-Host "[Check-ConfHash]" -Foregroundcolor Green
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Check-ConfHash]"
    $winlogbeatconf = $fileshare+'winlogbeat.yml'                                                # Define the variable for the fileshare path to winlogbeat.yml
    $srvwinlogbeatconfHash = Get-FileHash -Path $winlogbeatconf -Algorithm SHA256                # SHA256 Hash the winlogbeat.yml on the 
    Write-InstallLog -logstring "$(Get-DTG) - $srvwinlogbeatconfHash"                            # Log the hash

    $localwinlogbeatconf= "C:\ProgramData\Elastic\Beats\winlogbeat\"+"winlogbeat.yml"            # Define the variable for the local path to winlogbeat.yml
    $testlocalwinlogbeatconf = Test-Path $localwinlogbeatconf                                    # Test the path of the local winlogbeat.yml for the if statement:
	                                                                                             # If present, do the hashes match: Yes, move on. No, replace with file from server
                                                                                                 # If not present, copy from file server
                                                                                                  
    $srvWinLogBeatHashsha256 = ${srvInputsHash}.Hash                                             # Define the variable for the server winlogbeat.yml hash

    If($testlocalwinlogbeatconf)                                                                 # If the test of the local winlogbeat.yml is true...
    {
        
        Write-Verbose "WinLogBeat.yml exists"
        Write-InstallLog -logstring "$(Get-DTG) - WinLogBeat.yml exists"                         # Log it
        $localWinLogBeatHash = Get-FileHash -Path $winlogbeatconf-Algorithm SHA256               # Hash the local winlogbeat.yml and define as a variable for comparing
        Write-InstallLog -logstring "$(Get-DTG) - $localWinLogBeatHash"                          # Log it

        If($srvWinLogBeatHashsha256 -eq ${localWinLogBeatHash}.hash)                             # If winlogbeat.yml hashes match
        {
            Write-Verbose "winlogbeat.yml match, no action required"
            Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml match, no action required"  # Log it, no action required
			Install-Sysmon

        } else {
            
            Write-Verbose "winlogbeat.yml does not match, replacing the config"
            Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml do not match, replacing the config"  # If they don't match, log it
			Copy-Item $winlogbeatconf -Destination $localwinlogbeatconf -Force                   # Copy the file from the file server and overwrite the local version
			Install-Sysmon

        }
    } else {
        
        Write-Verbose "winlogbeat.yml is not present, copying over"
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml does not exist"                 # If winlogbeat.yml is not present, log it
		Copy-Item $winlogbeatconf -Destination $localwinlogbeatconf -Force                       # Copy the winlogbeat.yml from the fileserver to the local machine
        Write-InstallLog -logstring "$(Get-DTG) - winlogbeat.yml copied from fileserver"         # Log it
		Install-Sysmon
    
    }
}

Function Install-winlogbeat ()
{
	Write-Host "[Install-WinLogBeat]" -Foregroundcolor Green
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Install-winlogbeat]"
	$winlogbeatmsi = "$fileshare"+"$installermsi" 
	New-Item -Path "C:\Tools\" -Name Installer -ItemType Directory -Force  >$null
    Copy-Item $winlogbeatmsi -Destination "C:\Tools\Installer\" -Force >$null
    #$winlogbeatmsi = $fileshare+"winlogbeat-oss-7.13.4-windows-x86_64.msi"                      # Concatanate the fileshare and the filename for the Installer
    $msitest = Test-Path -Path $winlogbeatmsi                                                    # Test the patch exists
    if($msitest)                                                                                 # If yes, install splunk with the following values
    {
		msiexec.exe /i $winlogbeatmsi /QN
		Write-InstallLog -logstring "$(Get-DTG) - WinLogBeat has been installed"
        Write-Verbose "WinLogBeat has been installed"
		Check-ConfHash
    } else {
        Write-ErrorLog -logstring "$(Get-DTG) - WinLogBeat msi is not found."                    # If no, exit the script
        Write-Verbose "WinLogBeat install msi not found, exiting..."
        exit
    } 
}

Function Install-Sysmon ()
{
	Write-Host "[Install-Sysmon]" -Foregroundcolor Green
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Install-Sysmon]"                        # Log it
    
    $sysmonexe = $fileshare+"sysmon64.exe"                                                       # Concatanate the fileshare and the filename for Sysmon
    $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                           # Concatanate the fileshare and the filename for Sysmon Config
    $sysmontest = Test-Path -Path $sysmonexe                                                     # Tests whether the Sysmon exe exists
    $sysmonconftest = Test-Path -Path $sysmonconf                                                # Tests whether the Sysmon conf exists
    
    If(($sysmontest) -and ($sysmonconftest))                                                     # If both the exe and the conf exist
    { 
        if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                              # Check if sysmon is already running, if no:
        { 
            New-Item -Path $env:ProgramFiles -Name Sysmon -ItemType Directory -Force > $null  # Create the system directory in c:\Program Files
            $sysmon = $fileshare+"sysmon64.exe"                                                  # Define variable for remote path to the executable
            $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                   # Define variable for remote path to the config
            Copy-Item $sysmon -Destination $env:ProgramFiles\Sysmon -Force                       # Copy the executable from the share
            Copy-Item $sysmonconf -Destination $env:ProgramFiles\Sysmon\ -Force                  # Copy the config from the share
            Write-Verbose "Sysmon exe and conf has been copied over"
            & $env:ProgramFiles\Sysmon\sysmon64.exe -i $env:ProgramFiles\Sysmon\sysmonconfig-export.xml -accepteula > $null  # Run Sysmon with the specified config, accepting the EULA and outputing to $null
            if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null) {                        # Checks if Sysmon started correctly
                Write-Verbose "Sysmon Not Running"
                Write-ErrorLog -logstring "$(Get-DTG) - Sysmon failed to start"                  # Logs it having failed
            } else {
                Write-Verbose "Sysmon is running"
                Write-InstallLog "$(Get-DTG) - Sysmon running"                                   # Logs it running successfully
				Restart-WinLogBeat                                                               # Call Restart-WinLogBeat function
            } 
        } else { 
            Write-Verbose "Stopping Sysmon"
			& $env:ProgramFiles\Sysmon\sysmon64.exe -u > $null                                   # Checked if sysmon was running and yes
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
				Restart-WinLogBeat  
            } #>
        }
    } else {
        Write-Verbose "Sysmon and/or Sysmon config not found"
        Write-ErrorLog -logstring "$(Get-DTG) - Sysmon64 and sysmonconfig not found"             # Sysmon and/or Sysmon config not found, exiting script
        exit
    }
     
   
} 

Function Restart-WinLogBeat ()
{
	Write-Host "[Restart-WinLogBeat]" -Foregroundcolor Green
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Restart-WinLogBeat]"
    $testWinlogBeat = Get-Service winlogbeat                                                     # Check if WinLogBeat is running
    If(($testWinlogBeat).Status -eq 'Running')                                                   # If yes...
    {
		Restart-Service winlogbeat
		$testWinlogBeat1 = Get-Service winlogbeat                                                # Check whether WinLogBeat service has restarted successfully
        if(($testWinlogBeat1).Status -eq 'Running')
        {
            Write-Verbose "WinLogBeat has restarted successfully"
            Write-InstallLog -logstring "$(Get-DTG) - WinLogBeat has been restarted successfully"
        } else {
            Write-Verbose "WinLogBeat has failed to restart successfully"
            Write-ErrorLog -logstring "$(Get-DTG) - WinLogBeat could not be started"             # WinLogBeat has failed to start, log it and exit script
            exit
        }
    } else {
        Write-Verbose "[Line 291]"
		ReStart-Service winlogbeat
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

Write-Host "WinLogBeat and Sysmon have been installed"
