# Download a small set of OpenStreetMap tiles for the DFW area so the map works without live tile access.
# Keep this one-time and small: the OSM tile policy forbids bulk downloads. The page restyles them per theme with CSS filters.
param(
  [double]$North = 33.40, [double]$South = 31.70, [double]$West = -97.95, [double]$East = -96.10,
  [int[]]$Zooms = @(8, 9, 10), [string]$Out = "site\tiles"
)
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
function TileX($lon, $z) { [math]::Floor(($lon + 180) / 360 * [math]::Pow(2, $z)) }
function TileY($lat, $z) {
  $r = $lat * [math]::PI / 180
  [math]::Floor((1 - [math]::Log([math]::Tan($r) + 1 / [math]::Cos($r)) / [math]::PI) / 2 * [math]::Pow(2, $z))
}
$n = 0
foreach ($z in $Zooms) {
  foreach ($x in (TileX $West $z)..(TileX $East $z)) {
    foreach ($y in (TileY $North $z)..(TileY $South $z)) {
      $dir = Join-Path $Out "$z\$x"
      New-Item -ItemType Directory -Force $dir | Out-Null
      $file = Join-Path $dir "$y.png"
      if (-not (Test-Path $file)) {
        Invoke-WebRequest -UseBasicParsing "https://tile.openstreetmap.org/$z/$x/$y.png" -OutFile $file -Headers @{ 'User-Agent' = 'dfw-power-tracker/0.1 (UT Dallas student project)' }
        Start-Sleep -Milliseconds 300
      }
      $n++
    }
  }
}
"$n tiles"
