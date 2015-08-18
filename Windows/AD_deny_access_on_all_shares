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

$Hostname = "<HOST_NAME>"
$User = "<USER_NAME>"
$Shares = Get-WmiObject -Class Win32_Share -ComputerName $Hostname
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule "CORPNET\OlHoDE", "ReadAndExecute", "Deny"
ForEach ($Share in $Shares)
{
    If ($Share.Name -notlike "*$")
    {
        $ShareSecurity = Get-WmiObject -Class Win32_LogicalShareSecuritySetting -ComputerName $Hostname -Filter "Name='$($Share.Name)'"
        $SecurityDescriptor = $ShareSecurity.GetSecurityDescriptor().Descriptor
        $ACE = ([WMIClass] "Win32_ACE").CreateInstance()
        $Trustee = ([WMIClass] "Win32_Trustee").CreateInstance()
        $Trustee.Name = $User
        $Trustee.Domain = "<DOMAIN_NAME>"
        $ACE.AccessMask = 1179817
        $ACE.AceFlags = 3 
        $ACE.AceType = 1
        $ACE.Trustee = $Trustee
        $SecurityDescriptor.DACL += $ACE.PSObject.BaseObject
        $ShareSecurity.SetSecurityDescriptor($SecurityDescriptor)
    }
}
