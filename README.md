# TravOS onboarding

Setup scripts for a new TravOS developer or tester. Each one installs what the
role needs and is safe to run again.

This repo is public so a new machine can fetch a script before it has git or a
GitHub sign-in. Nothing here is secret. The developer script asks for the one
secret it needs while it runs.

## Developer

Windows, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-developer.ps1 | iex
```

macOS, in Terminal:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-developer.sh)"
```

It installs git, the GitHub CLI, the .NET 10 SDK, Node 24 with pnpm, Docker
Desktop, the Aspire CLI, dotnet-ef, VS Code, the Azure CLI and Claude Code. A
tool whose command already works is left alone. The script then:

- trusts the HTTPS dev certificate
- turns on long paths on Windows
- signs you in to GitHub
- clones `travos-aus-agent` into `~/src/travos-aus-agent` and runs its
  `bootstrap.sh`
- creates both portals' `config.json`
- asks for the Auth0 Management secret your lead sent you

It finishes with a checklist of anything still missing.

Already set up? Check your machine against the current requirements without
changing anything:

```powershell
$env:TRAVOS_CHECK=1; irm https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-developer.ps1 | iex
```

```sh
TRAVOS_CHECK=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-developer.sh)"
```

Set `TRAVOS_PATH` the same way to clone somewhere other than
`~/src/travos-aus-agent`. On Windows keep the path short. Some files in the
workspace are deep enough to hit the 260-character limit.

## Tester

Windows:

```powershell
irm https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-tester.ps1 | iex
```

macOS:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-tester.sh)"
```

It installs Chrome and Firefox, plus Edge on a Mac, then prints the links you
need: the QA Team board and the dev and UAT admin portals.

## Changing a script

The version requirements live in these scripts and nowhere else. The workspace
docs link here instead of listing them. When a repo moves to a new .NET, Node or
Aspire version, change it here in the same piece of work. Then run the check
mode on your own machine before opening the pull request.
