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

$PaloAltoFirewalls = @(#Add comma separated Palo Alto firewall names)
$SecuredCredentialsPlain = Get-Content("<PATH_TO_DOCUMENT_WITH_CREDENTIALS_AS_SECURESTRING>")
$SecuredCredentials = $SecuredCredentialsPlain | ConvertTo-Securestring
$Credential = New-Object System.Management.Automation.PSCredential -Argumentlist "<NAME_OF_ADMINISTRATOR>", $SecuredCredentials
If (-Not(Test-Path ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)"))
{
    If (-Not(Test-Path ".\$((Get-Date).Year)"))
    {
        New-Item -ItemType Directory -Path ".\$((Get-Date).Year)"
    }
    New-Item -ItemType Directory -Path ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)"
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Foreach ($PaloAltoFirewall in $PaloAltoFirewalls)
{
    $URI="https://$($PaloAltoFirewall)/api/?type=keygen&user=$($Credential.UserName)&password=$($Credential.GetNetworkCredential().Password)"
    $WebClient = New-Object System.Net.WebClient
    [XML] $WebResponse = $WebClient.DownloadString($URI)
    $Key = $WebResponse.response.result.key
    $URI = "https://$($PaloAltoFirewalls).ifsworld.net/api/?type=export&category=configuration&key=$($Key)"
    [XML] $Configuration = $WebClient.DownloadString($URI)
    $Configuration.Save(".\TFTPDirectory\$($PaloAltoFirewall).xml")
    Move-Item -Path ".\$($PaloAltoFirewall).xml" -Destination ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)" -Force
}
