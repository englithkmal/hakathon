param(
    [string]$Source  = "assets/branding/app_icon.png",
    [string]$ResRoot = "android/app/src/main/res",
    [int]$WhiteThreshold = 235
)

Add-Type -AssemblyName System.Drawing

# 1) Load the source as a Bitmap so we can read individual pixels.
$srcImg = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
$src = New-Object System.Drawing.Bitmap $srcImg
$srcImg.Dispose()

$srcW = $src.Width
$srcH = $src.Height

# 2) Convert it into a pure white-on-transparent silhouette:
#    - Pixels brighter than $WhiteThreshold (the white background of app_icon)
#      are forced fully transparent.
#    - All remaining opaque pixels are recoloured to pure white, keeping their
#      original alpha so antialiased edges stay smooth.
$silhouette = New-Object System.Drawing.Bitmap $srcW, $srcH
for ($y = 0; $y -lt $srcH; $y++) {
    for ($x = 0; $x -lt $srcW; $x++) {
        $px = $src.GetPixel($x, $y)
        if ($px.A -eq 0) {
            $silhouette.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            continue
        }
        if ($px.R -ge $WhiteThreshold -and $px.G -ge $WhiteThreshold -and $px.B -ge $WhiteThreshold) {
            $silhouette.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
        } else {
            $newColor = [System.Drawing.Color]::FromArgb($px.A, 255, 255, 255)
            $silhouette.SetPixel($x, $y, $newColor)
        }
    }
}
$src.Dispose()

# 3) Center-crop to a square so Android renders it correctly.
$side = [Math]::Min($silhouette.Width, $silhouette.Height)
$xOff = [int](($silhouette.Width  - $side) / 2)
$yOff = [int](($silhouette.Height - $side) / 2)

$square = New-Object System.Drawing.Bitmap $side, $side
$g = [System.Drawing.Graphics]::FromImage($square)
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$rect    = New-Object System.Drawing.Rectangle 0, 0, $side, $side
$srcRect = New-Object System.Drawing.Rectangle $xOff, $yOff, $side, $side
$g.DrawImage($silhouette, $rect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$silhouette.Dispose()

# 4) Resize to each Android density bucket and save under res/drawable-*/.
$sizes = @{
    "drawable-mdpi"    = 24
    "drawable-hdpi"    = 36
    "drawable-xhdpi"   = 48
    "drawable-xxhdpi"  = 72
    "drawable-xxxhdpi" = 96
}

foreach ($entry in $sizes.GetEnumerator()) {
    $folder = Join-Path $ResRoot $entry.Key
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Force -Path $folder | Out-Null }
    $size = [int]$entry.Value
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g2 = [System.Drawing.Graphics]::FromImage($bmp)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g2.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g2.DrawImage($square, 0, 0, $size, $size)
    $g2.Dispose()
    $outPath = Join-Path $folder "ic_stat_notification.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Wrote $outPath ($size x $size)"
}

$square.Dispose()
Write-Host "Done."
