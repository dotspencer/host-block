# HostBlock

A lightweight macOS menu bar app that updates your hosts file to block ads and malware system-wide.

<img height="600" alt="Screenshot 2026-08-03 at 10 41 05 AM" src="https://github.com/user-attachments/assets/7caab8cc-4a9f-4abe-8505-b6ea426529a3" />

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
./scripts/sync-catalog.sh         # once after cloning; copies site/public/catalog.json in as the bundled fallback
swift test                        # core unit tests
./scripts/build-app.sh            # dist/HostBlock.app, ad-hoc signed (local dev)
./scripts/build-app.sh --release  # Developer ID signed + notarized + DMG
```

`swift run HostBlock` works for development. `--release` signs with the Developer ID identity, notarizes and staples with `notarytool`, and packages `dist/HostBlock-<version>.dmg` alongside the `latest.json` update feed.

## Uninstall

HostBlock edits `/etc/hosts` through a small root-owned helper and a scoped `/etc/sudoers.d/hostblock` rule, so it never prompts for your password. To completely remove it:

```sh
curl -fsSL https://hostblock.app/uninstall.sh | bash
```

That releases your license key, clears HostBlock's hosts entries, then deletes the helper, the sudoers rule, and app data. Removing the helper asks for your password once. Afterwards, drag HostBlock out of Applications.

Releasing the key is the part worth not skipping: a Personal license is limited to 1 device, so a hand-rolled uninstall leaves the key stuck at 1 use and it won't activate again. If you're offline and want the key to stay counted against this device, add `--keep-license` (`| bash -s -- --keep-license`). The script is [`site/public/uninstall.sh`](site/public/uninstall.sh); the equivalent by hand is remove the license in the app first (License tab → Remove license), then:

```sh
sudo /Library/PrivilegedHelperTools/com.hostblock.helper remove
sudo rm /Library/PrivilegedHelperTools/com.hostblock.helper /etc/sudoers.d/hostblock
rm -rf ~/Library/Application\ Support/HostBlock
```

Data lives in `~/Library/Application Support/HostBlock/` (config, license, caches, staged hosts block).

## Blocklist sources

The default catalog is [`site/public/catalog.json`](site/public/catalog.json), served at [hostblock.app/catalog.json](https://hostblock.app/catalog.json) and fetched by the app on launch.

HostBlock ships only URLs and never bundles or redistributes a list. Each device downloads directly from the source, so distribution-triggered terms (GPLv3 copyleft, MIT notice) don't apply. Still check each list's license before adding to the default catalog, and avoid **NonCommercial (CC BY-NC)** as NC restricts commercial _use_.

## Known limitations

Blocking through `/etc/hosts` has a few inherent constraints:

- **No wildcard blocking.** A hosts file matches exact hostnames, so `*.example.com` isn't possible and every subdomain must be listed. The curated lists enumerate known ad/tracker subdomains, so common cases are covered, but a brand-new subdomain isn't blocked until a list adds it.
- **Domain-level, not content-level.** Blocking is all-or-nothing per domain, so it can't hide page elements or block ads served from the content's own domain. That's what in-browser filters like uBlock Origin do.
- **Bypassable by apps with their own resolver.** Apps using hardcoded IPs or their own DNS-over-HTTPS/TLS resolver skip `/etc/hosts` entirely.
- **Large lists mean a large hosts file.** Very large lists write hundreds of thousands of entries, which might potentially slow lookups on older Macs.
