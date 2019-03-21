# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
    Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
    exit
}

# Skipping 10 lines because if running when all prereqs met, statusbar covers powershell output
1..10 |% { Write-Host ""}

#region Functions

function WriteInfo($message){
        Write-Host $message
    }

function WriteInfoHighlighted($message){
    Write-Host $message -ForegroundColor Cyan
}

function WriteSuccess($message){
    Write-Host $message -ForegroundColor Green
}

function WriteError($message){
    Write-Host $message -ForegroundColor Red
}

function WriteErrorAndExit($message){
    Write-Host $message -ForegroundColor Red
    Write-Host "Press enter to continue ..."
    Stop-Transcript
    Read-Host | Out-Null
    Exit
}

function  Get-WindowsBuildNumber { 
    $os = Get-WmiObject -Class Win32_OperatingSystem 
    return [int]($os.BuildNumber) 
} 

#endregion

#region Initializtion

# grab Time and start Transcript
    Start-Transcript -Path "$PSScriptRoot\Prereq-Additional.log"
    $StartDateTime = get-date
    WriteInfo "Script started at $StartDateTime"

#Load LabConfig....
    . "$PSScriptRoot\LabConfig.ps1"

#define some variables if it does not exist in labconfig
    If (!$LabConfig.DomainNetbiosName){
        $LabConfig.DomainNetbiosName="Corp"
    }

    If (!$LabConfig.DomainName){
        $LabConfig.DomainName="Corp.contoso.com"
    }

#set TLS 1.2 for github downloads
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#endregion

#region Download Scripts

<#region TODO
#add scripts for SCCM?
    $Filenames="1_SQL_Install","2_ADK_Install","3_SCVMM_Install"
    foreach ($Filename in $filenames){
        $Path="$PSScriptRoot\Temp\ToolsVHD\SCVMM\$Filename.ps1"
        If (Test-Path -Path $Path){
            WriteSuccess "`t $Filename is present, skipping download"
        }else{
            $FileContent=$null
            $FileContent = (Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/Microsoft/WSLab/master/Tools/$Filename.ps1").Content
            if ($FileContent){
                $script = New-Item $Path -type File -Force
                $FileContent=$FileContent -replace "PasswordGoesHere",$LabConfig.AdminPassword #only applies to 1_SQL_Install and 3_SCVMM_Install.ps1
                $FileContent=$FileContent -replace "DomainNameGoesHere",$LabConfig.DomainNetbiosName #only applies to 1_SQL_Install and 3_SCVMM_Install.ps1
                Set-Content -path $script -value $FileContent
            }else{
                WriteErrorAndExit "Unable to download $Filename."
            }
        }
    }
#>

#endregion

#region some tools to download
# Downloading sysinternals if its not in ToolsVHD folder
    WriteInfoHighlighted "Testing SysinternalsSuite presence"
    If ( Test-Path -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\accesschk.exe" ) {
        WriteSuccess "`t AccessChk is present, skipping download"
    }else{ 
        WriteInfo "`t AccessChk not there - Downloading SysinternalsSuite"
        New-Item -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        try {
            $downloadurl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
            Invoke-WebRequest -Uri $downloadurl -OutFile "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\SysinternalsSuite.zip"
        }catch{
            WriteError "`t Failed to download SysinternalsSuite!"
        }
        # Unnzipping and extracting just diskspd.exe x64
            Expand-Archive "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\SysinternalsSuite.zip" -DestinationPath "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\Unzip"
            Copy-Item -Path (Get-ChildItem -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\Unzip" -Recurse).fullname -Destination "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\"
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\SysinternalsSuite.zip"
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\Unzip" -Recurse -Force
    }
#endregion

# finishing 
WriteInfo "Script finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"
Stop-Transcript
WriteSuccess "Press enter to continue..."
Read-Host | Out-Null
