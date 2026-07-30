# HostBlock download-redirect Worker

`GET https://hostblock.app/download` → **302** to the current DMG.

It reads the same `latest.json` update feed the app polls
(`https://updates.hostblock.app/releases/latest.json`) and redirects to that
file's `url`. So `/download` always points at the latest release with no
per-release changes — you just upload the new DMG + `latest.json` as usual, and
the redirect follows automatically. The 302 preserves the versioned filename
(e.g. `HostBlock-1.0.1.dmg`) in the user's download.

## Deploy

Needs [Bun](https://bun.sh). No dependencies to install — `bunx` fetches
`wrangler` on demand.

The path route in `wrangler.toml` does **not** auto-create DNS. The
`hostblock.app` apex must already resolve through Cloudflare with the proxy on
(orange cloud) so requests reach the Worker. Then:

```sh
bunx wrangler login
bunx wrangler deploy
```

Local dev: `bunx wrangler dev`, then hit the printed URL + `/download`.

## Notes

- Redirect target is read fresh from the feed on every request, so a new release
  is live immediately after you upload it.
- The feed's `url` is the single source of truth shared with the in-app update
  check, so the download link and update prompt can never drift apart.
