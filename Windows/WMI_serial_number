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

#!!!Install Windows Remote Administration Tools!!!

$LastLogonDate = (Get-Date).AddDays(-30)
$ADComputers = Get-ADComputer -Filter {LastLogonDate -gt $LastLogonDate} -SearchBase "<BASEDN_PATH_IN_AD>" -SearchScope Subtree | Select -ExpandProperty Name
$Mappings = @()
$ADComputers | ForEach-Object {
    $Skip = $False
    $Mapping = "" | Select Name, SerialNumber
    $Mapping.Name = $_
    Try
    {
        $IPs = [System.Net.Dns]::GetHostAddresses($Mapping.Name) | Select -ExpandProperty IPAddressToString
    }
    Catch
    {
        $Mapping.SerialNumber = "No DNS entry"
        $Skip = $True
    }
    If ($Skip -eq $False)
    {
        $Active = $False
        ForEach ($IP in $IPs) 
        {
            $IP = $_
            If (Test-Connection -ComputerName $IP -Count 2 -Quiet)
            {
                $Active = $True
                Try
                {
                    $ErrorActionPreference = "Stop"
                    $Mapping.SerialNumber = (Get-WmiObject -ComputerName $IP win32_bios) | Select -ExpandProperty SerialNumber
                }
                Catch
                {
                    $Mapping.SerialNumber = "WMI not accessible"
                }
                Break
            }
        }
        If ($Active -eq $False)
        {
            $Mapping.SerialNumber = "Not reachable"
        }
    }
    $Mappings += $Mapping
}
$Mappings | ConvertTo-HTML | Out-File .\WMI_serial_number.htm
