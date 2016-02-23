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

#!!!Install Windows Remote Administration Tools!!!

$LDAPController = "<GLOBAL_CATALOG_DOMAIN_CONTROLLER>"
$PrimaryDNSServer = "<IP_PRIMARY_DNS>"
$SecondaryDNSServer = "<IP_SECONDARY_DNS>"
$PrimaryWINSServer = "<IP_PRIMARY_WINS>"
$SecondaryWINSServer = "<IP_SECONDARY_WINS>"
$WINSNodeType = 0x8
$ADDHCPServers = Get-ADComputer -Filter {Enabled -eq $True -and OperatingSystem -like "Windows*"} -SearchBase "<BASEDN_PATH_IN_AD_FOR_SERVERS>" -SearchScope Subtree -Properties OperatingSystem -Server $LDAPController
$DHCPIPv4ScopeUpdateStatus = @()
$DNSServers = $PrimaryDNSServer, $SecondaryDNSServer
$WINSServers = $PrimaryWINSServer, $SecondaryWINSServer
If ([string]::IsNullOrEmpty($PrimaryWINSServer) -and [string]::IsNullOrEmpty($SecondaryWINSServer) -and [string]::IsNullOrEmpty($WINSNodeType))
{
    $RemoveWINS = $True
}
Else
{
    $RemoveWINS = $False
}
Foreach ($ADDHCPServer in $ADDHCPServers)
{
    $DHCPIPv4Scopes = Get-DhcpServerv4Scope -ComputerName $ADDHCPServer.Name
    Set-DhcpServerv4OptionValue -OptionId 6 -Value $DNSServers -ComputerName $ADDHCPServer.Name
    If ($RemoveWINS -eq $True)
    {
        Remove-DhcpServerv4OptionValue -OptionId 44 -ComputerName $ADDHCPServer.Name
        Remove-DhcpServerv4OptionValue -OptionId 46 -ComputerName $ADDHCPServer.Name
    }
    Else
    {
        Set-DhcpServerv4OptionValue -OptionId 44 -Value $WINSServers -ComputerName $ADDHCPServer.Name
        Set-DhcpServerv4OptionValue -OptionId 46 -Value $WINSNodeType -ComputerName $ADDHCPServer.Name
    }
    Foreach ($DHCPIPv4Scope in $DHCPIPv4Scopes)
    {
        $DHCPIPv4ScopeUpdateStatusEntry = "" | Select DHCPServer, ScopeId, OldPrimDNS, OldSecDNS, NewPrimDNS, NewSecDNS, OldPrimWINS, OldSecWINS, NewPrimWINS, NewSecWINS
        $DHCPIPv4ScopeUpdateStatusEntry.DHCPServer = $ADDHCPServer.Name
        $DHCPIPv4OptionValues = Get-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -ComputerName $ADDHCPServer.Name
        $DHCPIPv4ScopeUpdateStatusEntry.ScopeId = $DHCPIPv4Scope.ScopeId
        Foreach ($DHCPIPv4OptionValue in $DHCPIPv4OptionValues)
        {
            If ($DHCPIPv4OptionValue.OptionId -eq 6)
            {
                $DHCPIPv4ScopeUpdateStatusEntry.OldPrimDNS = $DHCPIPv4OptionValue.Value[0]
                $DHCPIPv4ScopeUpdateStatusEntry.OldSecDNS = $DHCPIPv4OptionValue.Value[1]
                #Set-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -OptionId 6 -Value $DNSServers -ComputerName $ADDHCPServer.Name
            }
            ElseIf($DHCPIPv4OptionValue.OptionId -eq 44)
            {
                $DHCPIPv4ScopeUpdateStatusEntry.OldPrimWINS = $DHCPIPv4OptionValue.Value[0]
                $DHCPIPv4ScopeUpdateStatusEntry.OldSecWINS = $DHCPIPv4OptionValue.Value[1]
                If ($RemoveWINS -eq $True)
                {
                    Remove-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -OptionId 44 -ComputerName $ADDHCPServer.Name
                    Remove-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -OptionId 46 -ComputerName $ADDHCPServer.Name
                }
                Else
                {
                    Set-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -OptionId 44 -Value $WINSServers -ComputerName $ADDHCPServer.Name
                    Set-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -OptionId 46 -Value $WINSNodeType -ComputerName $ADDHCPServer.Name
                }
            }
        }
        $DHCPIPv4OptionValues = Get-DhcpServerv4OptionValue -ScopeId $DHCPIPv4Scope.ScopeId -ComputerName $ADDHCPServer.Name
        Foreach ($DHCPIPv4OptionValue in $DHCPIPv4OptionValues)
        {
            If ($DHCPIPv4OptionValue.OptionId -eq 6)
            {
                $DHCPIPv4ScopeUpdateStatusEntry.NewPrimDNS = $DHCPIPv4OptionValue.Value[0]
                $DHCPIPv4ScopeUpdateStatusEntry.NewSecDNS = $DHCPIPv4OptionValue.Value[1]
            }
            ElseIf($DHCPIPv4OptionValue.OptionId -eq 44)
            {
                $DHCPIPv4ScopeUpdateStatusEntry.NewPrimWINS = $DHCPIPv4OptionValue.Value[0]
                $DHCPIPv4ScopeUpdateStatusEntry.NewSecWINS = $DHCPIPv4OptionValue.Value[1]
            }
        }
        $DHCPIPv4ScopeUpdateStatus += $DHCPIPv4ScopeUpdateStatusEntry
    }
}
$DHCPIPv4ScopeUpdateStatus | ConvertTo-HTML | Out-File .\DHCP_scope_update_DNS_WINS.htm
