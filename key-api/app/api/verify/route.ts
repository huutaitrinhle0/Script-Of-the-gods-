import { NextResponse } from "next/server";
import { redis, recordKey, type KeyRecord } from "@/lib/store";
import {
  allowedOrigin,
  blockedByRateLimit,
  bodyIsSmall,
  isJson,
} from "@/lib/security";

export const runtime = "nodejs";

function fail(message: string, status = 400) {
  return NextResponse.json(
    { valid: false, error: message },
    { status, headers: { "Cache-Control": "no-store" } }
  );
}

export async function POST(request: Request) {
  if (!isJson(request)) return fail("Content-Type must be application/json.", 415);
  if (!bodyIsSmall(request)) return fail("Request body too large.", 413);
  if (!allowedOrigin(request)) return fail("Origin is not allowed.", 403);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return fail("Malformed JSON.");
  }

  const key = String(
    body && typeof body === "object" && "key" in body
      ? (body as { key?: unknown }).key ?? ""
      : ""
  ).trim().toUpperCase();

  const ownerId = String(
    body && typeof body === "object" && "ownerId" in body
      ? (body as { ownerId?: unknown }).ownerId ?? ""
      : ""
  ).trim();

  if (!/^KEY-[A-Z0-9]{6}(?:-[A-Z0-9]{6}){2}$/.test(key)) {
    return fail("Invalid key format.");
  }

  if (!ownerId || ownerId.length > 128 || !/^[A-Za-z0-9._:@-]+$/.test(ownerId)) {
    return fail("Invalid ownerId.");
  }

  if (await blockedByRateLimit(request, key)) {
    return NextResponse.json(
      { valid: false, error: "Too many requests. Try again later." },
      { status: 429, headers: { "Retry-After": "60", "Cache-Control": "no-store" } }
    );
  }

  const result = await redis.get<KeyRecord>(recordKey(key));
  if (!result) {
    return fail("Key is invalid or has been revoked.", 404);
  }

  // Ownership is mandatory.
  if (result.ownerId !== ownerId) {
    return fail("Key is not owned by this owner.", 403);
  }

  // null expiresAt = N/A TIME / permanent.
  if (result.expiresAt === null) {
    return NextResponse.json(
      {
        valid: true,
        status: "active",
        ownerOnly: true,
        ownerId: result.ownerId,
        expiresAt: null,
        time: "N/A",
      },
      { headers: { "Cache-Control": "no-store" } }
    );
  }

  const now = Date.now();
  if (result.expiresAt <= now) {
    await redis.del(recordKey(key));
    return fail("Key has expired.", 410);
  }

  return NextResponse.json(
    {
      valid: true,
      status: "active",
      ownerOnly: true,
      ownerId: result.ownerId,
      expiresAt: new Date(result.expiresAt).toISOString(),
      expiresInSeconds: Math.max(0, Math.floor((result.expiresAt - now) / 1000)),
    },
    { headers: { "Cache-Control": "no-store" } }
  );
    }
