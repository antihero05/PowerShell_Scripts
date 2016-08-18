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

$APCupss = @(#Add comma separated APC ups names)
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
ForEach ($APCUps in $APCUpss)
{
    $FTPRequest = [System.Net.FtpWebRequest]::Create("ftp://$($APCUps)/config.ini")
    $FTPRequest.Credentials = $Credential.GetNetworkCredential()
    $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $FTPResponse = $FTPRequest.GetResponse()
    $ResponseStream = $FTPResponse.GetResponseStream()
    $StreamReader = New-Object System.IO.StreamReader($ResponseStream)
    $StreamWriter = New-Object System.IO.StreamWriter(".\TFTPDirectory\$($APCUps).cfg")
    $StreamWriter.WriteLine($StreamReader.ReadToEnd())
    $StreamWriter.Close()
    $StreamReader.Close()
    $FTPResponse.Close()
    Move-Item -Path ".\TFTPDirectory\$($APCUps).cfg" -Destination ".\$((Get-Date).Year)\KW$(Get-Date -UFormat %V)" -Force
}
