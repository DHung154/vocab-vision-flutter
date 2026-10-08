param([Parameter(Mandatory = $true)][string]$LogoPath)

# Scale and pad the transparent master into Android's density-specific canvases.
Add-Type -AssemblyName System.Drawing
$projectPath = Split-Path -Parent $PSScriptRoot
$resourcePath = Join-Path $projectPath 'android/app/src/main/res'
$brandPath = Join-Path $projectPath 'assets/brand'
New-Item -ItemType Directory -Force -Path $brandPath | Out-Null
Copy-Item -LiteralPath $LogoPath -Destination (Join-Path $brandPath 'vocab_vision_logo.png')
$master = [System.Drawing.Image]::FromFile($LogoPath)

function Save-BrandCanvas([string]$Destination, [int]$Size, [int]$MarkSize, [bool]$Solid) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($(if ($Solid) { [System.Drawing.Color]::FromArgb(255,255,248,237) } else { [System.Drawing.Color]::Transparent }))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $offset = [int](($Size - $MarkSize) / 2)
    $graphics.DrawImage($master, $offset, $offset, $MarkSize, $MarkSize)
    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

foreach ($entry in @(@('mdpi',1), @('hdpi',1.5), @('xhdpi',2), @('xxhdpi',3), @('xxxhdpi',4))) {
    $density = $entry[0]
    $scale = [double]$entry[1]
    Save-BrandCanvas (Join-Path $resourcePath "mipmap-$density/ic_launcher.png") ([int](48*$scale)) ([int](44*$scale)) $true
    Save-BrandCanvas (Join-Path $resourcePath "drawable-$density/ic_launcher_foreground.png") ([int](108*$scale)) ([int](76*$scale)) $false
    Save-BrandCanvas (Join-Path $resourcePath "drawable-$density/splash_logo.png") ([int](288*$scale)) ([int](180*$scale)) $false
    Save-BrandCanvas (Join-Path $resourcePath "drawable-$density/launch_logo.png") ([int](180*$scale)) ([int](180*$scale)) $false
}
$master.Dispose()
