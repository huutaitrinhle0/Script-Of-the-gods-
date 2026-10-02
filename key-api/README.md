# Expiring Key System

A self-hosted key system for your own application/script.

## Features

- Generate keys for `X` hours or `X` days.
- Server-side expiration using Redis TTL.
- Verify active/expired keys through an API.
- Revoke keys immediately.
- Keys are stored by SHA-256 hash instead of the raw key.
- Basic per-IP verification rate limit.
- Vercel/Next.js friendly.

## 1. Install

```bash
npm install
