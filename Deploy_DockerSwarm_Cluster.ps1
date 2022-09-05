[CmdletBinding()]
Param(
)
##################################################
#
#   DockerSwarm Cluster Deployment PS Script v0.1
#   Author: Michal Walewski
#
##################################################
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

####################################################
# Functions
####################################################

# Set-VMNodepool-Directory: To Create NodePool Dir For VM Disks
function Set-VMNodepool-Directory  
{
    PARAM
    (
        [string]$sVM_NewNodePool_Dir=$(throw "Parameter: sVM_NodePool_Dir Required!!")
    ) #End:Param

    #Create NodePool Dir
    try {
        mkdir $sVM_NewNodePool_Dir -ErrorAction Stop -ErrorVariable SearchError
        Write-Host "[SUCCESS] $sVM_NewNodePool_Dir directory created.`r" -ForegroundColor Green        
    }
    catch {
        Write-Host "[FAILED] to create $sVM_NewNodePool_Dir directory.`r" -ForegroundColor Red
        Write-Verbose "[FAILED] Error: $SearchError`r"
        Exit
    }

}

# New-VM-NetworkAdapter-Create: To Create TAP Virtual Network Adapter
function New-VM-NetworkAdapter-Create   
{
    try {
        & "C:\Program Files\TAP-Windows\bin\tapinstall.exe" install "C:\Program Files\TAP-Windows\driver\OemVista.inf" tap0901 -ErrorAction Stop -ErrorVariable SearchError
        Write-Host "[SUCCESS] Tap Virtual Network Adapter installed successfully.`r" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAILED] Tap Virtual Network Adapter installation FAILED.`r" -ForegroundColor Red
        Write-Verbose "[FAILED] Error: $SearchError`r"
        Exit
    }  
}

# Set-VM-NewNetworkAdapter-Name: Rename Network Adapter Default Name
function Set-VM-NewNetworkAdapter-Name   
{
    PARAM
    (
        [string]$sOldAdapter_Name=$(throw "Parameter: sOldAdapter_Name Required!!"),
        [string]$sNewAdapter_Name=$(throw "Parameter: sNewAdapter_Name Required!!")
    ) #End:Param

    Write-Debug "sOldAdapter_Name: $sOldAdapter_Name`r"
    Write-Debug "sNewAdapter_Name: $sNewAdapter_Name`r"

    try {
        Rename-NetAdapter -Name $sOldAdapter_Name -NewName $sNewAdapter_Name -ErrorAction Stop -ErrorVariable SearchError
        Write-Host "[SUCCESS] Tap Virtual Network Adapter renamed successfully.`r" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAILED] Tap Virtual Network Adapter rename FAILED.`r" -ForegroundColor Red
        Write-Verbose "[FAILED] Error: $SearchError`r"
        Exit
    }  
}


# New-VM-OSDisk-Create: To Copy VM Image From Existing VM Image Template
function New-VM-OSDisk-Create  
{
    PARAM
    (
        [string]$sVM_NewNodePool_Dir=$(throw "Parameter: sVM_NodePool_Dir Required!!"),
        [string]$sVM_Template_Path=$(throw "Parameter: sVM_Template_Path Required!!"),
        [string]$sVM_Template_Name=$(throw "Parameter: sVM_Template_Name Required!!"),
        [string]$sNodeType=$(throw "Parameter: sNodeType!!"),
        [int]$iVM_Number=$(throw "Parameter: iVM_Number Required!!")

    ) #End:Param


    Write-Debug "sVM_NodePool_Dir: $sVM_NewNodePool_Dir`r"
    Write-Debug "sVM_Template_Path: $sVM_Template_Path`r"
    Write-Debug "sVM_Template_Name: $sVM_Template_Name`r"
    Write-Debug "iVM_Number: $iVM_Number`r"

    #Copy Template Image & Create New VM Disk Image
    
    try {
            Copy-Item "$sVM_Template_Path\$sVM_Template_Name" "$sVM_NewNodePool_Dir" -ErrorAction Stop -ErrorVariable SearchError
            Write-Host "[SUCCESS] $sVM_Template_Name copied to directory $sVM_NewNodePool_Dir .`r" -ForegroundColor Green
        }
    catch{
            Write-Host "[FAILED] to copy $sVM_Template_Name to directory $sVM_NewNodePool_Dir .`r" -ForegroundColor Red
            Write-Verbose "[FAILED] Error: $SearchError`r"
            Exit
        }
    
            
    
    try { 
            $New_VM_Name="vm-$sNodeType$iVM_Number.img"
            Rename-Item "$sVM_NewNodePool_Dir\$sVM_Template_Name" "$sVM_NewNodePool_Dir\$New_VM_Name" -ErrorAction Stop -ErrorVariable SearchError
            Write-Host "[SUCCESS] Renamed vm image from $sVM_Template_Name to $New_VM_Name.`r" -ForegroundColor Green
        }
    catch{
            Write-Host "[FAILED] to create $New_VM_Name VM Disk .`r" -ForegroundColor Red
            Write-Verbose "[FAILED] Error: $SearchError`r"
            Exit
        }

}
# New-VM-Server-Deploy: Create New Virtual Servers
function New-VM-Server-Deploy 
{
    PARAM
    (
        [int]$iNumber_Of_Servers=$(throw "Parameter: iNumber_Of_Servers Required!!"),
        [string]$sVM_NewNodePool_Dir=$(throw "Parameter: sVM_NodePool_Dir Required!!"),
        [string]$sVM_Template_Path=$(throw "Parameter: sVM_Template_Path Required!!"),
        [string]$sVM_Template_Name=$(throw "Parameter: sVM_Template_Name Required!!"),
        [string]$sNodeType=$(throw "Parameter: sNodeType!!"),
        [int]$iAdapterNumberRange=$(throw "Parameter: iAdapterNumberRange Required!!")

    ) #End:Param
    Write-Debug "iNumber_Of_Servers: $iNumber_Of_Servers`r"    
    Write-Debug "sVM_NodePool_Dir: $sVM_NewNodePool_Dir`r"
    Write-Debug "sVM_Template_Path: $sVM_Template_Path`r"
    Write-Debug "sVM_Template_Name: $sVM_Template_Name`r"
    Write-Debug "sNodeType: $sNodeType`r"
    Write-Debug "iAdapterNumberRange: $iAdapterNumberRange`r"

    $iProgress=100/$iNumber_Of_Servers
    for($iNum=1;$iNum -le $iNumber_Of_Servers;$iNum++)
    {   
        # TODO: Progressbar
        #Write-Progress -Activity "Virtual Server Deployment in Progress" -Status "$iProgress% Complete:" -PercentComplete $iProgress

        Write-Host "[SETTING] Creating OSDisk VM-$sNodeType$iNum.img`r" -ForegroundColor Green
        
        New-VM-OSDisk-Create $sVM_NewNodePool_Dir $sVM_Template_Path $sVM_Template_Name $sNodeType $iNum
        
        $AdapterNumber=$iAdapterNumberRange+$iNum

        Write-Host "[SETTING] Deploying Tap Adapter vEth-$sNodeType$AdapterNumber`r" -ForegroundColor Green
        $CurrentAdaptersList=(Get-NetAdapter).name
        
        New-VM-NetworkAdapter-Create 

        $NewAdaptersList=(Get-NetAdapter).name

        $TAPAdapterName=Compare-Object -ReferenceObject $CurrentAdaptersList -DifferenceObject $NewAdaptersList -PassThru
            
        Set-VM-NewNetworkAdapter-Name $TAPAdapterName "vEth-$sNodeType$AdapterNumber"
        $iProgress=$iProgress*$iNum
    }
}

# New-DockerSwarm-Create: Configure Docker and Initialize DockerSwarm and First Manager Node
function New-DockerSwarm-Create
{
    PARAM
    (
        [string]$sVM_NewNodePool_Dir=$(throw "Parameter: sVM_NodePool_Dir Required!!"),
        [string]$sNodeType=$(throw "Parameter: sNodeType Required!!"),
        [string]$sVM_Template_Network_Subnet=$(throw "Parameter: sVM_Template_Name Required!!"),
        [string]$sVM_Template_IP=$(throw "Parameter: sVM_Template_IP Required!!"),
        [string]$sVM_New_Network_Subnet=$(throw "Parameter: sVM_New_Network_Subnet Required!!"),
        [int]$iAdapterNumberRangeManager=$(throw "Parameter: iAdapterNumberRangeManager Required!!"),
        [int]$iVM_Number=$(throw "Parameter: iVM_Number Required!!")

    ) #End:Param
    
    #New VM IP
    [int]$iIP_Last_Octet=$iAdapterNumberRangeManager+$iVM_Number
    
    $sVM_New_IP=$sVM_New_Network_Subnet+$iIP_Last_Octet

    Write-Debug "sVM_NodePool_Dir: $sVM_NewNodePool_Dir`r"
    Write-Debug "sNodeType: $sNodeType`r"
    Write-Debug "sVM_Template_Network_Subnet: $sVM_Template_Network_Subnet`r"
    Write-Debug "sVM_Template_IP: $sVM_Template_IP`r"
    Write-Debug "sVM_New_Network_Subnet: $sVM_New_Network_Subnet`r"
    Write-Debug "sVM_New_IP: $sVM_New_IP`r"
    Write-Debug "iAdapterNumberRangeManager: $iAdapterNumberRangeManager`r"
    Write-Debug "iVM_Number: $iVM_Number`r"

    Write-Host "[START] Powering on VM: vm-$sNodeType$iVM_Number`r" -ForegroundColor Green
    Write-Verbose "[SETTING] Adding vm-$sNodeType$iVM_Number to start script.`r"
    Write-Output "Start-Process 'C:\Program Files\qemu\qemu-system-x86_64.exe' -ArgumentList `"-hda $sVM_NewNodePool_Dir\vm-$sNodeType$iVM_Number.img -m 512 -machine type=q35 -device intel-iommu,intremap=on -smp 1,cores=1,threads=1,sockets=1 -netdev tap,id=mynet0,ifname=vEth-$sNodeType$iIP_Last_Octet -net nic,model=e1000,netdev=mynet0,macaddr=52:55:00:d1:55:$iIP_Last_Octet -vga std -boot strict=on -accel hax `" -WindowStyle Minimized" >> $sVM_NewNodePool_Dir\Start_VMs.ps1
    Start-Process 'C:\Program Files\qemu\qemu-system-x86_64.exe' -ArgumentList "-hda $sVM_NewNodePool_Dir\vm-$sNodeType$iVM_Number.img -m 512 -machine type=q35 -device intel-iommu,intremap=on -smp 1,cores=1,threads=1,sockets=1 -netdev tap,id=mynet0,ifname=vEth-$sNodeType$iIP_Last_Octet -net nic,model=e1000,netdev=mynet0,macaddr=52:55:00:d1:55:$iIP_Last_Octet -vga std -boot strict=on -accel hax " -WindowStyle Minimized
    
    #Verify current IP 
    Write-Host "[SETTING] Configuring vm-$sNodeType$iVM_Number`r" -ForegroundColor Green
    Write-Verbose "[CHECK] Network Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "cat /etc/network/interfaces"
    
    #Update Network Subnet
    Write-Verbose "[SETTING] Configuring Network Subnet`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "sed -i 's/$sVM_Template_Network_Subnet/$sVM_New_Network_Subnet/g' /etc/network/interfaces"
    
    #Update VM IP Address
    Write-Verbose "[SETTING] Configuring IP Address`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "sed -i 's/$sVM_Template_IP/$sVM_New_IP/g' /etc/network/interfaces"
    
    #Verify new VM IP Address
    Write-Verbose "[CHECK] Network Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "cat /etc/network/interfaces"
    
    #Verify current Hostname
    Write-Verbose "[CHECK] Hostname Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "cat /etc/hostname"

    #Update VM Hostname
    Write-Verbose "[SETTING] Updating Hostname`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "sed -i 's/alpine01/vm-$sNodeType$iVM_Number/g' /etc/hostname"

    #Reboot
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "reboot"
    
    Write-Verbose "[CHECK] Waiting for VM to reboot.`r"
    
    Start-Sleep 30

    #Verify current Hostname
    Write-Verbose "[CHECK] Hostname Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "cat /etc/hostname"

    # Docker setup
    Write-Host "[SETTING] Deploying Docker`r" -ForegroundColor Green
    Write-Verbose "[SETTING] Package Manager Update & Docker Deployment`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "apk update && apk add docker && service docker start && rc-update add docker boot && reboot"
    
    Write-Verbose "[CHECK] Waiting for VM to reboot.`r"
    Start-Sleep 30

    # Docker Verification
    Write-Verbose "[CHECK] Docker Details`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "docker ps && docker info"

    # Docker initialize Docker Swarm mode
    Write-Verbose "[SETTING] Initialize Docker Swarm`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "docker swarm init --advertise-addr $sVM_New_IP"
    
    Write-Host "[COMPLETE] vm-$sNodeType$iVM_Number Configuration & Deployment Finished.`r" -ForegroundColor Green
}

# Set-DockerNode-Type: Configure Docker Worker or Manager Node
function Set-DockerNode-Type
{
    PARAM
    (
        [string]$sVM_NewNodePool_Dir=$(throw "Parameter: sVM_NodePool_Dir Required!!"),
        [string]$sNodeType=$(throw "Parameter: sNodeType Required!!"),
        [string]$sVM_Template_Network_Subnet=$(throw "Parameter: sVM_Template_Name Required!!"),
        [string]$sVM_Template_IP=$(throw "Parameter: sVM_Template_IP Required!!"),
        [string]$sVM_New_Network_Subnet=$(throw "Parameter: sVM_New_Network_Subnet Required!!"),
        [int]$iAdapterNumberRange=$(throw "Parameter: iAdapterNumberRangeWorker Required!!"),
        [int]$iAdapterNumberRangeManager=$(throw "Parameter: iAdapterNumberRangeManager Required!!"),
        [int]$iVM_Number=$(throw "Parameter: iVM_Number Required!!")

    ) #End:Param

    #New VM IP
    [int]$iIP_Last_Octet=$iAdapterNumberRange+$iVM_Number
    $sVM_New_IP=$sVM_New_Network_Subnet+$iIP_Last_Octet

    Write-Debug "sVM_NodePool_Dir: $sVM_NewNodePool_Dir`r"
    Write-Debug "sNodeType: $sNodeType`r"
    Write-Debug "sVM_Template_Network_Subnet: $sVM_Template_Network_Subnet`r"
    Write-Debug "sVM_Template_IP: $sVM_Template_IP`r"
    Write-Debug "sVM_New_Network_Subnet: $sVM_New_Network_Subnet`r"
    Write-Debug "iAdapterNumberRange: $iAdapterNumberRange`r"
    Write-Debug "iAdapterNumberRangeManager: $iAdapterNumberRangeManager`r"
    Write-Debug "sVM_New_IP: $sVM_New_IP`r"
    Write-Debug "iVM_Number: $iVM_Number`r"

    Write-Host "[START] Powering on VM: vm-$sNodeType$iVM_Number`r" -ForegroundColor Green
    Write-Verbose "[SETTING] Adding vm-$sNodeType$iVM_Number to start script.`r"
    Write-Output "Start-Process 'C:\Program Files\qemu\qemu-system-x86_64.exe' -ArgumentList `"-hda $sVM_NewNodePool_Dir\vm-$sNodeType$iVM_Number.img -m 512 -machine type=q35 -device intel-iommu,intremap=on -smp 1,cores=1,threads=1,sockets=1 -netdev tap,id=mynet0,ifname=vEth-$sNodeType$iIP_Last_Octet -net nic,model=e1000,netdev=mynet0,macaddr=52:55:00:d1:55:$iIP_Last_Octet -vga std -boot strict=on -accel hax `" -WindowStyle Minimized" >> $sVM_NewNodePool_Dir\Start_VMs.ps1
    Start-Process 'C:\Program Files\qemu\qemu-system-x86_64.exe' -ArgumentList "-hda $sVM_NewNodePool_Dir\vm-$sNodeType$iVM_Number.img -m 512 -machine type=q35 -device intel-iommu,intremap=on -smp 1,cores=1,threads=1,sockets=1 -netdev tap,id=mynet0,ifname=vEth-$sNodeType$iIP_Last_Octet -net nic,model=e1000,netdev=mynet0,macaddr=52:55:00:d1:55:$iIP_Last_Octet -vga std -boot strict=on -accel hax " -WindowStyle Minimized
    
    #Verify current IP 
    Write-Host "[SETTING] Configuring vm-$sNodeType$iVM_Number`r" -ForegroundColor Green
    Write-Verbose "[CHECK] Network Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "cat /etc/network/interfaces"
    
    #Update Network Subnet
    Write-Verbose "[SETTING] Configuring Network Subnet`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "sed -i 's/$sVM_Template_Network_Subnet/$sVM_New_Network_Subnet/g' /etc/network/interfaces"
    
    #Update VM IP Address
    Write-Verbose "[SETTING] Configuring IP Address`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "sed -i 's/$sVM_Template_IP/$sVM_New_IP/g' /etc/network/interfaces"
    
    #Verify new VM IP Address
    Write-Verbose "[CHECK] Network Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "cat /etc/network/interfaces"
    
    #Verify current Hostname
    Write-Verbose "[CHECK] Hostname Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "cat /etc/hostname"

    #Update VM Hostname
    Write-Verbose "[SETTING] Updating Hostname`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "sed -i 's/alpine01/vm-$sNodeType$iVM_Number/g' /etc/hostname"

    #Reboot
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_Template_IP -t "reboot"

    Write-Verbose "[CHECK] Waiting for VM to reboot.`r"
    Start-Sleep 30
    
    #Verify current Hostname
    Write-Verbose "[CHECK] Hostname Details:`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "cat /etc/hostname"

    # Docker setup
    Write-Host "[SETTING] Deploying Docker`r" -ForegroundColor Green
    Write-Verbose "[SETTING] Package Manager Update & Docker Deployment`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "apk update && apk add docker && service docker start && rc-update add docker boot && reboot"
    
    Write-Verbose "[CHECK] Waiting for VM to reboot.`r"
    Start-Sleep 30
    
    # Docker Verification
    Write-Verbose "[CHECK] Docker Details`r"
    ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "docker ps && docker info"

    # Join Docker Swarm as Worker node
    Write-Verbose "[SETTING] Joining node to Docker Swarm`r"
    [int]$iIP_Manager_Node_Last_Octet=$iAdapterNumberRangeManager+1
    $sManager_Node_IP=$sVM_New_Network_Subnet+$iIP_Manager_Node_Last_Octet
    
    # 3 Attempts in case swarm leader is busy
    for ($iAttempt = 1; $iAttempt -lt 3; $iAttempt++) {
        
        $sJoinDockerSwarmCMD=ssh -o StrictHostKeyChecking=accept-new root@$sManager_Node_IP -t "docker swarm join-token $sNodeType|grep docker"
        ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "$sJoinDockerSwarmCMD" | Out-Null  

        Write-Verbose "[CHECK] Verifying DockerSwarm connection`r"
        Start-Sleep 10
        #Verify if node was successfully connected
        $sJoinDockerSwarmResult=ssh -o StrictHostKeyChecking=accept-new root@$sManager_Node_IP -t "docker node ls|grep vm-$sNodeType$iVM_Number"
        Write-Verbose "sJoinDockerSwarmResult: $sJoinDockerSwarmResult`r"

        if ($sJoinDockerSwarmResult|findstr "vm-$sNodeType$iVM_Number") {
            Write-Verbose "[SUCCESS] vm-$sNodeType$iVM_Number joined Docker Swarm successfully at $iAttempt attempt.`r"
            break
        }
        elseif($sJoinDockerSwarmResult|findstr "too few managers are online")
        {
            Write-Verbose "[FAILED] vm-$sNodeType$iVM_Number failed to join Docker Swarm at $iAttempt attempt.`r"
            Write-Verbose "[ERROR] Manager node not responding.`r"
            Write-Verbose "[CHECK] Rebooting manager node.`r"
            ssh -o StrictHostKeyChecking=accept-new root@$sVM_New_IP -t "reboot"
            Start-Sleep 30
            
        }
        else {
            Write-Verbose "[FAILED] vm-$sNodeType$iVM_Number failed to join Docker Swarm at $iAttempt attempt.`r"
        }
    }
    
    if ($sNodeType -like "worker") {
        Write-Verbose "[SETTING] Applying Node Label`r"
        ssh -o StrictHostKeyChecking=accept-new root@$sManager_Node_IP -t "docker node update --label-add application=yes vm-$sNodeType$iVM_Number"
    }

    Write-Host "[COMPLETE] vm-$sNodeType$iVM_Number Configuration & Deployment Finished.`r" -ForegroundColor Green

}

####################################################
# Main Deployment Script
####################################################

Clear-Host

$sVM_NewNodePool_Dir="c:\nodepool"
$sVM_Template_Path="C:\vms"
$sVM_Template_Name="linux_alpine_template.img"
$sVM_Template_Network_Subnet="192.168.1."
$sVM_Template_IP="192.168.1.250"
$sVM_New_Network_Subnet="192.168.1."
$iAdapterNumberRangeManager=50
$iAdapterNumberRangeWorker=60
#$NumOfNodes=Read-Host("Enter number of VMs to deploy")
$NumOfManagerNodes=3
$NumOfWorkerNodes=5

Write-Debug "NumOfManagerNodes: $NumOfManagerNodes`r"
Write-Debug "NumOfWorkerNodes: $NumOfWorkerNodes`r"

Set-VMNodepool-Directory $sVM_NewNodePool_Dir

#######################
# Deployment Phase
#######################

# Managers Docker nodes
New-VM-Server-Deploy $NumOfManagerNodes $sVM_NewNodePool_Dir $sVM_Template_Path $sVM_Template_Name "manager" $iAdapterNumberRangeManager

# Workers Docker nodes
New-VM-Server-Deploy $NumOfWorkerNodes $sVM_NewNodePool_Dir $sVM_Template_Path $sVM_Template_Name "worker" $iAdapterNumberRangeWorker

Write-Host "Full List of all new adapters adapters:`r"

((Get-NetAdapter).Name | findstr vEth)

Write-Host "Refreshing Network Adapters List...`r" -ForegroundColor Green
Start-Sleep 3
Write-Host "Opening Network Connections Graphic Interface..`r" -ForegroundColor Green
Start-Sleep 1
Write-Host "Please add vEth6X connections to the bridge..`r" -ForegroundColor Green

C:\Windows\System32\ncpa.cpl

Pause

#######################
# Post Deployment 
#######################

# Create DockerSwarm Cluster
New-DockerSwarm-Create $sVM_NewNodePool_Dir "manager" $sVM_Template_Network_Subnet $sVM_Template_IP $sVM_New_Network_Subnet $iAdapterNumberRangeManager 1

# Start building manager nodes
for($iNum=2;$iNum -le $NumOfManagerNodes;$iNum++)
{   
    Set-DockerNode-Type $sVM_NewNodePool_Dir "manager" $sVM_Template_Network_Subnet $sVM_Template_IP $sVM_New_Network_Subnet $iAdapterNumberRangeManager $iAdapterNumberRangeManager $iNum
}

# Start deploying worker nodes
for($iNum=1;$iNum -le $NumOfWorkerNodes;$iNum++)
{   
    Set-DockerNode-Type $sVM_NewNodePool_Dir "worker" $sVM_Template_Network_Subnet $sVM_Template_IP $sVM_New_Network_Subnet $iAdapterNumberRangeWorker $iAdapterNumberRangeManager $iNum
}
