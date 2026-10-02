# 👑 OVERLORD — OF THE GODS

A redesigned, privacy-first Roblox developer toolkit UI for the OVERLORD project, with a server-authoritative action model and an optional Owner Key / Key API system.

> **Important:** The Roblox client is not trusted for authorization. Sensitive permissions and game actions must be validated by the server.

---

## ✨ Features

- 🦖 **Guard** — server-owned Guard actions
- 🔨 **Forge** — recipe selection and server-validated craft requests
- 🥚 **Auto Farm** — Egg / Selected discovery and preview
- ☁️ **Cloud Storage** — script catalog and notes
- 🤖 **AI** — local diagnostics and integration review
- 🏜️ **Arena** — reversible arena previews
- 🏠 **Zone Builder** — reusable construction blueprints
- 🔐 **Security** — privacy-first security controls
- ⚙️ **Settings** — UI and configuration controls
- 👑 **Owner Key** — server-side key verification
- ☁️ **Key API** — Next.js API for generating, verifying and revoking keys

---

# 🎨 UI & Animation

The interface uses Roblox `TweenService` for:

- Smooth transitions
- Splash-screen animations
- Hover effects
- Button animations
- Visual status effects

The main image uses an `ImageLabel` slot:

```lua
HeroImage = "rbxassetid://0"
