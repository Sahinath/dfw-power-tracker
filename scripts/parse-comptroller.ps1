# Parse the Texas Comptroller "Qualifying Data Center" lists into CSV rows.
param([string]$In = "data-raw/comptroller.html", [string]$Out = "data-raw/comptroller-all.csv")

$h = (Get-Content $In -Raw) -replace '\r?\n', ' '
# The phrase also appears in the intro paragraph; the section heading is the last occurrence
$largeStart = $h.LastIndexOf('Large Data Center Projects')

function Clean($s) {
  $items = [regex]::Matches($s, '<li>(.*?)</li>') | ForEach-Object { $_.Groups[1].Value.Trim() }
  if ($items) { return ($items -join '; ') }
  return (($s -replace '<[^>]+>', '') -replace '\s+', ' ').Trim()
}

$rows = foreach ($tr in [regex]::Matches($h, '<tr[^>]*>\s*<th scope="row">(.*?)</th>(.*?)</tr>')) {
  $tds = [regex]::Matches($tr.Groups[2].Value, '<td[^>]*>(.*?)</td>') | ForEach-Object { $_.Groups[1].Value }
  if ($tds.Count -lt 8) { continue }
  [pscustomobject]@{
    List      = if ($largeStart -gt 0 -and $tr.Index -gt $largeStart) { 'Large' } else { 'Standard' }
    Name      = Clean $tr.Groups[1].Value
    Effective = Clean $tds[0]
    Owner     = Clean $tds[1]
    Occupant  = Clean $tds[3]
    Operator  = Clean $tds[5]
    ExemptEnd = Clean $tds[7]
  }
}
$rows | Export-Csv $Out -NoTypeInformation -Encoding UTF8
"{0} rows ({1} large)" -f $rows.Count, ($rows | Where-Object List -eq 'Large').Count
