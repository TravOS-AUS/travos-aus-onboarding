#!/bin/bash
# TravOS tester setup for macOS. In Terminal:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TravOS-AUS/travos-aus-onboarding/main/setup-tester.sh)"
#
# Installs Chrome, Firefox and Edge; Safari ships with macOS. Safe to re-run.
set -u

for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && BREW=$b && break; done
if [ -z "${BREW:-}" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && BREW=$b && break; done
fi
[ -n "${BREW:-}" ] || { echo 'Homebrew did not install. Install it from https://brew.sh, then re-run.'; exit 1; }

"$BREW" install --cask google-chrome firefox microsoft-edge

cat <<'EOF'

Bookmark these:
  QA Team board (your test passes):  https://github.com/orgs/TravOS-AUS/projects/1/views/12
  Admin portal, dev:                 https://dev.admin.travos.com.au
  Admin portal, UAT:                 https://uat.admin.travos.com.au
  Tenant portal:                     your lead sends the link for the TMC you are testing
EOF
