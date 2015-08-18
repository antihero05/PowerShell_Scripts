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
$Blacklist = "*<BLACKLISTED_OBJECT>"
$FailedComputers = @()
$ADComputers | ForEach-Object {
    $LDAPDN = $_.DistinguishedName
    $Computer = $_.Name
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
        Write-Output ""
        Write-Output "### $($Computer.ToUpper()) ###"
        Write-Output ""
        Try
        {
            $IP = [System.Net.Dns]::GetHostAddresses($Computer) | Select -ExpandProperty IPAddressToString
        }
        Catch
        {
            Write-Output "No DNS entry"
            $FailedComputers += $Computer.ToUpper() + " --- No DNS entry"
            $Skip = $True
        }
        If ($Skip -eq $False)
        {
            If (Test-Connection -ComputerName $IP -Count 2 -Quiet)
            {
                Try
                {
                    $OSLanguageCode = (Get-WmiObject Win32_OperatingSystem -ComputerName $Computer).OSlanguage
                    Switch ($OSLanguageCode) `
                    {
                        1033 {
                                $LocalAdminGroup = "Administrators"
                                $LocalRDPGroup = "Remote Desktop Users"
                            }
                        1031 {
                                $LocalAdminGroup = "Administratoren"
                                $LocalRDPGroup = "Remotedesktopbenutzer"
                            }
                        default {
                                Write-Output "OSLanguageCode '$($OSLanguageCode)' not resolved"
                                $FailedComputers += $Computer.ToUpper() + " --- OSLanguageCode '$($OSLanguageCode)' not resolved"
                        }
                    }
                }
                Catch
                {
                    Write-Output "OS is not Windows"
                    $FailedComputers += $Computer.ToUpper() + " --- OS is not Windows"
                    Return
                }
                Try
                {
                    $Groups = @()
                    $ErrorActionPreference = "Stop"
                    $ReturnValue = Invoke-Command {net localgroup $args[0]| Where-Object {$_ -and $_ -notmatch "command completed successfully"} | Select-Object -Skip 4} -Computer $Computer -ArgumentList $LocalAdminGroup
                    Write-Output "#ADMIN:"
                    $LocalAdminGroupMembers = @()
                    $ReturnValue | ForEach-Object {
                    If ($_ -ne "<EXCEPTION_1>" -and $_ -ne "<EXCEPTION_2>")
                        {
                            $LocalAdminGroupMembers += $_
                        }
                    }
                    $LocalAdminGroupMembers 
                    $LocalRDPGroupMembers = @()
                    $LocalRDPGroupMembers = Invoke-Command {net localgroup $args[0] | Where-Object {$_ -and $_ -notmatch "command completed successfully"} | Select-Object -Skip 4} -Computer $Computer -ArgumentList $LocalRDPGroup
                    Write-Output "#RDP:"
                    $LocalRDPGroupMembers
                    [Array]::Reverse($LDAP)
                    $LDAPCustom = $False
                    $Loop = 1
                    $Group = "<GROUPNAME_PREFIX>"
                    Write-Output "#Actions:"
                    Foreach ($LDAPObject in $LDAP)
                    {
                        If ($LDAPObject -eq "OU=DE")
                        {
                            $LDAPCustom = $True
                        }
                        Elseif ($LDAPCustom -eq $True)
                        {
                            If ($Loop -eq $LDAP.Count)
                            {
                                $Group = $Group + "." + $LDAPObject.Substring(3,$LDAPObject.Length-3).ToUpper()
                                $AdminGroup = $Group + ".Admin"
                                If ($LocalAdminGroupMembers -notcontains "<DOMAIN_NAME>\$($AdminGroup)")
                                {
                                    Write-Output "Add domain group '$($AdminGroup)' to local group '$($LocalAdminGroup)'"
                                    ([ADSI]"WinNT://$($Computer)/$($LocalAdminGroup),group").Add("WinNT://<DOMAIN_NAME>/$($AdminGroup),group")
                                    Sleep 1
                                }
                                $RDPGroup = $Group + ".RDP"
                                If ($LocalRDPGroupMembers -notcontains "<DOMAIN_NAME>\$($RDPGroup)")
                                {
                                    Write-Output "Add domain group '$($RDPGroup)' to local group '$($LocalRDPGroup)'"
                                    ([ADSI]"WinNT://$($Computer)/$($LocalRDPGroup),group").Add("WinNT://<DOMAIN_NAME>/$($RDPGroup),group")
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
                Catch
                {
                    Write-Output "PSRemote not successfull"
                    $FailedComputers += $Computer.ToUpper() + " --- PSRemote not successfull"
                }
            }
            Else
            {
                Write-Output "No reply from host"
                $FailedComputers += $Computer.ToUpper() + " --- No reply from host"
            }
        }
    }
}
Write-Output ""
Write-Output "!!! Failure Summary !!!"
Write-Output ""
Write-Output "##################################################"
Write-Output $FailedComputers
Write-Output "##################################################"
