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
./scripts/sync-catalog.sh         # once after cloning; copies site/public/catalog.json in as the bundled fallback
swift test                        # core unit tests
./scripts/build-app.sh            # dist/HostBlock.app, ad-hoc signed (local dev)
./scripts/build-app.sh --release  # Developer ID signed + notarized + DMG
```

`swift run HostBlock` works for development. `--release` signs with the Developer ID identity, notarizes and staples with `notarytool`, and packages `dist/HostBlock-<version>.dmg` alongside the `latest.json` update feed.

## Uninstall

HostBlock edits `/etc/hosts` through a small root-owned helper and a scoped `/etc/sudoers.d/hostblock` rule, so it never prompts for your password. To completely remove HostBlock, run the following commands in order. It will clear HostBlock's hosts entries, then delete the helper, the rule, and app data.

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

HostBlock blocks by writing entries to your `/etc/hosts` file, which has a few inherent constraints:

- **No wildcard blocking.** A hosts file matches _exact_ hostnames, so every subdomain must be listed explicitly, and `*.example.com` isn't possible. DNS-based blockers (Pi-hole, AdGuard Home, NextDNS) can use wildcard rules; a hosts file can't. In practice the curated lists enumerate the known ad/tracker subdomains, so common cases are covered, but a brand-new subdomain won't be blocked until a list includes it.
- **Domain-level, not content-level.** Blocking is all-or-nothing per domain. HostBlock can't hide individual page elements, or block ads served from the same domain as the content you want. That's what in-browser filters like uBlock Origin do.
- **Bypassable by apps with their own resolver.** Apps that use hardcoded IPs or their own DNS-over-HTTPS/TLS resolver skip `/etc/hosts` entirely, so those requests aren't affected.
- **Large lists mean a large hosts file.** Enabling very large lists writes hundreds of thousands of entries to `/etc/hosts`. Fine on modern Macs, but worth knowing.
