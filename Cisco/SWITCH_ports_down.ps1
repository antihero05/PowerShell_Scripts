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

#!!!Install SNMP Net Tools, create a folder "Binary" where the script resides and copy "snmpwalk.exe" there!!!

$Switches = @(#Add comma separated Cisco switch names)
$SNMPCommunity = "<SNMP_WRITE_COMMUNITY>"
$InterfacesName = @()
$InterfacesLastChanged = @()
$HTMLOutput = "<!DOCTYPE html PUBLIC `"-//W3C//DTD XHTML 1.0 Strict//EN`"  `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd`">" `
            + "<html xmlns=`"http://www.w3.org/1999/xhtml`">" `
            + "<head>" `
            + "<title>Switch ports down over 30 days</title>" `
            + "</head><body>"
ForEach ($Switch in $Switches)
{
    $InterfacesName = @()
    $InterfacesLastChanged = @()
    $Command = "..\Binary\snmpwalk.exe -v 1 -c $($SNMPCommunity) $($Switch) .1.3.6.1.2.1.1.3"
    $Uptime = ((Invoke-Expression -Command:$Command) -Split " ")[3].Trim("(",")")
    $Starttime = (Get-Date).AddSeconds(-$Uptime / 100)
    $HTMLOutput = $HTMLOutput + "<h1>$($Switch)</h1>" `
            + "<p>This switch is up since $($Starttime) and the following ports are down over 30 days:</p>" `
            + "<table>" `
            + "<colgroup>" `
            + "<col/>" `
            + "<col/>" `
            + "</colgroup>"
    $Command = ".\Binary\snmpwalk.exe -v 1 -c $($SNMPCommunity) $($Switch) .1.3.6.1.2.1.2.2.1.2"
    $Result = Invoke-Expression -Command:$Command
    $Result | Foreach-Object{
        $Temp = "" | Select-Object Index, Name
        $Temp.Index = ($_ -Split " ")[0].Substring(22)
        $Temp.Name = ($_ -Split " ")[3].Trim("`"")
        $InterfacesName += $Temp
    }
    $Command = ".\Binary\snmpwalk.exe -v 1 -c $($SNMPCommunity) $($Switch) .1.3.6.1.2.1.2.2.1.9"
    $Result = Invoke-Expression -Command:$Command
    $Result | Foreach-Object{
        $Temp = "" | Select-Object Index, Timeticks
        $Temp.Index = ($_ -Split " ")[0].Substring(22)
        $Temp.Timeticks = ($_ -Split " ")[3].Trim("(",")")
        $InterfacesLastChanged += $Temp
    }
    $Command = ".\Binary\snmpwalk.exe -v 1 -c $($SNMPCommunity) $($Switch) .1.3.6.1.2.1.2.2.1.8"
    $Result = Invoke-Expression -Command:$Command
    $InterfacesStatus = $Result | Where-Object {$_ -match "INTEGER: 2"}
    $InterfacesStatus | Foreach-Object {
        $InterfaceIndex = $_.Substring(22,5)
        If ($InterfaceIndex -gt 10100 -and $InterfaceIndex -lt 14500)
        {
            $Interface = "" | Select-Object Index, Name, LastChanged
            $Interface.Index = $InterfaceIndex
            $Temp = $InterfacesName | Where-Object {$_.Index -eq $Interface.Index}
            $Interface.Name = $Temp.Name
            $Temp = $InterfacesLastChanged | Where-Object {$_.Index -eq $Interface.Index}
            $Interface.LastChanged = $Starttime.AddSeconds($Temp.Timeticks / 100)
            If ($Interface.LastChanged -lt (Get-Date).AddDays(-30))
            {
                $HTMLOutput = $HTMLOutput + "<tr><td>$($Interface.Name)</td><td>$($Interface.LastChanged)</td></tr>"
            }
        }
    }
    $HTMLOutput = $HTMLOutput + "</table>"
}
$HTMLOutput = $HTMLOutput + "</body></html>"
$HTMLOutput | Out-File ".\$((Get-Date).Year)-$((Get-Date).Month)-$((Get-Date).Day)_SWITCH_ports_down.htm"
