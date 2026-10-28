# Minimal PDF text extractor (FlateDecode streams, literal and hex strings). No external tools needed.
param([Parameter(Mandatory)][string]$Path)
Add-Type -AssemblyName System.IO.Compression
$b = [IO.File]::ReadAllBytes((Resolve-Path $Path))
$l = [Text.Encoding]::GetEncoding(28591)
$t = $l.GetString($b)
$all = New-Object Text.StringBuilder
foreach ($m in [regex]::Matches($t, 'stream\r?\n')) {
  if ($m.Index -ge 3 -and $t.Substring($m.Index - 3, 3) -eq 'end') { continue }
  $st = $m.Index + $m.Length
  $en = $t.IndexOf('endstream', $st)
  if ($en -lt 0) { continue }
  try {
    $ms = New-Object IO.MemoryStream($b, ($st + 2), ($en - $st - 2))
    $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
    [void]$all.Append((New-Object IO.StreamReader($ds, $l)).ReadToEnd())
  } catch {}
}
$s = $all.ToString()
$sb = New-Object Text.StringBuilder
foreach ($bt in [regex]::Matches($s, 'BT(.*?)ET', 'Singleline')) {
  foreach ($x in [regex]::Matches($bt.Groups[1].Value, '\(((?:\\.|[^\\)])*)\)|<([0-9A-Fa-f\s]+)>')) {
    if ($x.Groups[1].Success) { [void]$sb.Append(($x.Groups[1].Value -replace '\\(.)', '$1')) }
    else {
      $hex = $x.Groups[2].Value -replace '\s', ''
      for ($i = 0; $i + 1 -lt $hex.Length; $i += 2) { [void]$sb.Append([char][Convert]::ToInt32($hex.Substring($i, 2), 16)) }
    }
  }
  [void]$sb.Append(' ')
}
$text = $sb.ToString() -replace "`0", ''

# Some TCEQ PDFs store glyph ids shifted 29 below the character codes; undo that when it reads better
$shifted = -join ($text.ToCharArray() | ForEach-Object { $c = [int]$_; if ($c -ge 3 -and $c -lt 100) { [char]($c + 29) } else { $_ } })
$score = { param($s) ([regex]::Matches($s, '(?i)\b(the|and|permit|will)\b')).Count }
if ((& $score $shifted) -gt (& $score $text)) { $text = $shifted -replace '=', ' ' }
$text -replace '\s+', ' '
