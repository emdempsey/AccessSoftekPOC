$TemplateFile = 'https://raw.githubusercontent.com/emdempsey/AccessSoftekPOC/master/AccessSoftekPOC/Templates/nicupdate.json'

$interfaces = @()

$nic = New-Object System.Object
$nic | Add-Member -Type Noteproperty -Name "nicName" -Value 'stg-MFMApp-nic0'
$nic | Add-Member -Type Noteproperty -Name "subnetName" -Value 'StgApp'

$interfaces += $nic

$nic = New-Object System.Object
$nic | Add-Member -Type Noteproperty -Name "nicName" -Value 'stg-MFMApp-nic1'
$nic | Add-Member -Type Noteproperty -Name "subnetName" -Value 'StgApp'

$interfaces += $nic

$nic = New-Object System.Object
$nic | Add-Member -Type Noteproperty -Name "nicName" -Value 'stg-OrpApp-nic0'
$nic | Add-Member -Type Noteproperty -Name "subnetName" -Value 'StgApp'

$interfaces += $nic

$nic = New-Object System.Object
$nic | Add-Member -Type Noteproperty -Name "nicName" -Value 'stg-OrpApp-nic1'
$nic | Add-Member -Type Noteproperty -Name "subnetName" -Value 'StgApp'

$interfaces += $nic

$nic = New-Object System.Object
$nic | Add-Member -Type Noteproperty -Name "nicName" -Value 'stg-Web-nic0'
$nic | Add-Member -Type Noteproperty -Name "subnetName" -Value 'StgWeb'

$interfaces += $nic

$nic = New-Object System.Object
$nic | Add-Member -Type Noteproperty -Name "nicName" -Value 'stg-Web-nic0'
$nic | Add-Member -Type Noteproperty -Name "subnetName" -Value 'StgWeb'

$interfaces += $nic

foreach($interface in $interfaces)
{
	New-AzureResourceGroup -Name 'macResourceGroup' -Location 'West US' -TemplateFile $TemplateFile -Verbose -nicName $interface.nicName -subnetName $interface.subnetName
}