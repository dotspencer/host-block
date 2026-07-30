# HostBlock

A lightweight native macOS menu bar app for hosts-file domain blocking.

<img height="600" alt="Screenshot 2026-07-29 at 9 23 56 PM" src="https://github.com/user-attachments/assets/08274062-0973-477f-9ba0-b94cbcab48d8" />

Download: https://download.hostblock.app
<br>Get a license: https://smithlabs.gumroad.com/l/host-block
<br>Homepage: https://hostblock.app


| Directory           | What it is                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [`app/`](app)       | The macOS menu bar app (Swift / SwiftUI). See [`app/README.md`](app/README.md) to build.                                 |
| [`site/`](site)     | The homepage (Astro), deployed to GitHub Pages at [hostblock.app](https://hostblock.app).                                |
| [`server/`](server) | Cloudflare Workers: [`license-decrement`](server/license-decrement) and [`download-redirect`](server/download-redirect). |
