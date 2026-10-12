#!/bin/bash
# TravOS developer setup for macOS. In Terminal:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TravOS-AUS/onboarding/main/setup-developer.sh)"
#
# Safe to re-run: every step checks before it acts.
#   Check only:       TRAVOS_CHECK=1 /bin/bash -c "$(curl ...)"
#   Clone elsewhere:  TRAVOS_PATH=~/code/travos-aus-agent /bin/bash -c "$(curl ...)"
#
# Written for the bash 3.2 macOS ships. Prompts read /dev/tty, so they work
# however the script was started.
set -u

REPO_PATH="${TRAVOS_PATH:-$HOME/src/travos-aus-agent}"
APPHOST="$REPO_PATH/repos/travos-aus-apphost/src/TravOS.Aus.AppHost"
PORTALS="$REPO_PATH/projects/travos-agent/repos/travos-web/public $REPO_PATH/projects/travos-agent/repos/travos-admin-web/public"

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
has() { command -v "$1" >/dev/null 2>&1; }

# Adds a line to ~/.zprofile once and applies it to this run too.
profile() {
  grep -qxF "$1" "$HOME/.zprofile" 2>/dev/null || echo "$1" >>"$HOME/.zprofile"
  eval "$1"
}

secret_set() {
  [ -d "$APPHOST" ] && dotnet user-secrets list --project "$APPHOST" 2>/dev/null |
    grep -q '^Parameters:auth0-management-secret'
}
configs_present() {
  for dir in $PORTALS; do [ -f "$dir/config.json" ] || return 1; done
}

FAILED=0
row() { # row <name> <command...>
  name=$1; shift
  if "$@" >/dev/null 2>&1; then printf '  \033[32mok   %s\033[0m\n' "$name"
  else printf '  \033[33mFIX  %s\033[0m\n' "$name"; FAILED=$((FAILED + 1)); fi
}
check() {
  step 'Checking'
  FAILED=0
  row 'git' has git
  row 'gh signed in' gh auth status
  row '.NET SDK 10' sh -c 'dotnet --list-sdks | grep -q "^10\."'
  row 'Node 24' sh -c 'node --version | grep -q "^v24\."'
  row 'pnpm' has pnpm
  row 'Docker running' docker info
  row 'Aspire CLI' has aspire
  row 'dotnet-ef' sh -c 'dotnet tool list -g | grep -q "^dotnet-ef "'
  row 'HTTPS dev cert' dotnet dev-certs https --check --trust
  row 'workspace cloned' test -f "$REPO_PATH/bootstrap.sh"
  row 'portal config.json' configs_present
  row 'Auth0 secret' secret_set
}

# Homebrew and the profile lines first, so a check-only run finds the tools too.
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && BREW=$b && break; done
if [ -z "${BREW:-}" ] && [ -z "${TRAVOS_CHECK:-}" ]; then
  step 'Installing Homebrew'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && BREW=$b && break; done
fi
if [ -n "${BREW:-}" ]; then
  profile "eval \"\$($BREW shellenv)\""
  # Only when Homebrew's Node is the one this script installed, so it never goes
  # in front of an nvm or fnm Node already on the machine.
  [ -d "$($BREW --prefix)/opt/node@24/bin" ] && profile "export PATH=\"$($BREW --prefix)/opt/node@24/bin:\$PATH\""
fi
profile 'export DOTNET_ROOT="$HOME/.dotnet"'
profile 'export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"'

if [ -n "${TRAVOS_CHECK:-}" ]; then check; exit "$FAILED"; fi
[ -n "${BREW:-}" ] || { echo 'Homebrew did not install. Install it from https://brew.sh, then re-run.'; exit 1; }

step 'Installing tools with Homebrew'
# Skipped when the command already works, however it was installed: a second
# Node beside nvm's, or a cask over a hand-installed Docker.app, is worse than none.
for pair in git:git gh:gh node:node@24; do
  has "${pair%%:*}" && echo "  ${pair#*:} already installed" || brew install "${pair#*:}"
done
for pair in docker:docker-desktop code:visual-studio-code claude:claude-code az:azure-cli; do
  has "${pair%%:*}" && echo "  ${pair#*:} already installed" || brew install --cask "${pair#*:}"
done
[ -d "$(brew --prefix)/opt/node@24/bin" ] && profile "export PATH=\"$(brew --prefix)/opt/node@24/bin:\$PATH\""

# .NET comes from Microsoft's installer rather than the dotnet-sdk cask, because
# the cask follows the newest major and the repos target net10.0.
if ! dotnet --list-sdks 2>/dev/null | grep -q '^10\.'; then
  step 'Installing .NET SDK 10'
  curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
fi

has corepack || npm install -g corepack
has pnpm || corepack enable pnpm

step '.NET tools and HTTPS certificate'
# Aspire also has a native installer (~/.aspire/bin), so ask for the command.
has aspire && echo '  aspire already installed' || dotnet tool install -g aspire.cli
dotnet tool list -g | grep -q '^dotnet-ef ' && echo '  dotnet-ef already installed' || dotnet tool install -g dotnet-ef
dotnet dev-certs https --check --trust >/dev/null 2>&1 || dotnet dev-certs https --trust

step 'GitHub sign-in'
gh auth status >/dev/null 2>&1 ||
  gh auth login --hostname github.com --git-protocol https --web --scopes project </dev/tty
gh auth setup-git

step "Workspace at $REPO_PATH"
[ -f "$REPO_PATH/bootstrap.sh" ] || gh repo clone TravOS-AUS/travos-aus-agent "$REPO_PATH"
(cd "$REPO_PATH" && BOOTSTRAP_FORCE=1 ./bootstrap.sh)

for dir in $PORTALS; do
  if [ -f "$dir/config.example.json" ] && [ ! -f "$dir/config.json" ]; then
    cp "$dir/config.example.json" "$dir/config.json"
    echo "  created $dir/config.json"
  fi
done

if [ -d "$APPHOST" ] && ! secret_set; then
  step 'Auth0 Management secret'
  printf 'Paste the secret your lead sent you (Enter to skip): '
  read -rs secret </dev/tty; echo
  if [ -n "$secret" ]; then
    dotnet user-secrets set 'Parameters:auth0-management-secret' "$secret" --project "$APPHOST" >/dev/null
  else
    echo "  skipped. Later: dotnet user-secrets set \"Parameters:auth0-management-secret\" \"<secret>\" --project \"$APPHOST\""
  fi
fi

check
cat <<EOF

Left to do by hand:
  1. Open Docker Desktop once (open -a Docker) and accept its terms.
  2. Ask your lead for a travos-dev Auth0 account.
  3. Only if you will set up Auth0 environments: brew install auth0
  4. Open a new terminal, then start the stack: cd "$REPO_PATH" && aspire run
  5. Start Claude Code from the same folder: claude

$FAILED item(s) above need fixing. Re-run this script after fixing them.
EOF
