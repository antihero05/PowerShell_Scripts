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
function Test-Item
{
    param
    (
        [String] $ItemPath,
        [String] $ItemProperty,
        [String] $ItemPropertyValue
    )
    If ([String]::IsNullOrEmpty($ItemProperty) -and [String]::IsNullOrEmpty($ItemPropertyValue))
    {
        Return Test-Path -Path $ItemPath
    }
    Else
    {
        If (Test-Path -Path $ItemPath)
        {
            $Item = Get-Item -Path $ItemPath
            If ($Item.GetValue($ItemProperty) -eq $Null -or (Test-Path -Path ($ItemPath + "\" + $ItemProperty)))
            {
                $Return = $False
            }
            Else
            {
                $Return = $True
            }
        }
        Else
        {
            $Return = $False
        }
    }
    If ([String]::IsNullOrEmpty($ItemPropertyValue))
    {
        Return $Return
    }
    Else
    {
        If ($Return -eq $True -and $ItemPropertyValue -eq (Get-ItemPropertyValue -Path $ItemPath -Name $ItemProperty))
        {
            Return $True
        }
        Else
        {
            Return $False
        }
    }
}
function Test-MSIInstalled {
    param (
        [IO.FileInfo] $Path
    )
    $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $Database = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", [System.Reflection.BindingFlags]::InvokeMethod, $Null, $WindowsInstaller, @($Path.FullName, 0))
    $Query = "SELECT Value FROM Property WHERE Property = 'ProductCode'"
    $View = $Database.GetType().InvokeMember("OpenView", [System.Reflection.BindingFlags]::InvokeMethod, $Null, $Database, ($Query))
    $View.GetType().InvokeMember("Execute", [System.Reflection.BindingFlags]::InvokeMethod, $Null, $View, $Null)
    $Record = $View.GetType().InvokeMember("Fetch", [System.Reflection.BindingFlags]::InvokeMethod, $Null, $View, $Null)
    $ProductCode= $Record.GetType().InvokeMember("StringData", "GetProperty", $Null, $Record, 1)
    $View.GetType().InvokeMember("Close", [System.Reflection.BindingFlags]::InvokeMethod, $Null, $View, $Null)
    $Temp = $ProductCode.Substring(1,$ProductCode.Length -2)
    $Value = ""
    $Loop = 0
    $Temp.Split("-") | ForEach-Object{
        $Item = $_
        $Loop = $Loop + 1
        If ($Loop -lt 4)
        {
            $Item = -join $Item[-1..-$Item.Length]
        }
        Else
        {
            $SubItem = $Item.ToCharArray()
            $Item = ""
            For ($SubLoop = 0; $SubLoop -le $SubItem.Count; $SubLoop+=2)
            {
                $Item = $Item + $SubItem[$Subloop + 1] + $SubItem[$Subloop]
            }
        }
        $Value = $Value + $Item
    }
    If ((Test-Path -Path "HKCR:\") -ne $True)
    {
        $Null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
    }
    $Return = Test-Item -ItemPath ("HKCR:\Installer\Products\$($Value)")
    If ($Return -eq $False)
    {
        $Return = Test-Item -ItemPath ("HKCU:\Software\Microsoft\Installer\Products\$($Value)")
    }
    Return $Return
}
