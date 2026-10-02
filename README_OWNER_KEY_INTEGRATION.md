# OVERLORD Owner Key Integration

This overlay adds a server-authoritative Owner Key system.

## Flow

`Owner Key → Roblox Server → /api/verify → ownerId from Player.UserId → Owner permission`

The client is never trusted for authorization. Invalid, expired, revoked, or mismatched-owner keys are rejected by the server.

## N/A TIME

Generate a permanent Owner key with:

```http
POST /api/generate
Authorization: Bearer YOUR_ADMIN_TOKEN
Content-Type: application/json

{"ownerId":"123456789","mode":"na_time"}
