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
$ADComputers = Get-ADComputer -Filter {Enabled -eq $True -and OperatingSystem -like "Windows*"} -SearchBase "<BASEDN_PATH_IN_AD_FOR_SERVERS>" -SearchScope Subtree -Properties OperatingSystem -Server $LDAPController
$ComputerUpdateStatus = @()
$DNSServers = $PrimaryDNSServer, $SecondaryDNSServer
ForEach ($ADComputer in $ADComputers)
{
    $Skip = $False
    $ComputerUpdateStatusEntry = "" | Select Name, Status, OldPrimDNS, OldSecDNS, NewPrimDNS, NewSecDNS, OldPrimWINS, OldSecWINS, NewPrimWINS, NewSecWINS
    $ComputerUpdateStatusEntry.Name = $ADComputer.Name
    Try
    {
        $IPs = [System.Net.Dns]::GetHostAddresses($ComputerUpdateStatusEntry.Name) | Select -ExpandProperty IPAddressToString
    }
    Catch
    {
        $ComputerUpdateStatusEntry.Status = "No DNS entry"
        $Skip = $True
    }
    If ($Skip -eq $False)
    {
        $Active = $False
        ForEach ($IP in $IPs) 
        {
            If (Test-Connection -ComputerName $IP -Count 2 -Quiet)
            { 
                $Active = $True
                Try
                {
                    $ErrorActionPreference = "Stop"
                    $ComputerWMINetworkAdapters = Get-WmiObject -ComputerName $IP -Filter "IPEnabled=TRUE" Win32_NetworkAdapterConfiguration | Where-Object {$_.ServiceName -ne "VMnetAdapter"}
                    Foreach ($ComputerWMINetworkAdapter in $ComputerWMINetworkAdapters)
                    {
                        If ($ComputerWMINetworkAdapter.DHCPEnabled -eq $False)
                        {
                            $ComputerUpdateStatusEntry.OldPrimDNS = $ComputerWMINetworkAdapter.DNSServerSearchOrder[0]
                            $ComputerUpdateStatusEntry.OldSecDNS = $ComputerWMINetworkAdapter.DNSServerSearchOrder[1]
                            $ComputerUpdateStatusEntry.SetDNSServerSearchOrder($DNSServers)
                            $ComputerUpdateStatusEntry.OldPrimWINS = $ComputerWMINetworkAdapter.WINSPrimaryServer
                            $ComputerUpdateStatusEntry.OldSecWINS = $ComputerWMINetworkAdapter.WINSSecondaryServer
                            $ComputerUpdateStatusEntry.SetWINSServer($PrimaryWINSServer, $SecondaryWINSServer)
                        }
                        Else
                        {
                            $ComputerUpdateStatusEntry.Status = "DHCP"
                        }
                    }
                    $ComputerWMINetworkAdapters = Get-WmiObject -ComputerName $IP -Filter "IPEnabled=TRUE" Win32_NetworkAdapterConfiguration | Where-Object {$_.ServiceName -ne "VMnetAdapter"}
                    Foreach ($ComputerWMINetworkAdapter in $ComputerWMINetworkAdapters)
                    {
                        If ($ComputerWMINetworkAdapter.DHCPEnabled -eq $False)
                        {
                            $ComputerUpdateStatusEntry.NewPrimDNS = $ComputerWMINetworkAdapter.DNSServerSearchOrder[0]
                            $ComputerUpdateStatusEntry.NewSecDNS = $ComputerWMINetworkAdapter.DNSServerSearchOrder[1]
                            $ComputerUpdateStatusEntry.NewPrimWINS = $ComputerWMINetworkAdapter.WINSPrimaryServer
                            $ComputerUpdateStatusEntry.NewSecWINS = $ComputerWMINetworkAdapter.WINSSecondaryServer
                        }
                    }
                }
                Catch
                {
                    $ComputerUpdateStatusEntry.Status = "WMI not accessible"
                }
                Break
            }
        }
        If ($Active -eq $False)
        {
            $ComputerUpdateStatusEntry.Status = "Not reachable"
        }
        $ComputerUpdateStatusEntry
    }
    $ComputerUpdateStatus += $ComputerUpdateStatusEntry
}
$ComputerUpdateStatus | ConvertTo-HTML | Out-File .\WMI_update_DNS_WINS.htm
