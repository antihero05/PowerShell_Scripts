#Copyright (C) 2016 Max Wimmelbacher 
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

#!!!Script needs EMC NetWorker to be installed on the machine executing the script and the executing user having sufficient permissions with EMC NetWorker!!! 
 
# Adjustable Parameters
$Quartal = 2
$NetWorkerMediaPoolsRetentionOneYear = "<SOURCE_MEDIA_POOL1>", "<SOURCE_MEDIA_POOL2>"
# End Adjustable Parameters
# Global Parameters
$global:NetWorkerServer = "<NETWORKER_SERVER_NAME>"
# End Global Parameters
# Functions
function Get-NetWorkerClients
{
    $GetClientsCommand= "show name`r`nprint type:NSR client"
    $TempFile = "$($env:TEMP)\GetClientsCommand.txt"
    Out-File -InputObject $Command -FilePath $TempFile -Encoding ascii
    $ClientsRaw = nsradmin -s $NetWorkerServer -i $TempFile
    $Clients = @()
    Foreach ($Client in $ClientsRaw)
    {
        If ($Client -match "name:*")
        {
            $Client = $Client -replace "name: ",""
            $Clients += $Client.Substring(0,$Client.Length-1)
        }
    }
    Return $Clients
}
function Get-NetWorkerFullSaveSets
{
    Param(
    [int]$Quartal,
    [string[]]$NetWorkerMediaPools
    )
    Switch ($Quartal)
    {
        1 {
            $SavedAfter = "12/31/$((Get-Date).Year-1)"
            $SavedBefore = "03/31/$((Get-Date).Year)"
          }
        2 {
            $SavedAfter = "03/31/$((Get-Date).Year)"
            $SavedBefore = "06/30/$((Get-Date).Year)"
          }
        3 {
            $SavedAfter = "06/30/$((Get-Date).Year)"
            $SavedBefore = "09/30/$((Get-Date).Year)"
          }
        4 {
            $SavedAfter = "09/30/$((Get-Date).Year-1)"
            $SavedBefore = "12/31/$((Get-Date).Year-1)"
          }
    }
    $SaveSetsRaw = @()
    Foreach ($NetWorkerMediaPool in $NetWorkerMediaPools)
    {
        $Argument = "`"level=full,pool=$($NetWorkerMediaPool),savetime>$($SavedAfter),savetime<$($SavedBefore)`""
        $SaveSetsRaw += mminfo -s $NetWorkerServer -a -q  $Argument -r "client,name,vmname,savetime,ssid,cloneid"
    }
    $SaveSets = @()
    Foreach ($SaveSetRaw in $SaveSetsRaw)
    {
        $SaveSet = "" | Select Client, SaveSet, SaveTime, SaveSetID, CloneID
        $Temp = $SaveSetRaw.Split(" ")
        If ($Temp.Count -eq 6)
            {
            Try
            {
                If ($Temp[2].Length -eq 0)
                {
                    $SaveSet.Client = $Temp[0]
                    $SaveSet.SaveSet = $Temp[1]
                }
                Else
                {
                    $SaveSet.Client = $Temp[2]
                    $SaveSet.SaveSet = "vm"
                }
                $SaveSet.SaveTime = Get-Date -Date $Temp[3]
                $SaveSet.SaveSetID = $Temp[4]
                $SaveSet.CloneID = $Temp[5]
            }
            Catch
            {
                "##Error Entry:" | Out-File -Append -FilePath "error.log"
                $Temp | Out-File -Append -FilePath "error.log"
            }
        }
        ElseIf ($Temp.Count -eq 9 -and $Temp[1] -eq "Windows")
        {
            Try
            {
                $SaveSet.Client = $Temp[0]
                $SaveSet.SaveSet = $Temp[1] + " " + $Temp[2] + " " + $Temp[3] + " " + $Temp[4]
                $SaveSet.SaveTime = Get-Date -Date $Temp[6]
                $SaveSet.SaveSetID = $Temp[7]
                $SaveSet.CloneID = $Temp[8]
            }
            Catch
            {
                "##Error Entry:" | Out-File -Append -FilePath "error.log"
                $Temp | Out-File -Append -FilePath "error.log"
            }
        }
        ElseIf ($Temp[0].Length -gt 0)
        {
            $TrimmedTemp = @()
            For ($Loop = 0; $Loop -lt $Temp.Count; $Loop++)
            {
                If ($Temp[$Loop].Length -gt 0)
                {
                    $TrimmedTemp += $Temp[$Loop]
                }
            }
            Try
            {
                $SaveSet.Client = $TrimmedTemp[0]
                $SaveSet.SaveSet = $TrimmedTemp[1]
                $SaveSet.SaveTime = Get-Date -Date $TrimmedTemp[2]
                $SaveSet.SaveSetID = $TrimmedTemp[3]
                $SaveSet.CloneID = $TrimmedTemp[4]
            }
            Catch
            {
                "##Error Entry:" | Out-File -Append -FilePath "error.log"
                $Temp | Out-File -Append -FilePath "error.log"
                $TrimmedTemp | Out-File -Append -FilePath "error.log"
            }
        }
        If ($SaveSet.Client.Length -gt 0 -and $SaveSet.SaveSet.Length -gt 0 -and $SaveSet.SaveTime.Length -gt 0 -and $SaveSet.SaveSetID.Length -gt 0 -and $SaveSet.CloneID.Length -gt 0)
        {
            $SaveSets += $SaveSet
        }
    }
    Return (Sort-Object -InputObject $SaveSets -Property Client,SaveSet,SaveTime -Descending)
}
Function Get-NetWorkerLatestSaveSets
{
    Param(
    [PSObject[]]$NetWorkerSaveSets
    )
    $BasicSaveSets = $NetWorkerSaveSets | Select-Object -Unique Client,SaveSet
    $FilteredSaveSets = @()
    Foreach ($BasicSaveSet in $BasicSaveSets)
    {
        $Temp = $NetWorkerSaveSets | Where-Object {$_.Client -eq $BasicSaveSet.Client -and $_.SaveSet -eq $BasicSaveSet.SaveSet}
        $Temp = $Temp | Sort-Object -Property SaveTime -Descending
        $FilteredSaveSets += $Temp | Select-Object -First 1
    }
    Return $FilteredSaveSets
}
Function Get-Retention
{
    Param(
    [int]$Quartal,
    [int]$Years
    )
    Switch ($Quartal)
    {
        1 {
            $Retention = "03/31/$((Get-Date).Year + $Years)"
          }
        2 {
            $Retention = "06/30/$((Get-Date).Year + $Years)"
          }
        3 {
            $Retention = "09/30/$((Get-Date).Year + $Years)"
          }
        4 {
            $Retention = "12/31/$((Get-Date).Year - 1 + $Years)"
          }
    }
    Return $Retention
}
Function Get-FormattedDate
{
    [string]$Year = (Get-Date).Year
    [string]$Month = (Get-Date).Month
    [string]$Day = (Get-Date).Day
    If ($Month.Length -eq 1)
    {
        $Month = "0" + $Month
    }
    If ($Day.Length -eq 1)
    {
        $Day = "0" + $Day
    }
    Return "$($Year)-$($Month)-$($Day)"
}
Function Clone-NetWorkerSaveSet
{
    Param(
    [decimal]$SaveSetID,
    [decimal]$CloneID,
    [string]$MediaPool,
    [string]$Retention,
    [string]$Browse
    )
    nsrclone -s $NetWorkerServer -b $MediaPool -y $Retention -w $Browse -S $SaveSetID/$CloneID 2>&1 | Out-File -Append -FilePath "status.log"
}
# End Functions
# Main()
If (-Not (Test-Path "workingset.csv"))
{
    $NetWorkerSaveSets = Get-NetWorkerFullSaveSets -Quartal $Quartal -NetWorkerMediaPools $NetWorkerMediaPoolsRetentionOneYear
    $NetWorkerSaveSetsWorkingSet = Get-NetWorkerLatestSaveSets -NetWorkerSaveSets $NetWorkerSaveSets
    $NetWorkerSaveSetsWorkingSet | ConvertTo-Csv | Out-File "workingset.csv"
    $NetWorkerSaveSetsWorkingSet | ConvertTo-Csv | Out-File "$(Get-FormattedDate)_cloningset.csv"
}
$NetWorkerSaveSets = Import-Csv "workingset.csv"
$NetWorkerSaveSetRetention = Get-Retention -Quartal $Quartal -Years 1
Write-Output "### Started cloning for tape backup at $(Get-Date)" | Out-File -Append -FilePath "status.log"
Foreach ($NetWorkerSaveSet in $NetWorkerSaveSets)
{
    Write-Output "$(Get-Date) - Cloning saveset $($NetWorkerSaveSet.SaveSet) backuped from client $($NetWorkerSaveSet.Client) with savesetid $($NetWorkerSaveSet.SaveSetID) and cloneid $($NetWorkerSaveSet.CloneID):" | Out-File -Append -FilePath "status.log"
    Clone-NetWorkerSaveSet -SaveSetID $NetWorkerSaveSet.SaveSetID -CloneID $NetWorkerSaveSet.CloneID -MediaPool "<CLONING_POOL_NAME>$($Quartal)" -Retention $NetWorkerSaveSetRetention -Browse $NetWorkerSaveSetRetention
    $NetWorkerSaveSetsWorkingSet = $NetWorkerSaveSetsWorkingSet[1..($NetWorkerSaveSetsWorkingSet.Length-1)]
    $NetWorkerSaveSetsWorkingSet | ConvertTo-Csv | Out-File "workingset.csv"
    Write-Output "$(Get-Date) - Finished cloning saveset $($NetWorkerSaveSet.SaveSet) backuped from client $($NetWorkerSaveSet.Client) with savesetid $($NetWorkerSaveSet.SaveSetID) and cloneid $($NetWorkerSaveSet.CloneID)." | Out-File -Append -FilePath "status.log"
}
Write-Output "### Finished all cloning jobs for tape backup at $(Get-Date)" | Out-File -Append -FilePath "status.log"
Remove-Item "workingset.csv"
Rename-Item -Path "status.log" -NewName "$(Get-FormattedDate)_status.log"
#End Main()
