# Monthly update: download the TCEQ and Comptroller lists, find entries not seen before,
# and write a review file listing the ones that look relevant. Nothing is added to the site
# automatically: a person reviews review/candidates.md and edits site/data/sites.json.
#
# Runs on Windows PowerShell 5.1 and PowerShell 7 (GitHub Actions). Run from the repo root.
param([switch]$Init)   # -Init: record everything currently listed as seen, without writing candidates

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
New-Item -ItemType Directory -Force data, data-raw, data-raw/pls, review | Out-Null

$today = (Get-Date).ToString('yyyy-MM-dd')
$ua = @{ 'User-Agent' = 'dfw-power-tracker (UT Dallas student project)' }
$tceqList = 'https://www.tceq.texas.gov/assets/public/permitting/air/reports/applications/nsr-pending-permits.html'
$comptrollerList = 'https://comptroller.texas.gov/taxes/data-centers/data-center-lists.php'
$plsBase = 'https://www.tceq.texas.gov/downloads/permitting/air/bilingual/pending-permit-notices'

# Counties of the DFW area and its edges, as written in TCEQ summaries
$dfwCounties = 'Dallas|Tarrant|Collin|Denton|Ellis|Kaufman|Rockwall|Johnson|Parker|Wise|Hood|Hill|Navarro|Hunt|Grayson|Bosque|Somervell|Palo Pinto|Cooke|Fannin|Van Zandt|Henderson'
$dfwNames = 'DFW|Dallas|Fort Worth|Irving|Richardson|Plano|Allen|Frisco|McKinney|Garland|Denton|Lewisville|Carrollton|Lancaster|Red Oak|Wilmer|Hutchins|Royse|Rockwall|Mesquite|Arlington|Grand Prairie|Midlothian|Waxahachie|Ennis|Corsicana|Bosque|Princeton|Celina|Sherman|Hillsboro|Hubbard|Cleburne|Weatherford|Mansfield|Forney|Terrell'
$dcWords = 'data center|datacenter|data-center|hyperscale|server|computing|compute|digital|cloud'

Invoke-WebRequest -UseBasicParsing $tceqList -OutFile data-raw/tceq.html -Headers $ua
Invoke-WebRequest -UseBasicParsing $comptrollerList -OutFile data-raw/comptroller.html -Headers $ua
& "$PSScriptRoot/parse-tceq.ps1" -In data-raw/tceq.html -Out data-raw/tceq-all.csv | Write-Host
& "$PSScriptRoot/parse-comptroller.ps1" -In data-raw/comptroller.html -Out data-raw/comptroller-all.csv | Write-Host
$tceq = Import-Csv data-raw/tceq-all.csv
$comp = Import-Csv data-raw/comptroller-all.csv
if ($tceq.Count -lt 50 -or $comp.Count -lt 50) { throw "A source list came back short (TCEQ $($tceq.Count), Comptroller $($comp.Count)); the page layout may have changed." }

# Keys already reviewed or recorded in earlier runs
$seenPath = 'data/seen.json'
$seen = @{ tceq = @(); comptroller = @() }
if (Test-Path $seenPath) {
  $j = Get-Content $seenPath -Raw | ConvertFrom-Json
  $seen.tceq = @($j.tceq); $seen.comptroller = @($j.comptroller)
}
$tceqKey = { param($r) ($r.Permit -split ',')[0].Trim() }
$compKey = { param($r) "$($r.Name)|$($r.Effective)" }

$newTceq = @($tceq | Where-Object { $seen.tceq -notcontains (& $tceqKey $_) })
$newComp = @($comp | Where-Object { $seen.comptroller -notcontains (& $compKey $_) })
Write-Host "New since last run: TCEQ $($newTceq.Count), Comptroller $($newComp.Count)"

$candidates = @()
if (-not $Init) {
  foreach ($r in $newTceq) {
    $permit = & $tceqKey $r
    $pdf = "data-raw/pls/$permit.pdf"
    $summary = ''
    try {
      if (-not (Test-Path $pdf)) { Invoke-WebRequest -UseBasicParsing "$plsBase/$permit-pls-english.pdf" -OutFile $pdf -Headers $ua -TimeoutSec 60 }
      $summary = & "$PSScriptRoot/pdf-text.ps1" $pdf
    } catch { }
    $names = "$($r.Applicant) $($r.Facility)"
    $isDc = ($summary -match "(?i)$dcWords") -or ($names -match "(?i)$dcWords")
    $isPower = ($summary -match '(?i)generat|turbine|megawatt|power plant|electricity') -or ($names -match '(?i)power|energy center|generat')
    $inDfw = ($summary -match "(?i)\b($dfwCounties) County") -or ($names -match "(?i)\b($dfwNames)\b")
    if (-not ($isDc -or ($isPower -and $inDfw))) { continue }
    $i = $summary.IndexOf('submitted'); if ($i -lt 0) { $i = 0 }
    $candidates += [pscustomobject]@{
      source = 'tceq'; key = $permit; name = $r.Facility; who = $r.Applicant; date = $r.Received; status = $r.Status
      dataCenter = $isDc; power = $isPower; dfw = $inDfw
      excerpt = if ($summary) { $summary.Substring($i, [Math]::Min(600, $summary.Length - $i)) } else { '(no plain-language summary found)' }
      link = "$plsBase/$permit-pls-english.pdf"
    }
  }
  foreach ($r in $newComp) {
    $candidates += [pscustomobject]@{
      source = 'comptroller'; key = & $compKey $r; name = $r.Name; who = $r.Occupant; date = $r.Effective; status = "$($r.List) list"
      dataCenter = $true; power = $false; dfw = ($r.Name -match "(?i)\b($dfwNames)\b")
      excerpt = "Owner: $($r.Owner). Occupant: $($r.Occupant). Operator: $($r.Operator)."
      link = $comptrollerList
    }
  }
}

# Review file: DFW-area entries first
$ConvertToJsonDepth = 5
$candidates | Sort-Object @{ e = { -not $_.dfw } }, source | ConvertTo-Json -Depth $ConvertToJsonDepth |
  Set-Content review/candidates.json -Encoding UTF8
$md = @("# Candidates to review ($today)", '',
  "New entries since the last run that look relevant. Add the ones that belong to ``site/data/sites.json`` (set ``added`` to $today), then merge.", '')
if (-not $candidates) { $md += 'No relevant new entries this month.' }
foreach ($c in ($candidates | Sort-Object @{ e = { -not $_.dfw } }, source)) {
  $flags = @(); if ($c.dfw) { $flags += 'DFW area' }; if ($c.dataCenter) { $flags += 'data center' }; if ($c.power) { $flags += 'power' }
  $md += "## $($c.name)"
  $md += "- **Source:** $($c.source), $($c.status), $($c.date)"
  $md += "- **Who:** $($c.who)"
  $md += "- **Flags:** $($flags -join ', ')"
  $md += "- **Link:** $($c.link)"
  $md += "- $($c.excerpt)"
  $md += ''
}
$md -join "`n" | Set-Content review/candidates.md -Encoding UTF8

# Record everything listed now as seen, and stamp the check date for the site
$seen.tceq = @($seen.tceq + ($tceq | ForEach-Object { & $tceqKey $_ }) | Sort-Object -Unique)
$seen.comptroller = @($seen.comptroller + ($comp | ForEach-Object { & $compKey $_ }) | Sort-Object -Unique)
[pscustomobject]$seen | ConvertTo-Json | Set-Content $seenPath -Encoding UTF8
$tceqStamp = [regex]::Match((Get-Content data-raw/tceq.html -Raw), 'Data Updated:\s*([0-9/]+)').Groups[1].Value
[pscustomobject]@{ checked = $today; tceqDataUpdated = $tceqStamp; tceqRows = $tceq.Count; comptrollerRows = $comp.Count } |
  ConvertTo-Json | Set-Content site/data/meta.json -Encoding UTF8

Write-Host "$($candidates.Count) candidate(s) written to review/candidates.md"
