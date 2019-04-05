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
    Start-Transcript -Path "$PSScriptRoot\Prereq_Additional.log"
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

#region folder build
# Checking Folder Structure
    "Temp\ToolsVHD\Scripts","Temp\ToolsVHD\SCCM","Temp\ToolsVHD\SCCMPrereqs" | ForEach-Object {
        if (!( Test-Path "$PSScriptRoot\$_" )) { New-Item -Type Directory -Path "$PSScriptRoot\$_" } }

    "Temp\ToolsVHD\SCCM\Copy_SCCM_install_here.txt","Temp\ToolsVHD\SCCMPrereqs\Copy_SCCMPrereqs_here.txt" | ForEach-Object {
        if (!( Test-Path "$PSScriptRoot\$_" )) { New-Item -Type File -Path "$PSScriptRoot\$_" } }
#endregion folder build

#region Download Scripts
$Filenames="Install-TAFirst2008R2DomainController","Set-StaticIPAddressUsingWMI"
foreach ($Filename in $filenames){
    $Path="$PSScriptRoot\Temp\ToolsVHD\Scripts\$Filename.ps1"
    If (Test-Path -Path $Path){
        WriteSuccess "`t $Filename is present, skipping download"
    }else{
        $FileContent=$null
        $FileContent = (Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/mcpjanmarek/WSLab-Additions/master/Tools/$Filename.ps1").Content
        if ($FileContent){
            $script = New-Item "$PSScriptRoot\Temp\ToolsVHD\Scripts\$Filename.ps1" -type File -Force
            Set-Content -path $script -value $FileContent
        }else{
            WriteErrorAndExit "Unable to download $Filename."
        }
    }
}

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
        # Unnzipping and extracting
            Expand-Archive "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\SysinternalsSuite.zip" -DestinationPath "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\Unzip"
            Copy-Item -Path (Get-ChildItem -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\Unzip" -Recurse).fullname -Destination "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\"
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\SysinternalsSuite.zip"
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\SysinternalsSuite\Unzip" -Recurse -Force
    }

# Downloading Kansa if its not in ToolsVHD folder
    WriteInfoHighlighted "Testing Kansa presence"
    If ( Test-Path -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa\Kansa.ps1" ) {
        WriteSuccess "`t Kansa is present, skipping download"
    }else{ 
        WriteInfo "`t Kansa not there - Downloading Kansa"
        New-Item -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        try {
            $downloadurl = 'https://github.com/davehull/Kansa/archive/master.zip'
            Invoke-WebRequest -Uri $downloadurl -OutFile "$PSScriptRoot\Temp\ToolsVHD\Kansa\Kansa-master.zip"
        }catch{
            WriteError "`t Failed to download Kansa!"
        }
        # Unnzipping and extracting
            Expand-Archive "$PSScriptRoot\Temp\ToolsVHD\Kansa\Kansa-master.zip" -DestinationPath "$PSScriptRoot\Temp\ToolsVHD\Kansa\Unzip"
            Copy-Item -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa\Unzip\Kansa-master\*" -Recurse  -Destination "$PSScriptRoot\Temp\ToolsVHD\Kansa\" -Force
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa\Kansa-master.zip"
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa\Unzip" -Recurse -Force
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa" -Recurse -Include "*.md" -Force
            Remove-Item -Path "$PSScriptRoot\Temp\ToolsVHD\Kansa\.gitignore" -Recurse -Force
    }


    
#endregion

# finishing 
WriteInfo "Script finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"
Stop-Transcript
WriteSuccess "Press enter to continue..."
Read-Host | Out-Null
