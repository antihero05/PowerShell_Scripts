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

#!!!Create a folder "TFTPDirectory" where the script resides which is configured as the root folder of a local TFTP server!!!
#!!!Install SNMP Net Tools, create a folder "Binary" where the script resides and copy "snmpset.exe" there!!!

#Functions
Function Test-FileLocked { Param ([Parameter(Mandatory=$True)][String]$Path)
    $File = New-Object System.IO.FileInfo $Path
    If ((Test-Path -Path $Path) -eq $False)
    {
        Return $False
    }
    Try
    {
        $Stream = $File.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        If ($Stream)
        {
            $Stream.Close()
        }
        Return $False
    }
    Catch
    {
        Return $True
    }
}
#End Functions

$Switches = @(#Add comma separated cisco switch names)
$SNMPCommunity = "<SNMP_WRITE_COMMUNITY>"
$TFTPServer = $([System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | Where-Object {$_.AddressFamily -eq "InterNetwork"})[0].IPAddressToString
If (-Not(Test-Path ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)"))
{
    If (-Not(Test-Path ".\$((Get-Date).Year)"))
    {
        New-Item -ItemType Directory -Path ".\$((Get-Date).Year)"
    }
    New-Item -ItemType Directory -Path ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)"
}
ForEach ($Switch in $Switches)
{
    $Random = Get-Random
    $Command = ".\Binary\snmpset.exe -v 1 -c $($SNMPCommunity) $($Switch)"
    $Command = $Command + ".1.3.6.1.4.1.9.9.96.1.1.1.1.2.$($Random) i 1 "
    $Command = $Command + ".1.3.6.1.4.1.9.9.96.1.1.1.1.3.$($Random) i 3 "
    $Command = $Command + ".1.3.6.1.4.1.9.9.96.1.1.1.1.4.$($Random) i 1 "
    $Command = $Command + ".1.3.6.1.4.1.9.9.96.1.1.1.1.5.$($Random) a $($TFTPServer) "
    $Command = $Command + ".1.3.6.1.4.1.9.9.96.1.1.1.1.6.$($Random) s $($Switch).cfg "
    $Command = $Command + ".1.3.6.1.4.1.9.9.96.1.1.1.1.14.$($Random) i 4 "
    Invoke-Expression -Command:$Command
    Start-Sleep -Seconds 3
    While (Test-FileLocked ".\TFTPDirectory\$($Switch).cfg")
    {
        Start-Sleep -Seconds 3
    }
    Move-Item -Path ".\TFTPDirectory\$($Switch).cfg" -Destination ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)" -Force
	$Random = Get-Random
    $Command = ".\Binary\snmpset.exe -v 1 -c $($SNMPCommunity) $($Switch) "
	$Command = $Command + ".1.3.6.1.4.1.9.9.10.1.2.1.1.2.$($Random) i 3 "
    $Command = $Command + ".1.3.6.1.4.1.9.9.10.1.2.1.1.3.$($Random) i 1 "
    $Command = $Command + ".1.3.6.1.4.1.9.9.10.1.2.1.1.4.$($Random) a $($TFTPServer) "
    $Command = $Command + ".1.3.6.1.4.1.9.9.10.1.2.1.1.5.$($Random) s vlan.dat "
	$Command = $Command + ".1.3.6.1.4.1.9.9.10.1.2.1.1.6.$($Random) s $($Switch)_vlan.dat "
    $Command = $Command + ".1.3.6.1.4.1.9.9.10.1.2.1.1.11.$($Random) i 4 "
    Invoke-Expression -Command:$Command
    Start-Sleep -Seconds 3
    While (Test-FileLocked ".\TFTPDirectory\$($Switch)_vlan.dat")
    {
        Start-Sleep -Seconds 3
    }
    Move-Item -Path ".\TFTPDirectory\$($Switch)_vlan.dat" -Destination ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)" -Force
}
