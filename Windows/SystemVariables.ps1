$AssetTag = Read-Host "Enter asset tag: "
$TopsNum = Read-Host "Enter Tops#: "
$SellerCode = Read-Host "Enter seller code: "
$VenueCode = Read-Host "Enter venue code:"

$DeviceName = "TCW11${VenueCode}-${AssetTag}"
Rename-Computer -NewName $DeviceName

[Environment]::SetEnvironmentVariable('TEG_ASSET_TAG', $AssetTag, 'Machine')
[Environment]::SetEnvironmentVariable('TEG_TOPS_NUM', $TopsNum, 'Machine')
[Environment]::SetEnvironmentVariable('TEG_SELLER_CODE', $SellerCode, 'Machine')
[Environment]::SetEnvironmentVariable('TEG_SITE_CODE', $SiteCode, 'Machine')