# OVERLORD — OF THE GODS

A redesigned, privacy-first Roblox **developer toolkit UI** for the `OVERLORD` project.

## Included modules

- 🦖 Guard — server-owned Guard actions through `ReplicatedStorage.OVX_DevAPI`
- 🔨 Forge — recipe selection and server-validated craft requests
- 🥚 Auto Farm — Egg / Selected discovery and preview only
- ☁ Cloud Storage — catalog/notes for requested external scripts; no auto-execution
- 🤖 AI — local diagnostics and integration review
- 🏜️🏞️ Arena — reversible local arena previews (Cross/Ring/Grid/Spiral)
- 🏠🏡 Zone Builder — reusable construction blueprints based on interest
- 🔐 Security — telemetry off, remote execution blocked, privacy-first defaults
- ⚙ Settings — compact mode, image slot and restore controls

## Animation / image design

The UI uses Roblox `TweenService` for animated transitions, pulsing visuals, splash screen motion and hover effects. The hero art is an `ImageLabel` slot with a placeholder asset ID:

```lua
HeroImage = "rbxassetid://0"
```

Upload your own banner/emblem through Roblox Creator and replace that ID.

## Server API contract

The client only calls a game-owned `RemoteFunction`:

- `ReplicatedStorage.OVX_DevAPI`
- `workspace.OVX_DeveloperMode == true`

Your **server** must verify the caller, permissions, recipe data, cooldowns and every requested action. Never trust client-side authorization.

Example request names used by the UI:

- `Guard:Start`
- `Guard:Stop`
- `Guard:Patrol`
- `Forge:Craft`
- `AutoFarm:Preview`

## Deliberately not included

This build does not include executor fingerprinting, anti-ban behavior, synthetic input, generic remote automation, `loadstring`, external code execution, or detection bypass.

## Files

- `Overlord-Of-The-Gods.lua` — main script
- `assets/of-the-gods-banner.svg` — GitHub preview/banner; Roblox UI still requires a Creator image asset ID
- `.github/workflows/secure-lint.yml` — lightweight repository guardrail
