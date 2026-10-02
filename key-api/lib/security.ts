import crypto from "node:crypto";
import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();

const ADMIN_SECRET = process.env.ADMIN_SECRET ?? "";
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN ?? "";

const RATE_LIMIT_WINDOW = 60;
const RATE_LIMIT_MAX = 30;

function getClientIp(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0].trim();
  }

  return request.headers.get("x-real-ip")?.trim() || "unknown";
}

function safeEqual(a: string, b: string): boolean {
  const aBuffer = Buffer.from(a);
  const bBuffer = Buffer.from(b);

  if (aBuffer.length !== bBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(aBuffer, bBuffer);
}

export function authorizedAdmin(request: Request): boolean {
  if (!ADMIN_SECRET) {
    return false;
  }

  const authorization = request.headers.get("authorization") ?? "";

  if (!authorization.startsWith("Bearer ")) {
    return false;
  }

  const supplied = authorization.slice("Bearer ".length).trim();

  return safeEqual(supplied, ADMIN_SECRET);
}

export function isJson(request: Request): boolean {
  const contentType = request.headers.get("content-type") ?? "";

  return contentType.toLowerCase().includes("application/json");
}

export function bodyIsSmall(request: Request): boolean {
  const length = request.headers.get("content-length");

  if (!length) {
    return true;
  }

  const size = Number(length);

  return Number.isFinite(size) && size <= 16 * 1024;
}

export function allowedOrigin(request: Request): boolean {
  if (!ALLOWED_ORIGIN) {
    return true;
  }

  const origin = request.headers.get("origin");

  if (!origin) {
    return true;
  }

  return origin === ALLOWED_ORIGIN;
}

export async function blockedByRateLimit(
  request: Request,
  key?: string
): Promise<boolean> {
  const ip = getClientIp(request);
  const identifier = key ? `${ip}:${key}` : ip;

  const bucket = Math.floor(Date.now() / (RATE_LIMIT_WINDOW * 1000));
  const redisKey = `rate:${bucket}:${identifier}`;

  const count = await redis.incr(redisKey);

  if (count === 1) {
    await redis.expire(redisKey, RATE_LIMIT_WINDOW);
  }

  return count > RATE_LIMIT_MAX;
}
