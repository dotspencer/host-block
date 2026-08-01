# HostBlock

A lightweight menu bar app that updates your hosts file to block ads, trackers, and malware across your entire Mac.

<img height="600" alt="Screenshot 2026-07-29 at 9 23 56 PM" src="https://github.com/user-attachments/assets/08274062-0973-477f-9ba0-b94cbcab48d8" />

Download from homepage: https://hostblock.app (or from [releases](https://github.com/dotspencer/host-block/releases))

Get a license: https://smithlabs.gumroad.com/l/host-block
<br/>Personal is free (1 device), Pro is paid (unlimited devices)

- A few default blocklists (ads, trackers, malware, NSFW) plus you can add custom lists by URL. Domain lists, hosts files, and Adblock-style lists are all parsed.
- Writes `/etc/hosts` between `#HOSTBLOCK_START`/`#HOSTBLOCK_END` as strict `0.0.0.0 domain` lines (deduped, validated), then flushes DNS.
- Auto-updates blocklists daily.

## Repo layout

| Directory           | What it is                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [`app/`](app)       | The macOS menu bar app (Swift / SwiftUI).                                                                                |
| [`site/`](site)     | The homepage (Astro), deployed to GitHub Pages at [hostblock.app](https://hostblock.app).                                |
| [`server/`](server) | Cloudflare Workers: [`license-decrement`](server/license-decrement) and [`download-redirect`](server/download-redirect). |

## Build

Requires macOS 13+ and the Xcode command line tools. Run from `app/`:

```sh
cd app
swift test                        # core unit tests
./scripts/build-app.sh            # dist/HostBlock.app, ad-hoc signed (local dev)
./scripts/build-app.sh --release  # Developer ID signed + notarized + DMG
```

`swift run HostBlock` works for development. `--release` signs with the Developer ID identity, notarizes and staples with `notarytool`, and packages `dist/HostBlock-<version>.dmg` alongside the `latest.json` update feed.

## Gumroad

Set in `app/Sources/HostBlock/AppState.swift`: `gumroadProductID`, `purchaseURL`, and `decrementEndpoint` (your license-decrement Worker URL; placeholder = disabled).

- **Product:** one product, two variants, Personal priced $0. Tier comes from the variant name, anything containing "Pro" is Pro, else Personal.
- **Device limit:** activation increments Gumroad's uses count and rejects Personal above 1. Removing a license calls the decrement Worker to free the slot (and only removes locally if that succeeds). Refunds/disputes are rejected at activation.

`decrement_uses_count` needs your Gumroad **seller token**, which must never ship in the app. It lives in the [`server/license-decrement`](server/license-decrement) Worker (see its README to deploy). Until `decrementEndpoint` is set, removal still works locally.

## Privileged helper

macOS needs root to edit `/etc/hosts`. Setup installs a root-owned helper at `/Library/PrivilegedHelperTools/com.hostblock.helper` plus a scoped `/etc/sudoers.d/hostblock` rule, so the app runs it via `sudo -n` afterward — no more prompts. The helper only splices the `#HOSTBLOCK_START…END` section (accepting only strict `0.0.0.0 <domain>` lines), removes it, or flushes DNS; writes are atomic and the rest of the file is untouched.

## Uninstall

```sh
sudo /Library/PrivilegedHelperTools/com.hostblock.helper remove
sudo rm /Library/PrivilegedHelperTools/com.hostblock.helper /etc/sudoers.d/hostblock
rm -rf ~/Library/Application\ Support/HostBlock
```

Data lives in `~/Library/Application Support/HostBlock/` (config, license, caches, staged hosts block).

## Blocklist sources

HostBlock ships only URLs and never bundles or redistributes a list. Each device downloads directly from the source, so distribution-triggered terms (GPLv3 copyleft, MIT notice) don't apply. Still check each list's license before adding to the default catalog, and avoid **NonCommercial (CC BY-NC)** as NC restricts commercial _use_.

## Known limitations

HostBlock blocks by writing entries to your `/etc/hosts` file, which has a few inherent constraints:

- **No wildcard blocking.** A hosts file matches _exact_ hostnames, so every subdomain must be listed explicitly — `*.example.com` isn't possible. DNS-based blockers (Pi-hole, AdGuard Home, NextDNS) can use wildcard rules; a hosts file can't. In practice the curated lists enumerate the known ad/tracker subdomains, so common cases are covered, but a brand-new subdomain won't be blocked until a list includes it.
- **Domain-level, not content-level.** Blocking is all-or-nothing per domain. HostBlock can't hide individual page elements, or block ads served from the same domain as the content you want, that's what in-browser filters like uBlock Origin do.
- **Bypassable by apps with their own resolver.** Apps that use hardcoded IPs or their own DNS-over-HTTPS/TLS resolver skip `/etc/hosts` entirely, so those requests aren't affected.
- **Large lists mean a large hosts file.** Enabling very large lists writes hundreds of thousands of entries to `/etc/hosts`. Fine on modern Macs, but worth knowing.
