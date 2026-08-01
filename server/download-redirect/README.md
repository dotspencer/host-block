# HostBlock download-redirect Worker

`GET https://download.hostblock.app` → **302** to the current DMG.

It reads the same `latest.json` update feed the app polls — the latest GitHub
release's `latest.json` asset (`FEED_URL` in `wrangler.toml`) — and redirects to
that file's `url` (this release's DMG asset). So the download link always points
at the latest release with no per-release changes: publishing a new GitHub
release moves it automatically. The 302 preserves the versioned filename
(e.g. `HostBlock-1.0.9.dmg`) in the user's download.

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
  is live once GitHub's CDN serves the new `latest.json` asset (a minute or two).
- The feed's `url` is the single source of truth shared with the in-app update
  check, so the download link and update prompt can never drift apart.
