# HostBlock download-redirect Worker

`GET https://download.hostblock.app` → **302** to the current DMG.

It reads the same `latest.json` update feed the app polls
(`https://updates.hostblock.app/releases/latest.json`) and redirects to that
file's `url`. So the download link always points at the latest release with no
per-release changes — you just upload the new DMG + `latest.json` as usual, and
the redirect follows automatically. The 302 preserves the versioned filename
(e.g. `HostBlock-1.0.4.dmg`) in the user's download.

## Deploy

Needs [Bun](https://bun.sh). No dependencies to install — `bunx` fetches
`wrangler` on demand.

`download.hostblock.app` is a `custom_domain` route (see `wrangler.toml`), so the
deploy auto-provisions its proxied DNS record and TLS cert — no manual DNS.

```sh
bunx wrangler login
bunx wrangler deploy
```

Local dev: `bunx wrangler dev`, then hit the printed URL.

## Notes

- Redirect target is read fresh from the feed on every request, so a new release
  is live immediately after you upload it.
- The feed's `url` is the single source of truth shared with the in-app update
  check, so the download link and update prompt can never drift apart.
