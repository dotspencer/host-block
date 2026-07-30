# HostBlock

A lightweight native macOS menu bar app for hosts-file domain blocking.

Download: https://download.hostblock.app
<br>Get a license: https://smithlabs.gumroad.com/l/host-block
<br>Homepage: https://hostblock.app

| Directory           | What it is                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [`app/`](app)       | The macOS menu bar app (Swift / SwiftUI). See [`app/README.md`](app/README.md) to build.                                 |
| [`site/`](site)     | The homepage (Astro), deployed to GitHub Pages at [hostblock.app](https://hostblock.app).                                |
| [`server/`](server) | Cloudflare Workers: [`license-decrement`](server/license-decrement) and [`download-redirect`](server/download-redirect). |
