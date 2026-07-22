# HostBlock license-decrement Worker

Frees a Gumroad license's "uses" slot when a user removes their license, so the
same key can be re-added on the same device. Keeps the Gumroad **seller token**
server-side instead of shipping it in the app.

`POST { "license_key": "..." }` → verifies the key against your product (public
endpoint, so a bad key can't decrement anything), then decrements if `uses > 0`.
Returns `{ "success": true, "decremented": true|false }`; invalid keys get `404`.

Served at `https://api.hostblock.app/license/decrement` (see `wrangler.toml`),
leaving the rest of `api.hostblock.app` free for other endpoints later.

## Deploy

Needs [Bun](https://bun.sh). No dependencies to install — `bunx` fetches
`wrangler` on demand.

The path route in `wrangler.toml` does **not** auto-create DNS. First, in the
`hostblock.app` zone, add a proxied (orange-cloud) record for `api` — e.g. an
`AAAA` record `api` → `100::` — so requests reach Cloudflare's edge. Then:

```sh
bunx wrangler login
bunx wrangler secret put GUMROAD_ACCESS_TOKEN   # paste your Gumroad token
bunx wrangler deploy
```

The app already points `AppConstants.decrementEndpoint` at
`https://api.hostblock.app/license/decrement`. `GUMROAD_PRODUCT_ID` lives in
`wrangler.toml` (public id). Local dev: `bunx wrangler dev` with the token in a
gitignored `.dev.vars`.

## Security

The only exposed capability is decrementing a valid license for this one product;
the token and all other account operations stay private. Add a shared-secret
header or Cloudflare rate-limit rule to tighten further.
