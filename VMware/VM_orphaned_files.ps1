#Copyright (C) 2018 Max Wimmelbacher
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
$OrphanedFiles = @()
If ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PSSnapin VMware.VimAutomation.Core
}
Connect-VIServer -Server $VMwarevCenter -Credential $Credential
$VMs = Get-VM
$UsedDisks = $VMs | Get-HardDisk | %{$_.FileName}
Foreach ($VM in $VMs)
{
    $CurrentSnapshot = $VM | Get-Snapshot | Where-Object { $_.IsCurrent -eq $True }
    If ($CurrentSnapshot.Count -ne 0)
    {
        $UsedDisks += ($VM.ExtensionData.Layout.Snapshot | Where-Object {$_.Key -eq $CurrentSnapshot.ExtensionData.Snapshot}).SnapshotFile | Where-Object {$_.Contains(".vmdk")}
    }
}
$UsedDisks += Get-Template | Get-HardDisk | %{$_.FileName}
Write-Output "Number of valid VMDKs known to vCenter Server discovered: $($UsedDisks.Count)"
$Datastores = Get-Datastore
Foreach ($Datastore in $Datastores)
{
    Write-Output "Processing Datastore: $($Datastore)"
    $DatastoreInfo = Get-View $Datastore.Id
    $FileQueryFlags = New-Object VMware.Vim.FileQueryFlags
    $FileQueryFlags.FileSize = $true
    $FileQueryFlags.FileType = $true
    $FileQueryFlags.Modification = $true
    $HostDatastoreBrowserSearchSpec= New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $HostDatastoreBrowserSearchSpec.Details = $FileQueryFlags
    $HostDatastoreBrowserSearchSpec.SortFoldersFirst = $true   
    $HostDatastoreBrowser = Get-View $DatastoreInfo.Browser
    $DatastoreRootPath = "[" + $DatastoreInfo.Summary.Name + "]"
    $DatestoreSearchResult = $HostDatastoreBrowser.SearchDatastoreSubFolders($DatastoreRootPath, $HostDatastoreBrowserSearchSpec)
    Foreach ($Folder in $DatestoreSearchResult)
    {
        Write-Output "Processing Folder: $($Folder.Folderpath)"
        Foreach ($File in $Folder.File)
        {
            $FileObject = "" | Select Name, FullPath, SizeInGB
            $FileObject.Name = $File.Path
            $FileObject.FullPath = $Folder.Folderpath + $File.Path
            $FileObject.SizeInGB = [math]::Round($File.FileSize / 1GB)
            If ($FileObject.Name)
            {
                If ($FileObject.Name.Contains(".vmdk")) 
                {
                    If ((!$FileObject.Name.Contains("-ctk.vmdk")) -and (!$FileObject.Name.Contains("-flat.vmdk")) -and (!$FileObject.Name.Contains("-delta.vmdk")))
                    {
                        $FileNameToCheck = "*" + $FileObject.Name + "*"
                        If ($UsedDisks -Like $FileNameToCheck)
                        {
                        }
                        Else 
                        {
                            $OrphanedFiles += $FileObject
                        }
                    }
                }
            }
        }
    }
}
$OrphanedFiles = $OrphanedFiles | Sort-Object -Property Name, FullPath
$OrphanedFiles | ConvertTo-HTML | Out-File .\VM_orphaned_files.htm
Disconnect-VIServer $VMwarevCenter -Confirm:$False
