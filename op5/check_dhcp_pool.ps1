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

$Warning=90
$Critical=95
$OutIPv4Scopes = @()
$OutIPv4Text = ""
$OutIPv4Perfdata = ""
$OutIPv4Code = 0
Try
{
    Get-DhcpServerv4ScopeStatistics  | ForEach-Object {
        If ((Get-DhcpServerv4Scope -ScopeId $_.ScopeId).State -eq "Active")
        {
            $OutIpv4Scope = "" | Select ScopeId, IPFree, IPFreePercentage, IPUsed, IPUsedPercentage
            $OutIpv4Scope.IPFree = [int]$_.Free
            $OutIpv4Scope.IPUsed = [int]$_.InUse
            $OutIPv4Scope.IPUsedPercentage = [double]$_.PercentageInUse
            $OutIPv4Scope.IPFreePercentage = (100 - [double]$_.PercentageInUse)
            $IPv4ScopeId = [string]$_.ScopeId
            $IPv4Scope = Get-DhcpServerv4Scope -ScopeId $IPv4ScopeId
            $IPv4Subnet = 0
            (($IPv4Scope.SubnetMask -split '\.' | % { [convert]::ToString($_,2) } ) -join '').tochararray() | % { $IPv4Subnet += ([convert]::ToInt32($_)-48)}
            $OutIpv4Scope.ScopeId = $IPv4ScopeId + '/' + $IPv4Subnet
            If ($OutIPv4Code -lt 1 -and $OutIPv4Scope.IPUsedPercentage -gt $Warning)
            {
                $OutIPv4Code = 1
            }
            If ($OutIPv4Code -lt 2 -and $OutIPv4Scope.IPUsedPercentage -gt $Critical)
            {
                $OutIPv4Code = 2
            }
            $OutIPv4Scopes += $OutIpv4Scope
            $IPTotal = 0
            $IPTotal = $OutIpv4Scope.IPFree + $OutIpv4Scope.IPUsed
            $OutIPv4Perfdata = $OutIPv4Perfdata + "'" + $OutIPv4Scope.ScopeId + "IPs Used'=" + $OutIpv4Scope.IPUsed + ";" + ($IPTotal * $Warning)/100 + ";" + ($IPTotal * $Critical)/100 + " "
        }
    }
    $MostUsedIPv4Scope = $OutIPv4Scopes | Sort-Object -Property IPFree | Select-Object -First 1
    $OutIPv4Text = "Scope '" + $MostUsedIPv4Scope.ScopeId + "' has least free IPs: " + $MostUsedIPv4Scope.IPFree + " (" + $MostUsedIPv4Scope.IPFreePercentage + " %)"
}
Catch
{
    $OutIPv4Code = 3
    $OutIPv4Text = "An error occured while executing the script on the server."
    $OutIPv4Perfdata = ""
}
Switch ($OutIPv4Code)
{
    0 {$OutIPv4Status = "OK"}
    1 {$OutIPv4Status = "Warning"}
    2 {$OutIPv4Status = "Critical"}
    3 {$OutIPv4Status = "Unknown"}
}
$OutIPv4 = $OutIPv4Status + " - " + $OutIPv4Text + " |" + $OutIPv4Perfdata
Write-Host $OutIPv4
Exit $OutIPv4Code
