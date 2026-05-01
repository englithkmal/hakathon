param(
    [string]$Source       = "assets/branding/app_icon.png",
    [string]$Destination  = "assets/branding/app_icon.png",
    [int]$WhiteThreshold  = 240,
    [double]$PaddingRatio = 0.10  # 10% breathing room around the icon
)

Add-Type -AssemblyName System.Drawing

$srcImg = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
$src = New-Object System.Drawing.Bitmap $srcImg
$srcImg.Dispose()

$srcW = $src.Width
$srcH = $src.Height

# 1) Find the bounding box of "real content" — pixels that are neither
#    transparent nor pure-white (the rounded white background tile is treated
#    the same as white padding so it gets cropped away too).
$minX = $srcW; $minY = $srcH; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $srcH; $y++) {
    for ($x = 0; $x -lt $srcW; $x++) {
        $px = $src.GetPixel($x, $y)
        if ($px.A -lt 30) { continue }
        $isWhiteish = ($px.R -ge $WhiteThreshold -and $px.G -ge $WhiteThreshold -and $px.B -ge $WhiteThreshold)
        if ($isWhiteish) { continue }
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
    }
}

if ($maxX -lt 0 -or $maxY -lt 0) {
    Write-Error "No non-white content detected in source image."
    exit 1
}

$contentW = $maxX - $minX + 1
$contentH = $maxY - $minY + 1
$contentSide = [Math]::Max($contentW, $contentH)

# 2) Add padding so the icon doesn't touch the canvas edges.
$padding = [int]($contentSide * $PaddingRatio)
$canvasSide = $contentSide + ($padding * 2)

# 3) Center the cropped content on a transparent square canvas.
$out = New-Object System.Drawing.Bitmap $canvasSide, $canvasSide
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
# Fill background fully transparent.
$g.Clear([System.Drawing.Color]::Transparent)

$dstX = [int](($canvasSide - $contentW) / 2)
$dstY = [int](($canvasSide - $contentH) / 2)
$dstRect = New-Object System.Drawing.Rectangle $dstX, $dstY, $contentW, $contentH
$srcRect = New-Object System.Drawing.Rectangle $minX, $minY, $contentW, $contentH
$g.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$src.Dispose()

$out.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()

Write-Host ("Source bbox: ({0},{1}) -> ({2},{3}) content {4}x{5}" -f $minX, $minY, $maxX, $maxY, $contentW, $contentH)
Write-Host ("Saved cropped square: {0}x{0} -> {1}" -f $canvasSide, $Destination)
