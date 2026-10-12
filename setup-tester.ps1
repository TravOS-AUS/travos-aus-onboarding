# TravOS tester setup for Windows. In any PowerShell window:
#
#   irm https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-tester.ps1 | iex
#
# Installs Chrome and Firefox; Edge ships with Windows. Safe to re-run.
& {
    foreach ($id in 'Google.Chrome', 'Mozilla.Firefox') {
        winget list --exact --id $id --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "$id already installed"; continue }
        winget install --exact --id $id --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "$id did not install (exit $LASTEXITCODE). Install it by hand." }
    }
    Write-Host @'

Bookmark these:
  QA Team board (your test passes):  https://github.com/orgs/TravOS-AUS/projects/1/views/12
  Admin portal, dev:                 https://dev.admin.travos.com.au
  Admin portal, UAT:                 https://uat.admin.travos.com.au
  Tenant portal:                     your lead sends the link for the TMC you are testing
'@
}
