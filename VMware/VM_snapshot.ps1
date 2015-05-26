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

$VMwarevCenter = @(#Add comma separated vSphere vCenter names")
$SecuredCredentialsPlain = Get-Content("<PATH_TO_DOCUMENT_WITH_CREDENTIALS_AS_SECURESTRING>")
$SecuredCredentials = $SecuredCredentialsPlain | ConvertTo-Securestring
$Credential = New-Object System.Management.Automation.PSCredential -Argumentlist "<NAME_OF_LOCAL_ADMINISTRATOR>", $SecuredCredentials
$Snapshots = @()
If ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PSSnapin VMware.VimAutomation.Core
}
Connect-VIServer -Server $VMwarevCenter -Credential $Credential
$VMwareSnapshot = Get-VM | Get-Snapshot
ForEach ($VMSnapshot in $VMwareSnapshot)
{
    $Snapshot = "" | Select VirtualMachine, ActiveSnapshot, Description, "Size (GB)", Created
    $Snapshot.VirtualMachine = $VMSnapshot.VM
    $Snapshot.ActiveSnapshot = $VMSnapshot.IsCurrent
    $Snapshot.Description = $VMSnapshot.Name
    $Snapshot."Size (GB)" = [math]::Round($VMSnapshot.SizeGB)
    $Snapshot.Created = $VMSnapshot.Created
    $Snapshots += $Snapshot
}
$Snapshots = $Snapshots | Sort-Object -Property VirtualMachine, Created, ActiveSnapshot
$Snapshots | ConvertTo-HTML | Out-File ..\Shared\VM_snapshot.htm
Disconnect-VIServer $VMwarevCenter -Confirm:$False
