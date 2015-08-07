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

$LDAPController = "<GLOBAL_CATALOG_DOMAIN_CONTROLLER>"
$ADComputers = Get-ADComputer -Filter {*} -SearchBase "<BASEDN_PATH_IN_AD_FOR_SERVERS>" -SearchScope Subtree -Server $LDAPController
$Blacklist = "*<BLACKLISTED_OBJECT"
$ADComputers | ForEach-Object {
    $LDAPDN = $_.DistinguishedName
    $LDAP = $LDAPDN.Split(",")
    $Skip = $False
    $Blacklist | ForEach-Object {
        If ($LDAPDN -like $_)
        {
            $Skip = $True
        }
    }
    If ($Skip -eq $False)
    {
        [Array]::Reverse($LDAP)
        $LDAPCustom = $False
        $Loop = 1
        $OU = "<BASEDN_PATH_IN_AD_FOR_GROUPS_FOR_SERVERS>"
        $Group = "Acc.LIS.DE"
        Foreach ($LDAPObject in $LDAP)
        {
            If ($LDAPObject -eq "OU=DE")
            {
                $LDAPCustom = $True
            }
            Elseif ($LDAPCustom -eq $True)
            {
                If ($LDAPObject.Substring(0,2) -eq "CN")
                {
                   $LDAPObject = $LDAPObject -Replace "CN", "OU"
                }
                Try
                {
                    $OUBase = $OU
                    $OU =  $LDAPObject + "," + $OU
                    $LDAPOU = Get-ADOrganizationalUnit -Identity  $OU -Server $LDAPController
                    Set-ADOrganizationalUnit -Identity $LDAPOU -ProtectedFromAccidentalDeletion $False
                }
                Catch
                {
                    $OUName = $LDAPObject.Substring(3,$LDAPObject.Length-3)
                    If ($Loop -eq $LDAP.Count)
                    {
                        $OUName = $OUName.ToUpper()
                    }
                    Write-Output "Create OU '$($OUName)' in BaseDN '$($OUBase)'"
                    New-ADOrganizationalUnit $OUName -Path $OUBase -ProtectedFromAccidentalDeletion $False -Server $LDAPController
                    Sleep 1
                }
                If ($Loop -eq $LDAP.Count)
                {
                    $Group = $Group + "." + $LDAPObject.Substring(3,$LDAPObject.Length-3).ToUpper()
                    $AdminGroup = $Group + ".Admin"
                    $RDPGroup = $Group + ".RDP"
                    Try
                    {
                        $AdminGroupDN = "CN=$($AdminGroup)," + $OU
                        $LDAPAdminGroup = Get-ADGroup -Identity $AdminGroupDN -Server $LDAPController
                    }
                    Catch
                    {
                        Write-Output "Create Group '$($AdminGroup)' in BaseDN '$($OU)'"
                        New-ADGroup $AdminGroup -GroupCategory Security -GroupScope Universal -Path $OU -Server $LDAPController
                        Sleep 1
                    }
                    Try
                    {
                        $RDPGroupDN = "CN=$($RDPGroup)," + $OU
                        $LDAPAdminGroup = Get-ADGroup -Identity $RDPGroupDN -Server $LDAPController
                    }
                    Catch
                    {
                        Write-Output "Create Group '$($RDPGroup)' in BaseDN '$($OU)'"
                        New-ADGroup $RDPGroup -GroupCategory Security -GroupScope Universal -Path $OU -Server $LDAPController
                        Sleep 1
                    }
                }
                Else
                {
                    $Group = $Group + "." + $LDAPObject.Substring(3,$LDAPObject.Length-3)
                }
            }
            $Loop++
        }
    }
