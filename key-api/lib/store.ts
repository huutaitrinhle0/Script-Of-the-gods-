import { Redis } from "@upstash/redis";
import crypto from "node:crypto";

export type KeyRecord = {
  createdAt: number;
  ownerId: string;
  expiresAt: number | null;
};

export const redis = Redis.fromEnv();

export function hashKey(key: string): string {
  return crypto.createHash("sha256").update(key).digest("hex");
}

export function recordKey(key: string): string {
  return `owner-key:${hashKey(key)}`;
}
