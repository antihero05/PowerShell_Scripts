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

#!!!Install vSphere PowerCLI!!!

$VMwarevCenter = @(#Add comma separated vSphere vCenter names)
$SecuredCredentialsPlain = Get-Content("<PATH_TO_DOCUMENT_WITH_CREDENTIALS_AS_SECURESTRING>")
$SecuredCredentials = $SecuredCredentialsPlain | ConvertTo-Securestring
$Credential = New-Object System.Management.Automation.PSCredential -Argumentlist "<NAME_OF_LOCAL_ADMINISTRATOR>", $SecuredCredentials
$VMStats = @()
If ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PSSnapin VMware.VimAutomation.Core
}
Connect-VIServer -Server $VMwarevCenter -Credential $Credential
$VMwareVM = Get-VM
ForEach ($VM in $VMwareVM)
{
    $VMStat = "" | Select VirtualMachine, State, Host, CPUCores, "CPULoadAvg (Mhz)", "CPULoadMax (Mhz)", "CPULoadMin (Mhz)", "RAM (MByte)", HDDs, "HDDCapacity (GByte)", "HDDLoadAvg (KByte/s)", "HDDLoadMax (KByte/s)", "HDDLoadMin (KByte/s)", NICs, "NICLoadAvg (KByte/s)", "NICLoadMax (KByte/s)", "NICLoadMin (KByte/s)"
    $VMStat.VirtualMachine = $VM.Name
    $VMStat.State = $VM.PowerState
    $VMStat.Host = $VM.VMHost.Name
    $VMStat.CPUCores = $VM.NumCpu
    Try
    {
        $ErrorActionPreference = "Stop"
        $CPUStat = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat cpu.usagemhz.average
        $CPULoad = $CPUStat | Measure-Object -Property Value -Average -Maximum -Minimum
        $VMStat."CPULoadAvg (Mhz)" = [math]::Round($CPULoad.Average)
        $VMStat."CPULoadMax (Mhz)" = [math]::Round($CPULoad.Maximum)
        $VMStat."CPULoadMin (Mhz)" = [math]::Round($CPULoad.Minimum)
    }
    Catch
    {
        $VMStat."CPULoadAvg (Mhz)" = "N/A"
        $VMStat."CPULoadMax (Mhz)" = "N/A"
        $VMStat."CPULoadMin (Mhz)" = "N/A"
    }
    $VMStat."RAM (MByte)" = $VM.MemoryMB
    Get-HardDisk -VM $VM | Foreach-Object {
        $VMStat.HDDs = $VMStat.HDDs + 1
        $VMStat."HDDCapacity (GByte)" = $VMStat."HDDCapacity (GByte)" + $_.CapacityGB}
    Try
    {
        $ErrorActionPreference = "Stop"
        $HDDStat = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat disk.usage.average
        $HDDLoad = $HDDStat | Measure-Object -Property Value -Average -Maximum -Minimum
        $VMStat."HDDLoadAvg (KByte/s)" = [math]::Round($HDDLoad.Average)
        $VMStat."HDDLoadMax (KByte/s)" = [math]::Round($HDDLoad.Maximum)
        $VMStat."HDDLoadMin (KByte/s)" = [math]::Round($HDDLoad.Minimum)
    }
    Catch
    {
        $VMStat."HDDLoadAvg (KByte/s)" = "N/A"
        $VMStat."HDDLoadMax (KByte/s)" = "N/A"
        $VMStat."HDDLoadMin (KByte/s)" = "N/A"
    }
    $VMStat.NICs = (Get-NetworkAdapter -VM $VM).Count
    Try
    {
        $ErrorActionPreference = "Stop"
        $NICStat = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat net.usage.average
        $NICLoad = $NICStat | Measure-Object -Property Value -Average -Maximum -Minimum  
        $VMStat."NICLoadAvg (KByte/s)" = [math]::Round($NICLoad.Average)
        $VMStat."NICLoadMax (KByte/s)" = [math]::Round($NICLoad.Maximum)
        $VMStat."NICLoadMin (KByte/s)" = [math]::Round($NICLoad.Minimum)
    }
    Catch
    {
        $VMStat."NICLoadAvg (KByte/s)" = "N/A"
        $VMStat."NICLoadMax (KByte/s)" = "N/A"
        $VMStat."NICLoadMin (KByte/s)" = "N/A"
    }
    $VMStats += $VMStat
}
$VMStats = $VMStats | Sort-Object -Property VirtualMachine, Device
$VMStats | ConvertTo-HTML | Out-File .\VM_performance_stats.htm
Disconnect-VIServer $VMwarevCenter -Confirm:$False
