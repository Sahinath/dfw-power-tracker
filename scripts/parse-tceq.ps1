# Parse the TCEQ "Pending Applications: New Source Review Permits" page into CSV rows.
param([string]$In = "data-raw/tceq.html", [string]$Out = "data-raw/tceq-all.csv")

$h = (Get-Content $In -Raw) -replace '\r?\n', ' '

# Section anchors look like id/name="NSR Case-by-Case Air Permits-A"; track the latest section before each row
$sections = [regex]::Matches($h, '(?:name|id)="((?:NSR Case-by-Case Air Permits|Concrete Batch Plant Standard Permits|Standard Permits)(?:-[A-Z0-9])?)"') |
  ForEach-Object { [pscustomobject]@{ Pos = $_.Index; Name = ($_.Groups[1].Value -replace '-[A-Z0-9]$', '') } }

$rows = foreach ($tr in [regex]::Matches($h, '<tr>(.*?)</tr>')) {
  $tds = [regex]::Matches($tr.Groups[1].Value, '<td[^>]*>(.*?)</td>') | ForEach-Object { $_.Groups[1].Value }
  if ($tds.Count -ne 5) { continue }
  $sec = ($sections | Where-Object { $_.Pos -lt $tr.Index } | Select-Object -Last 1).Name
  $notice = [regex]::Match($tds[0], '#(\d+)"').Groups[1].Value
  $doc = [regex]::Match($tds[4], 'href="([^"]+)"').Groups[1].Value -replace '\s', ''
  [pscustomobject]@{
    Section   = $sec
    Applicant = (($tds[0] -split '<br')[0]).Trim()
    Facility  = ($tds[1] -replace '<[^>]+>', '').Trim()
    Permit    = ($tds[2] -replace '<[^>]+>', '').Trim()
    Received  = ($tds[3] -replace '<[^>]+>', '').Trim()
    Status    = (($tds[4] -replace '<[^>]+>', '') -replace '\s+', ' ').Trim()
    NoticeId  = $notice
    DocUrl    = if ($doc) { "https://www.tceq.texas.gov$doc" } else { "" }
  }
}
$rows | Export-Csv $Out -NoTypeInformation -Encoding UTF8
"{0} rows" -f $rows.Count
$rows | Group-Object Section | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
