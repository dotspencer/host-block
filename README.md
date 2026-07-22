# HostBlock

A lightweight native macOS menu bar app for family sysadmins: hosts-file domain
blocking for non-technical family members, then forget about it.

- Curated blocklist catalog (ads, trackers, malware, NSFW) plus custom lists by URL. Domain lists, hosts files, and Adblock-style lists are all parsed.
- Writes `/etc/hosts` between `#HOSTBLOCK_START`/`#HOSTBLOCK_END` as strict
  `0.0.0.0 domain` lines (deduped, validated), then flushes DNS.
- Auto-updates lists daily.
- Gumroad-licensed: Personal is free (1 device), Pro is paid (unlimited devices).

## Build

Requires macOS 13+ and the Xcode command line tools.

```sh
swift test              # core unit tests
./scripts/build-app.sh  # builds dist/HostBlock.app (ad-hoc signed)
```

`swift run HostBlock` works for development. For distribution, swap the ad-hoc
`codesign` in `scripts/build-app.sh` for a Developer ID identity and notarize.

## Gumroad

Set in `Sources/HostBlock/AppState.swift`: `gumroadProductID`, `purchaseURL`, and
`decrementEndpoint` (your license-decrement Worker URL; placeholder = disabled).

- **Product:** one product, two variants, Personal priced $0. Tier comes from the
  variant name — anything containing "Pro" is Pro, else Personal ("Family" is a
  legacy alias for Pro).
- **Device limit:** activation increments Gumroad's uses count and rejects Personal
  above 1. Removing a license calls the decrement Worker to free the slot (and only
  removes locally if that succeeds). Refunds/disputes are rejected at activation.

### Decrement Worker

`decrement_uses_count` needs your Gumroad **seller token**, which must not ship in
the app. It lives in a small Cloudflare Worker at
[`server/license-decrement`](server/license-decrement) that the app POSTs a license
key to; the Worker verifies the key before decrementing. See its README to deploy.
Until `decrementEndpoint` is set, removal still works locally.

## Privileged helper

macOS needs root to edit `/etc/hosts`. Setup installs a root-owned helper at
`/Library/PrivilegedHelperTools/com.hostblock.helper` plus a scoped
`/etc/sudoers.d/hostblock` rule, so the app runs it via `sudo -n` afterward — no
more prompts. The helper only splices the `#HOSTBLOCK_START…END` section (accepting
only strict `0.0.0.0 <domain>` lines), removes it, or flushes DNS; writes are atomic
and the rest of the file is untouched.

## Uninstall

```sh
sudo /Library/PrivilegedHelperTools/com.hostblock.helper remove
sudo rm /Library/PrivilegedHelperTools/com.hostblock.helper /etc/sudoers.d/hostblock
rm -rf ~/Library/Application\ Support/HostBlock
```

Data lives in `~/Library/Application Support/HostBlock/` (config, license, caches,
staged hosts block).

## Blocklist sources

HostBlock ships only URLs and never bundles or redistributes a list — each device
downloads directly from the source, so distribution-triggered terms (GPLv3
copyleft, MIT notice) don't apply. Still check each list's license before adding
to the default catalog, and avoid **NonCommercial (CC BY-NC)** as NC restricts
commercial _use_.
