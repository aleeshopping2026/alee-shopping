$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$imgDir = Join-Path $root 'images'
New-Item -ItemType Directory -Force -Path $imgDir | Out-Null
$urls = @(
  'https://media.selfshop.com.bd/products/vendor/8611032e4b5e2e262bf8c4b9828ecde8_6v7CqzLi.png',
  'https://media.bunnings.com.au/api/public/content/e05cfaf2cf4c40ef9c0f61ee07da9e93?t=w700dpr1&v=24e05cad',
  'https://www.soniclever.com/upload/photo/169277966923234900210.jpg',
  'https://udqwwfkqmvqnzhmcnaqy.supabase.co/storage/v1/object/public/product-images/products/original-m25-2-in-1-detachable-wireless-speaker-dual-stereo-bluetooth-sound-with-rgb-led-lights/39af8145-9529-4111-b8bc-06b92dee74e8.webp',
  'https://images.priceoye.pk/ultra-3-7in1-smart-watch-pakistan-priceoye-pnbvg.jpg',
  'https://static-01.daraz.com.bd/p/4c5296a046cae2a0afbad5e896111326.jpg',
  'https://www.mynavyexchange.com/products/images/large/14872612_001.jpg',
  'https://content.propertyroom.com/listings/sellers/seller600031/images/origimgs/600031_3110202214552999.jpg',
  'https://img.drz.lazcdn.com/g/kf/S7fd95a2304854f9983eb2f47dad7d227O.jpg_720x720q80.jpg_.webp',
  'https://p.globalsources.com/IMAGES/PDT/B5926620477/power-banks.jpg',
  'https://static-01.daraz.lk/p/4d95f462e8ec89d43f5228b40288e9a7.jpg',
  'https://img.bobshop.co.za/f_auto%2Cq_auto%3Aeco%2Cd_notfound.png/user/5126137/22_rkbSG5YFr0.jpg',
  'https://bizweb.dktcdn.net/thumb/1024x1024/100/425/492/products/cap-sac-nhanh-3-dau-baseus-flash-series-one-for-three-fast-charging-data-cable-usb-to-m-plus-l-plus-c-100w-cass030001-5.jpg?v=1696326260340',
  'https://img.drz.lazcdn.com/static/lk/p/f6488887e4b215a6b616bbfa55542da4.png_720x720q80.png_.webp',
  'https://ttec.gr/images/detailed/9/ttec_PowerSlim_Trio_LCD_20.000mAh_PD_22%2C5W_Dahili_Kablolu_Tasinabilir_Sarj_Aleti__Powerbank104396.jpg',
  'https://static2.kapruka.com/product-image/width%3D700%2Cquality%3D93%2Cf%3Dauto/https%3A//partnercentral.kapruka.com/kapruka-pc/assets/images/product/pc00670/elec0v1905p00528/elec0v1905p00528_1.jpg'
)
$i=1
foreach($u in $urls){
  try {
    $ext = [IO.Path]::GetExtension(([Uri]$u).AbsolutePath)
    if([string]::IsNullOrWhiteSpace($ext) -or $ext.Length -gt 5){$ext='.jpg'}
    $out = Join-Path $imgDir (('web_{0:00}' -f $i) + $ext)
    Invoke-WebRequest -Uri $u -OutFile $out
    Write-Host "Downloaded $out"
  } catch { Write-Warning "Could not download $u" }
  $i++
}
Write-Host "Done. Open index.html after downloads finish."
