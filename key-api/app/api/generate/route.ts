import { NextResponse } from "next/server";
import { redis, recordKey } from "@/lib/store";
import { generateKey, getDurationSeconds, normalizeOwnerId, type KeyUnit } from "@/lib/key";
import { allowedOrigin, authorizedAdmin, bodyIsSmall, isJson, blockedByRateLimit } from "@/lib/security";

export const runtime = "nodejs";

export async function POST(request: Request) {
  if (!authorizedAdmin(request)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  if (!isJson(request)) {
    return NextResponse.json({ error: "Content-Type must be application/json." }, { status: 415 });
  }
  if (!bodyIsSmall(request)) {
    return NextResponse.json({ error: "Request body too large." }, { status: 413 });
  }
  if (!allowedOrigin(request)) {
    return NextResponse.json({ error: "Origin is not allowed." }, { status: 403 });
  }
  if (await blockedByRateLimit(request)) {
    return NextResponse.json(
      { error: "Too many requests. Try again later." },
      { status: 429, headers: { "Retry-After": "60" } }
    );
  }

  try {
    const body = await request.json();
    const ownerId = normalizeOwnerId(body?.ownerId);
    const mode = String(body?.mode ?? "duration");

    const key = generateKey();
    const now = Date.now();

    if (mode === "na_time") {
      // Permanent key: no Redis TTL.
      await redis.set(
        recordKey(key),
        { createdAt: now, ownerId, expiresAt: null }
      );

      return NextResponse.json(
        {
          ok: true,
          key,
          ownerId,
          expiresAt: null,
          time: "N/A",
          ownerOnly: true,
        },
        { headers: { "Cache-Control": "no-store" } }
      );
    }

    const duration = Number(body?.duration);
    const unit = body?.unit as KeyUnit;

    if (!Number.isInteger(duration) || duration < 1 || duration > 3650) {
      return NextResponse.json({ error: "duration must be an integer from 1 to 3650." }, { status: 400 });
    }
    if (!["hours", "days"].includes(unit)) {
      return NextResponse.json({ error: "unit must be hours or days." }, { status: 400 });
    }

    const ttl = getDurationSeconds(duration, unit);
    const expiresAt = now + ttl * 1000;

    await redis.set(
      recordKey(key),
      { createdAt: now, ownerId, expiresAt },
      { ex: ttl }
    );

    return NextResponse.json(
      {
        ok: true,
        key,
        ownerId,
        createdAt: new Date(now).toISOString(),
        expiresAt: new Date(expiresAt).toISOString(),
        expiresInSeconds: ttl,
        ownerOnly: true,
      },
      { headers: { "Cache-Control": "no-store" } }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid request";
    return NextResponse.json({ error: message }, { status: 400 });
  }
      }
