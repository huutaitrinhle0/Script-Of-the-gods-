import { NextResponse } from "next/server";
import { redis, recordKey } from "@/lib/store";
import {
  allowedOrigin,
  authorizedAdmin,
  blockedByRateLimit,
  bodyIsSmall,
  isJson,
} from "@/lib/security";

export const runtime = "nodejs";

export async function POST(request: Request) {
  if (!authorizedAdmin(request)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!isJson(request)) {
    return NextResponse.json(
      { error: "Content-Type must be application/json." },
      { status: 415 }
    );
  }

  if (!bodyIsSmall(request)) {
    return NextResponse.json(
      { error: "Request body too large." },
      { status: 413 }
    );
  }

  if (!allowedOrigin(request)) {
    return NextResponse.json(
      { error: "Origin is not allowed." },
      { status: 403 }
    );
  }

  if (await blockedByRateLimit(request)) {
    return NextResponse.json(
      { error: "Too many requests. Try again later." },
      {
        status: 429,
        headers: { "Retry-After": "60" },
      }
    );
  }

  try {
    const body = await request.json();

    const key = String(body?.key ?? "")
      .trim()
      .toUpperCase();

    if (!/^KEY-[A-Z0-9]{6}(?:-[A-Z0-9]{6}){2}$/.test(key)) {
      return NextResponse.json(
        { error: "Invalid key format." },
        { status: 400 }
      );
    }

    const exists = await redis.get(recordKey(key));

    if (!exists) {
      return NextResponse.json(
        {
          ok: false,
          error: "Key not found or already revoked.",
        },
        { status: 404 }
      );
    }

    await redis.del(recordKey(key));

    return NextResponse.json(
      {
        ok: true,
        revoked: true,
        key,
      },
      {
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Invalid request";

    return NextResponse.json(
      { error: message },
      { status: 400 }
    );
  }
}
