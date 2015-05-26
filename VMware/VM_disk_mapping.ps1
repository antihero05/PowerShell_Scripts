#Copyright (C) 2015 Max Wimmelbacher
#
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#!!!Install vSphere PowerCLI!!!

$VMwarevCenter = @(#Add comma separated vSphere vCenter names)
$VMwareVMs = @(#Add comma separated VM names)
$SecuredCredentialsPlain = Get-Content("<PATH_TO_DOCUMENT_WITH_CREDENTIALS_AS_SECURESTRING>")
$SecuredCredentials = $SecuredCredentialsPlain | ConvertTo-Securestring
$Credential = New-Object System.Management.Automation.PSCredential -Argumentlist "<NAME_OF_LOCAL_ADMINISTRATOR>", $SecuredCredentials
$MappedDisks = @()
If ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PSSnapin VMware.VimAutomation.Core
}
Connect-VIServer -Server $VMwarevCenter -Credential $Credential
$VMwareVM = Get-VM -Name $VMwareVMs | Where-Object {$_.PowerState -eq "PoweredOn"}
ForEach ($VM in $VMwareVM)
{
    $VMView = Get-View $VM    
    $WinRegistry = Get-WmiObject -List -Namespace root\default -ComputerName $VMView.Name -Credential $Credential | Where-Object {$_.Name -eq "StdRegProv"}
    $WinHardwareID = $WinRegistry.EnumKey(2147483650, "SYSTEM\CurrentControlSet\Enum\PCI")
    $WinSCSIController = Get-WmiObject -Class "Win32_SCSIControllerDevice" -ComputerName $VMView.Name -Credential $Credential
    $WinDisk = Get-WmiObject -Class "Win32_DiskDrive" -ComputerName $VMView.Name -Credential $Credential
    $PCISlots = @()
    ForEach ($HardwareID in $WinHardwareID.sNames)
    {
        $WinControllerID = $WinRegistry.EnumKey(2147483650, "SYSTEM\CurrentControlSet\Enum\PCI\$($HardwareID)")
        ForEach ($ControllerID in $WinControllerID.sNames)
        {
    	$PCISlot = "" | Select PNPDeviceID, PCISlotNumber
    	$PCISlot.PNPDeviceID = "PCI\$($HardwareID.ToUpper())\$($ControllerID.ToUpper())"
            $WinPCISlot = $WinRegistry.GetDWORDValue(2147483650, "SYSTEM\CurrentControlSet\Enum\PCI\$($HardwareID)\$($ControllerID)", "UINumber")
            $PCISlot.PCISlotNumber = $WinPCISlot.uValue
    	$PCISlots += $PCISlot
        }
    }
    $MappedDevices = @()
    ForEach ($Disk in $WinDisk)
    {
        ForEach ($SCSIController in $WinSCSIController)
        {
            $Device = $SCSIController.Dependent.Split("=")[1] -Replace "\\\\", "\"
            If ($Disk.PNPDeviceID -eq $Device.Substring(1, $Device.Length-2))
            {
                $MappedDevice = "" | Select DeviceID, PCISlotNumber, SCSITargetID 
                $MappedDevice.DeviceID = $Disk.DeviceID
    	        $Device = $SCSIController.Antecedent.Split("=")[1] -Replace "\\\\", "\"
                $Device = $Device.Substring(1, $Device.Length-2)
                $PCISlot = $PCISlots | Where-Object {$_.PNPDeviceID -eq $Device}
                $MappedDevice.PCISlotNumber = $PCISlot.PCISlotNumber
                $MappedDevice.SCSITargetID = $Disk.SCSITargetID
                $MappedDevices += $MappedDevice
            }
        }
    }
    ForEach ($VirtualSCSIController in ($VMView.Config.Hardware.Device | where {$_.GetType().BaseType.Name -eq "VirtualSCSIController"}))
    {
        ForEach ($VirtualDisk in ($VMView.Config.Hardware.Device | where {$_.GetType().Name -eq "VirtualDisk" -and $_.ControllerKey -eq $VirtualSCSIController.Key}))
        {
            $MappedDisk = "" | Select VirtualMachine, Device, SCSI, PCISlotNumber, "DiskSize (GB)", WindowsDisk
            $MappedDisk.VirtualMachine = $VMView.Name
            $MappedDisk.Device = $VirtualDisk.DeviceInfo.Label
            $MappedDisk.SCSI = "($($VirtualSCSIController.BusNumber):$($VirtualDisk.UnitNumber))"
            $PCISlotNumber = Get-AdvancedSetting -Entity $VM -Name "scsi$($VirtualSCSIController.BusNumber).pciSlotNumber"
            $MappedDisk.PCISlotNumber = [int]("$($PCISlotNumber)".Split(":")[1])
            While ($MappedDisk.PCISlotNumber -gt 1024)
            {
                $MappedDisk.PCISlotNumber = $MappedDisk.PCISlotNumber - 1023 
            } 
            $MappedDisk."DiskSize (GB)" = [math]::Round($VirtualDisk.CapacityInKB * 1KB / 1GB)
            $MatchedDisk = $MappedDevices | ?{($_.PCISlotNumber) -eq $MappedDisk.PCISlotNumber -and $_.SCSITargetID -eq $VirtualDisk.UnitNumber} 
            If ($MatchedDisk)
            {
                $MappedDisk.WindowsDisk = $MatchedDisk.DeviceID
            }
            Else
            {
                $MappedDisk.WindowsDisk = "No matching disk found!"
            }
            $MappedDisks += $MappedDisk 
        }
    }
}
$MappedDisks = $MappedDisks | Sort-Object -Property VirtualMachine, Device
$MappedDisks | ConvertTo-HTML | Out-File .\VM_disk_mapping.htm
Disconnect-VIServer $VMwarevCenter -Confirm:$False
