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

#!!!Install SNMP Net Tools, create a folder "Binary" where the script resides and copy "snmpwalk.exe" and "snmpset.exe" there!!! 

# Adjustable Parameters
$AvayaIPOServer = "<AVAYA_IPO_SERVER>"
$AvayaSNMPCommunity = "<AVAYA_IPO_SERVER_SNMP_COMMUNITY>"
$CiscoSwitches = @(#Add comma separated Cisco switch names)
$AvayaPoolExtensions = @(#Add comma separated extension numbers or extension number ranges)
# End Adjustable Parameters
# Global Parameters
$global:CiscoSNMPCommunity = "<CISCO_SWITCHES_SNMP_WRITE_COMMUNITY>"
# End Global Parameters
# Functions
Function Get-SNMPValue
{
    param(
    [string]$Command,
    [string[]]$Data
    )
    If ($Data.Length -eq $null)
    {
        $SNMPRaw = Invoke-Expression -Command:$Command
    }
    Else
    {
        $SNMPRaw = $Data
    }
    $ValueType = ($SNMPRaw -Split " ")[2].Trim(":").ToUpper()
    Switch ($ValueType)
    {
        "INTEGER"
        {
            Return ($SNMPRaw -Split " ")[3].Trim(" ")
        }
        "STRING"
        {
            Return ($SNMPRaw -Split "`"")[1].Trim(" ")
        }
        "IPADDRESS"
        {
            Return ($SNMPRaw -Split " ")[3].Trim(" ")
        }
        "GAUGE32"
        {
            Return ($SNMPRaw -Split " ")[3].Trim(" ")
        }
        "HEX-STRING" 
        {
            $Return = ""
            $Temp = $SNMPRaw -Split " "
            For ($Loop = 3; $Loop -le $Temp.Length; $Loop++)
            {
                $Return = $Return + $Temp[$Loop]
            }
            Return $Return.Trim(" ")
        } 
    }
}
Function ConvertTo-IPAddress
{
    param(
    [string]$HexData
    )
    $Octets = $HexData[0..8]
    $IPData = ""
    ForEach ($Octet in $Octets)
    {
        $Loop++
        If ($Loop % 2 -eq $false)
        {
            $HexOctet = $HexOctet + $Octet
            $IPOctet = [Convert]::ToInt32($HexOctet,16)
            $IPData = $IPData + [Convert]::ToString($IPOctet) + "."
            $HexOctet = ""
        }
        Else
        {
        $HexOctet = $HexOctet + $Octet
        }
    }
    Return $IPData.Substring(0,$IPData.Length -1)
}
Function Reset-CiscoInterface
{
    param(
    [string]$CiscoSwitch,
    [string]$InterfaceID
    )
    $Command = "..\Binary\snmpset.exe -v 1 -c $($CiscoSNMPCommunity) $($CiscoSwitch) .1.3.6.1.2.1.2.2.1.7.$($InterfaceID) i 2"
    Invoke-Expression -Command:$Command
    $Command = "..\Binary\snmpset.exe -v 1 -c $($CiscoSNMPCommunity) $($CiscoSwitch) .1.3.6.1.2.1.2.2.1.7.$($InterfaceID) i 1"
    Invoke-Expression -Command:$Command
}
# End Functions
$Command = "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.1"
$AvayaPhoneCount = ((Invoke-Expression -Command:$Command) -Split " ")[3].Trim("(",")")
$AvayaPhones = @()
For ($Loop = 1; $Loop -le $AvayaPhoneCount; $Loop++)
{
    $AvayaPhone = "" | Select-Object "ExtensionID","ExtensionNumber","UserShort","UserLong","Type","Port","PortNumber","ModuleNumber","IPAddress","MACAddress"
    $AvayaPhone.ExtensionID = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.2.$($Loop)"
    $AvayaPhone.ExtensionNumber = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.3.$($Loop)"
    $AvayaPhone.UserShort = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.4.$($Loop)"
    $AvayaPhone.UserLong = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.5.$($Loop)"
    $AvayaPhone.Type = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.6.$($Loop)"
    $AvayaPhone.Port = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.7.$($Loop)"
    $AvayaPhone.PortNumber = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.8.$($Loop)"
    $AvayaPhone.ModuleNumber = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.9.$($Loop)"
    $AvayaPhone.IPAddress = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.10.$($Loop)"
    $Temp = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -Ox -v 1 -c $($AvayaSNMPCommunity) $($AvayaIPOServer) .1.3.6.1.4.1.6889.2.2.1.1.1.1.1.2.1.11.$($Loop)"
    If ($Temp -match "^[0-9A-F]*$")
    {
        $AvayaPhone.MACAddress = $Temp
    }
    Else
    {
        $AvayaPhone.MACAddress = ""
    }
    $AvayaPhones += $AvayaPhone
}
$LLDPNeighbours = @()
Foreach ($CiscoSwitch in $CiscoSwitches)
{
    $LLDPIPAddresses = Invoke-Expression -Command "..\Binary\snmpwalk.exe -Ox -v 1 -c $($CiscoSNMPCommunity) $($CiscoSwitch) .1.0.8802.1.1.2.1.4.1.1.5"
    $LLDPMACAddresses = Invoke-Expression -Command "..\Binary\snmpwalk.exe -Ox -v 1 -c $($CiscoSNMPCommunity) $($CiscoSwitch) .1.0.8802.1.1.2.1.4.1.1.7"
    $Interfaces = Invoke-Expression -Command "..\Binary\snmpwalk.exe -v 1 -c $($CiscoSNMPCommunity) $($CiscoSwitch) .1.3.6.1.2.1.2.2.1.2"
    $Loop = 0
    Foreach ($LLDPIPAddress in $LLDPIPAddresses)
    {
        $LLDPNeighbour = "" | Select-Object "CiscoSwitch","Interface","InterfaceID","IPAddress","MACAddress"
        $LLDPNeighbour.CiscoSwitch = $CiscoSwitch
        $Temp = (($LLDPIPAddress.Split(" "))[0].Split("."))[13]
        $LLDPNeighbour.Interface = Get-SNMPValue -Command "..\Binary\snmpwalk.exe -v 1 -c $($CiscoSNMPCommunity) $($CiscoSwitch) .1.0.8802.1.1.2.1.3.7.1.4.$($Temp)"
        [string]$Temp = $Interfaces -like "*`"$($LLDPNeighbour.Interface)`""
        $LLDPNeighbour.InterfaceID = (($Temp.Split(" "))[0].Split("."))[11]
        $Temp = Get-SNMPValue -Data $LLDPIPAddress
        If ($Temp -match "^[0-9A-F]*$")
        {
            $LLDPNeighbour.IPAddress = ConvertTo-IPAddress -HexData $Temp.Substring($Temp.Length-8,8)
        }
        Else
        {
            $LLDPNeighbour.IPAddress = ""
        }
        $Temp = Get-SNMPValue -Data $LLDPMACAddresses[$Loop]
        If ($Temp -match "^[0-9A-F]*$")
        {
            $LLDPNeighbour.MACAddress = $Temp
        }
        Else
        {
            $LLDPNeighbour.MACAddress = ""
        }
        $LLDPNeighbours += $LLDPNeighbour
        $Loop++
    }
}
Foreach ($AvayaPoolExtension in $AvayaPoolExtensions)
{
    $AvayaPhone = $Null
    $LLDPNeighbour = $Null
    $AvayaPhone = $AvayaPhones | Where-Object {$_.ExtensionNumber -eq $AvayaPoolExtension}
    $LLDPNeighbour = $LLDPNeighbours | Where-Object {$_.MACAddress -eq $AvayaPhone.MACAddress}
    If ($LLDPNeighbour -eq $Null)
    {
        $LLDPNeighbour = $LLDPNeighbours | Where-Object {$_.IPAddress -eq $AvayaPhone.IPAddress}
    }
    If ($AvayaPhone -eq $Null -or $LLDPNeighbour -eq $Null)
    {
        Write-Output "# Could not identify device port for extension $($AvayaPoolExtension) with the gathered information:"
        Write-Output "MACAddress - $($AvayaPhone.MACAddress)"
        Write-Output "IPAddress - $($AvayaPhone.IPAddress)"
        Write-Output "CiscoSwitch - $($LLDPNeighbour.CiscoSwitch)"
        Write-Output "InterfaceID - $($LLDPNeighbour.InterfaceID)"
    }
    Else
    {
        Reset-CiscoInterface -CiscoSwitch $LLDPNeighbour.CiscoSwitch -InterfaceID $LLDPNeighbour.InterfaceID
    }
}
