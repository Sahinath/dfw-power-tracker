# DFW Power Tracker

A public register of data center sites and on-site power filings around Dallas–Fort Worth, built from Texas Comptroller, TCEQ and ERCOT records. By Sahinath Saminadane, M.S. Energy Management, UT Dallas.

## How it is kept up to date

1. On the 1st of each month, the **Monthly update** workflow downloads the TCEQ pending air permit list and the Comptroller's qualifying data center lists, reads the plain-language summary of each new permit, and opens a pull request listing new entries that look relevant (`review/candidates.md`).
2. A person reviews that list and adds the entries that belong to `site/data/sites.json`, with `added` set to the update date.
3. Merging the pull request publishes the site through the **Publish site** workflow. Entries with the latest `added` date appear under "New since the last update".

The workflow can also be started by hand from the Actions tab (**Run workflow**).

## Layout

| Path | What it holds |
| --- | --- |
| `site/index.html` | The page |
| `site/data/sites.json` | The curated site register |
| `site/data/meta.json` | Date of the last check |
| `site/tiles/` | Map tiles for offline previews (© OpenStreetMap contributors) |
| `scripts/update.ps1` | Monthly fetch and candidate detection |
| `data/seen.json` | Entries already reviewed, so they are not listed again |

## Run locally

```powershell
./scripts/update.ps1
```

Works with Windows PowerShell 5.1 and PowerShell 7.

## Sources

- Texas Comptroller, [Qualifying Data Center lists](https://comptroller.texas.gov/taxes/data-centers/data-center-lists.php)
- TCEQ, [Pending NSR air permit applications](https://www.tceq.texas.gov/assets/public/permitting/air/reports/applications/nsr-pending-permits.html)
- ERCOT, [Large Load Update, April 2026](https://www.ercot.com/files/docs/2026/04/01/ERCOT_LargeLoad_Update_April2026_B-C_-Hearing.pdf)
- Map data © OpenStreetMap contributors
