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

$Warning=90
$Critical=30
$OutCertificates = @()
$OutCertificatesText = ""
$OutCertificatesPerfdata = ""
$OutCertificatesCode = 0
Try
{
    Get-ChildItem -Path Cert:\LocalMachine\My -Recurse | ForEach-Object {
        $OutCertificate = "" | Select SubjectName, IssuerName, ExpireDate, DaysRemaining
        If ([string]$_.GetName() -match 'CN=([A-Za-z0-9\. ]){1,}')
        {
            $OutCertificate.SubjectName = $Matches[0]
        }
        If ([string]$_.GetIssuerName() -match 'CN=([A-Za-z0-9\. ]){1,}')
        {
            $OutCertificate.IssuerName = $Matches[0]
        }
        $OutCertificate.ExpireDate = [datetime]$_.NotAfter
        $OutCertificate.DaysRemaining = [int](New-TimeSpan $(Get-Date) $OutCertificate.ExpireDate).Days
        If ($OutCertificatesCode -lt 1 -and $OutCertificate.DaysRemaining -lt $Warning)
        {
            $OutCertificatesCode = 1
        }
        If ($OutCertificatesCode -lt 2 -and $OutCertificate.DaysRemaining -lt $Critical)
        {
            $OutCertificatesCode = 2
        }
        $OutCertificates += $OutCertificate
        $OutCertificatesPerfdata = $OutCertificatesPerfdata + "'" + $OutCertificate.SubjectName + " by " + $OutCertificate.IssuerName + " expires (days)'=" + $OutCertificate.DaysRemaining + ";" + $Warning + ";" + $Critical + " "
    }
    $NextExpiringCertificate = $OutCertificates | Sort-Object -Property DaysRemaining | Select-Object -First 1
    $OutCertificatesText = "'" + $NextExpiringCertificate.SubjectName + "' issued by '" + $NextExpiringCertificate.IssuerName + "' expires in " + $NextExpiringCertificate.DaysRemaining + " days"
}
Catch
{
    $OutCertificatesCode = 3
    $OutCertificatesText = "An error occured while executing the script on the server."
    $OutCertificatesPerfdata = ""
}
Switch ($OutCertificatesCode)
{
    0 {$OutCertificatesStatus = "OK"}
    1 {$OutCertificatesStatus = "Warning"}
    2 {$OutCertificatesStatus = "Critical"}
    3 {$OutCertificatesStatus = "Unknown"}
}
$OutCertificates = $OutCertificatesStatus + " - " + $OutCertificatesText + " |" + $OutCertificatesPerfdata
Write-Host $OutCertificates
Exit $OutCertificatesCode
