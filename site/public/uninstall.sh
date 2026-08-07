#!/bin/bash
# HostBlock uninstaller.
#
#   curl -fsSL https://hostblock.app/uninstall.sh | bash
#
# Releases the license key, clears HostBlock's hosts entries, then removes the
# privileged helper, its sudoers rule, and app data.
#
# Releasing the key matters: a Personal license is limited to 1 device, so tearing
# HostBlock out by hand leaves the key stuck at 1 use and it won't activate again.
#
# Flags:
#   --keep-license   skip the release step (key stays counted against this device)

set -uo pipefail

HELPER="/Library/PrivilegedHelperTools/com.hostblock.helper"
SUDOERS="/etc/sudoers.d/hostblock"
SUPPORT="$HOME/Library/Application Support/HostBlock"
LICENSE="$SUPPORT/license.json"
DECREMENT_URL="https://license-decrement.hostblock.app"

keep_license=false
for arg in "$@"; do
  case "$arg" in
    --keep-license) keep_license=true ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/, ""); print}' "$0"; exit 0 ;;
    *) echo "uninstall.sh: unknown option '$arg'" >&2; exit 64 ;;
  esac
done

# Quit first so the running app can't rewrite its config after the data is deleted.
osascript -e 'quit app "HostBlock"' >/dev/null 2>&1

# 1) Release the license's uses slot, before touching anything else, so a failure
#    here leaves the install intact and retryable.
if [ "$keep_license" = false ] && [ -f "$LICENSE" ]; then
  # plutil reads JSON and ships with macOS, so no jq/python dependency.
  key=$(plutil -extract licenseKey raw -o - "$LICENSE" 2>/dev/null)
  if [[ "$key" =~ ^[A-Za-z0-9-]+$ ]]; then
    echo "Releasing license $key..."
    response=$(curl -sS -m 15 -X POST "$DECREMENT_URL" \
      -H "Content-Type: application/json" \
      -d "{\"license_key\":\"$key\"}" 2>/dev/null)
    case "$response" in
      *'"success":true'*)
        echo "  Released. This key can be activated again."
        ;;
      *invalid_license*)
        echo "  Gumroad doesn't recognize this key, so there's nothing to release."
        ;;
      *)
        echo "uninstall.sh: couldn't reach the license server, so nothing was removed." >&2
        echo "Check your connection and re-run, or re-run with --keep-license." >&2
        exit 1
        ;;
    esac
  fi
fi

# 2) Clear the HostBlock section from /etc/hosts. The sudoers rule makes this
#    passwordless while it still exists.
if [ -x "$HELPER" ]; then
  echo "Clearing hosts entries..."
  sudo "$HELPER" remove || {
    echo "uninstall.sh: the helper failed to clear /etc/hosts." >&2
    exit 1
  }
fi

# 3) The helper and its rule. This is the one step that asks for a password.
if [ -e "$HELPER" ] || [ -e "$SUDOERS" ]; then
  echo "Removing the privileged helper (this asks for your password)..."
  sudo rm -f "$HELPER" "$SUDOERS" || exit 1
fi

# 4) Config, license, caches, staged hosts block.
rm -rf "$SUPPORT"

echo
echo "HostBlock is uninstalled. Drag HostBlock out of Applications to finish."
