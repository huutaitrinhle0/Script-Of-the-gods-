import crypto from "node:crypto";

export type KeyUnit = "hours" | "days";

export function generateKey(): string {
  const part = () =>
    crypto.randomBytes(4).toString("hex").toUpperCase().slice(0, 6);

  return `KEY-${part()}-${part()}-${part()}`;
}

export function getDurationSeconds(
  duration: number,
  unit: KeyUnit
): number {
  return unit === "days"
    ? duration * 24 * 60 * 60
    : duration * 60 * 60;
}

export function normalizeOwnerId(value: unknown): string {
  const ownerId = String(value ?? "").trim();

  if (!ownerId || ownerId.length > 128) {
    throw new Error("Invalid ownerId.");
  }

  if (!/^[A-Za-z0-9._:@-]+$/.test(ownerId)) {
    throw new Error("Invalid ownerId.");
  }

  return ownerId;
}
