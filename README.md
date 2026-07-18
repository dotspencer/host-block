# HostBlock

A lightweight native macOS menu bar app for family sysadmins: set up hosts-file
domain blocking for non-technical family members or friends, then forget about it.

- Subscribe to **oisd** blocklists (Ads/Malware/Tracking, and NSFW) with toggle switches
- Add **custom remote blocklists** by URL (a raw GitHub Gist works great) — plain
  domain lists, hosts files, and Adblock-style lists are all understood
- Writes `/etc/hosts` between `#HOSTBLOCK_START` / `#HOSTBLOCK_END` markers, with
  every line strictly formatted as `0.0.0.0 domain.com` (deduplicated, validated),
  then flushes the DNS cache
- Auto-updates lists once per day; manual **Update Now** and **Flush DNS** in the menu
- **One admin prompt, ever** — initial setup installs a small privileged helper so
  later updates never ask for a password
- Enable/disable blocking straight from the dropdown (removes the block section
  from the hosts file)
- Gumroad-licensed: free Personal (1 device) or paid Family (unlimited devices),
  with the license email shown right in the dropdown and full purchase details
  (name, email, tier, purchase date, redacted card) in the License window to
  discourage sharing keys online

## Building

Requires macOS 13+ and Xcode command line tools.

```sh
swift test              # core unit tests
./scripts/build-app.sh  # builds dist/HostBlock.app (ad-hoc signed)
```

`swift run HostBlock` also works for development (menu bar app, no Dock icon).
For distribution, replace the ad-hoc `codesign` in `scripts/build-app.sh` with a
Developer ID identity and notarize the app.

## Gumroad configuration

Edit `Sources/HostBlock/AppState.swift`:

- `AppConstants.gumroadProductID` — the `product_id` of your Gumroad product
  (enable "Generate a unique license key per sale" on the product)
- `AppConstants.purchaseURL` — your product page, linked from the activation modal

Set the product up as a single product with two variants, pricing the Personal
variant at $0. The app detects the tier from the variant name: any variant
containing **"Family"** is treated as a Family license; everything else is
Personal.

Device limiting for Personal licenses uses Gumroad's license "uses" counter:
activation increments it, and a count above 1 is rejected. A reinstall on the
same machine also increments the counter, so a legitimate user who reinstalls
may need their uses count reset from the Gumroad dashboard (Sales → license key).
Daily/launch revalidation does not increment the counter; refunded or disputed
purchases deactivate the app on next launch.

## How the privileged setup works

macOS requires root to edit `/etc/hosts`. To keep it to a single admin prompt:

1. During initial setup, an osascript admin prompt installs
   `/Library/PrivilegedHelperTools/com.hostblock.helper` (root-owned, 755) and a
   sudoers rule at `/etc/sudoers.d/hostblock` scoped to exactly that helper.
2. From then on the app runs the helper via `sudo -n` — no password, no prompt.

The helper only ever:
- replaces the `#HOSTBLOCK_START`…`#HOSTBLOCK_END` section of `/etc/hosts`,
  accepting only lines matching `0.0.0.0 <domain>` (revalidated in the helper
  itself with a strict regex),
- removes that section, or
- flushes the DNS cache (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`).

The rest of the hosts file is never touched, and writes are atomic
(temp file + `mv`).

## Uninstalling

```sh
sudo /Library/PrivilegedHelperTools/com.hostblock.helper remove   # clean /etc/hosts + flush DNS
sudo rm /Library/PrivilegedHelperTools/com.hostblock.helper /etc/sudoers.d/hostblock
rm -rf ~/Library/Application\ Support/HostBlock
```

## Data locations

- Config & license: `~/Library/Application Support/HostBlock/`
- Downloaded list caches: `~/Library/Application Support/HostBlock/cache/`
  (used as a fallback when a list is unreachable)
- Staged hosts block: `~/Library/Application Support/HostBlock/hosts_block.txt`

## Note on oisd

The built-in lists come from [oisd.nl](https://oisd.nl) (`big.oisd.nl` and
`nsfw.oisd.nl`, `domainswild2` plain-domain syntax). oisd has its own
[license](https://github.com/sjhgvr/oisd/blob/main/LICENSE) — review it (and
consider reaching out to the maintainer) before shipping it inside a paid
product.
