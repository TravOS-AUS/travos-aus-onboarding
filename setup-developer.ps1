# TravOS developer setup for Windows. In any PowerShell window:
#
#   irm https://raw.githubusercontent.com/TravOS-AUS/onboarding/main/setup-developer.ps1 | iex
#
# Safe to re-run: every step checks before it acts.
#   Check only:          $env:TRAVOS_CHECK=1; irm ... | iex
#   Clone elsewhere:     $env:TRAVOS_PATH='D:\src\travos-aus-agent'; irm ... | iex
#
# Settings come from environment variables rather than parameters, because
# `irm | iex` has no way to pass any. Everything runs inside one script block so
# nothing leaks into the caller's session.
& {
    $repoPath = if ($env:TRAVOS_PATH) { $env:TRAVOS_PATH } else { Join-Path $HOME 'src\travos-aus-agent' }
    $appHost = Join-Path $repoPath 'repos\travos-aus-apphost\src\TravOS.Aus.AppHost'
    $portals = 'travos-web', 'travos-admin-web' | ForEach-Object { Join-Path $repoPath "projects\travos-agent\repos\$_\public" }

    function Step($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }
    function Has($command) { [bool](Get-Command $command -ErrorAction SilentlyContinue) }
    function Refresh-Path {
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path', 'User')
    }
    function Ok([scriptblock]$test) { try { [bool](& $test) } catch { $false } }
    function LongPathsOn {
        (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction SilentlyContinue).LongPathsEnabled -eq 1
    }
    function SecretSet {
        (Test-Path $appHost) -and ((dotnet user-secrets list --project $appHost) -match '^Parameters:auth0-management-secret')
    }

    # Prints one line per requirement and returns how many need fixing.
    function Check {
        Step 'Checking'
        $rows = [ordered]@{
            'git'                   = { Has git }
            'gh signed in'          = { gh auth status *> $null; $LASTEXITCODE -eq 0 }
            '.NET SDK 10'           = { (dotnet --list-sdks) -match '^10\.' }
            'Node 24'               = { (node --version) -like 'v24.*' }
            'pnpm'                  = { Has pnpm }
            'Docker running'        = { docker info *> $null; $LASTEXITCODE -eq 0 }
            'Aspire CLI'            = { Has aspire }
            'dotnet-ef'             = { (dotnet tool list -g) -match '^dotnet-ef\s' }
            'HTTPS dev cert'        = { dotnet dev-certs https --check --trust *> $null; $LASTEXITCODE -eq 0 }
            'git core.longpaths'    = { (git config --global core.longpaths) -eq 'true' }
            'Windows long paths'    = { LongPathsOn }
            'workspace cloned'      = { Test-Path (Join-Path $repoPath 'bootstrap.sh') }
            'portal config.json'    = { -not ($portals | Where-Object { -not (Test-Path "$_\config.json") }) }
            'Auth0 secret'          = { SecretSet }
        }
        $failed = 0
        foreach ($name in $rows.Keys) {
            if (Ok $rows[$name]) { Write-Host "  ok   $name" -ForegroundColor Green }
            else { Write-Host "  FIX  $name" -ForegroundColor Yellow; $failed++ }
        }
        $failed
    }

    if ($env:TRAVOS_CHECK) { Refresh-Path; $null = Check; return }

    if (-not (Has winget)) {
        Write-Host 'winget is missing. Install "App Installer" from the Microsoft Store, then re-run.' -ForegroundColor Red
        return
    }

    Step 'Installing tools with winget'
    # ponytail: Node comes from the LTS channel, which is 24 today. When LTS moves
    # past 24, Check flags it; pin with `--version 24.x` then.
    # Skipped when the command already works, however it was installed: winget only
    # knows its own installs, and a second Node beside nvm's, or a second Claude Code
    # beside the native installer's, is worse than none.
    $packages = [ordered]@{
        'Git.Git'                    = { Has git }
        'GitHub.cli'                 = { Has gh }
        'Microsoft.DotNet.SDK.10'    = { (dotnet --list-sdks) -match '^10\.' }
        'OpenJS.NodeJS.LTS'          = { Has node }
        'Docker.DockerDesktop'       = { Has docker }
        'Microsoft.VisualStudioCode' = { Has code }
        'Microsoft.AzureCLI'         = { Has az }
        'Anthropic.ClaudeCode'       = { Has claude }
    }
    foreach ($id in $packages.Keys) {
        if (Ok $packages[$id]) { Write-Host "  $id already installed"; continue }
        winget install --exact --id $id --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "$id did not install (exit $LASTEXITCODE). Install it by hand, then re-run." }
    }
    Refresh-Path

    # One elevated window for the three machine-wide changes, and only when one is
    # still needed, so a re-run asks for nothing.
    $admin = @()
    wsl --status *> $null
    if ($LASTEXITCODE -ne 0) { $admin += 'wsl --install --no-distribution' }
    if (-not (Has pnpm)) { $admin += 'corepack enable pnpm' }
    if (-not (LongPathsOn)) {
        $admin += "New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -PropertyType DWord -Force"
    }
    if ($admin) {
        Step "Machine-wide changes (approve the admin prompt): $($admin -join '; ')"
        Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile', '-Command', ($admin -join '; ')
        Refresh-Path
    }

    Step '.NET tools, HTTPS certificate and git'
    $toolsDir = Join-Path $HOME '.dotnet\tools'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$toolsDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$toolsDir", 'User')
        Refresh-Path
    }
    # Aspire also has a native installer (~\.aspire\bin), so ask for the command.
    if (Has aspire) { Write-Host '  aspire already installed' } else { dotnet tool install -g aspire.cli }
    if ((dotnet tool list -g) -match '^dotnet-ef\s') { Write-Host '  dotnet-ef already installed' }
    else { dotnet tool install -g dotnet-ef }
    dotnet dev-certs https --check --trust *> $null
    if ($LASTEXITCODE -ne 0) { dotnet dev-certs https --trust }
    git config --global core.longpaths true

    Step 'GitHub sign-in'
    gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { gh auth login --hostname github.com --git-protocol https --web --scopes project }
    gh auth setup-git

    Step "Workspace at $repoPath"
    if (-not (Test-Path (Join-Path $repoPath 'bootstrap.sh'))) {
        gh repo clone TravOS-AUS/travos-aus-agent $repoPath
    }
    $bash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    Push-Location $repoPath
    try { $env:BOOTSTRAP_FORCE = '1'; & $bash ./bootstrap.sh } finally { Remove-Item Env:BOOTSTRAP_FORCE; Pop-Location }

    foreach ($dir in $portals) {
        if ((Test-Path "$dir\config.example.json") -and -not (Test-Path "$dir\config.json")) {
            Copy-Item "$dir\config.example.json" "$dir\config.json"
            Write-Host "  created $dir\config.json"
        }
    }

    if ((Test-Path $appHost) -and -not (SecretSet)) {
        Step 'Auth0 Management secret'
        $secure = Read-Host 'Paste the secret your lead sent you (Enter to skip)' -AsSecureString
        $secret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        if ($secret) { dotnet user-secrets set 'Parameters:auth0-management-secret' $secret --project $appHost | Out-Null }
        else { Write-Host "  skipped. Later: dotnet user-secrets set `"Parameters:auth0-management-secret`" `"<secret>`" --project `"$appHost`"" }
    }

    $failed = Check
    Write-Host @"

Left to do by hand:
  1. Restart Windows if WSL was just installed, then open Docker Desktop once and accept its terms.
  2. Ask your lead for a travos-dev Auth0 account.
  3. Only if you will set up Auth0 environments: install the Auth0 CLI, https://github.com/auth0/auth0-cli#installation
  4. Start the stack: cd "$repoPath"; aspire run
  5. Start Claude Code from the same folder: claude

$failed item(s) above need fixing. Re-run this script after fixing them.
"@
}
