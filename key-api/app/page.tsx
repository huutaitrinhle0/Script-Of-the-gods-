"use client";

import { FormEvent, useState } from "react";

export default function Home() {
  const [adminToken, setAdminToken] = useState("");
  const [ownerId, setOwnerId] = useState("");
  const [mode, setMode] = useState<"na_time" | "duration">("na_time");
  const [duration, setDuration] = useState("24");
  const [unit, setUnit] = useState<"hours" | "days">("hours");
  const [generated, setGenerated] = useState<string>("");
  const [verifyKey, setVerifyKey] = useState("");
  const [verifyOwner, setVerifyOwner] = useState("");
  const [verifyResult, setVerifyResult] = useState("");
  const [revokeKey, setRevokeKey] = useState("");
  const [message, setMessage] = useState("");

  async function generate(e: FormEvent) {
    e.preventDefault();
    setGenerated("");
    setMessage("");

    const payload: Record<string, unknown> = { ownerId, mode };
    if (mode === "duration") {
      payload.duration = Number(duration);
      payload.unit = unit;
    }

    const res = await fetch("/api/generate", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify(payload),
    });

    const data = await res.json();
    if (!res.ok) {
      setMessage(data.error ?? "Generate failed");
      return;
    }

    setGenerated(
      mode === "na_time"
        ? `${data.key}\nOwner: ${data.ownerId}\nTime: N/A`
        : `${data.key}\nOwner: ${data.ownerId}\nExpires: ${new Date(data.expiresAt).toLocaleString()}`
    );
  }

  async function verify(e: FormEvent) {
    e.preventDefault();

    const res = await fetch("/api/verify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key: verifyKey, ownerId: verifyOwner }),
    });

    const data = await res.json();
    setVerifyResult(
      data.valid
        ? data.expiresAt === null
          ? `VALID — Owner-only — Time: N/A`
          : `VALID — expires ${new Date(data.expiresAt).toLocaleString()}`
        : `INVALID — ${data.error ?? "Key rejected"}`
    );
  }

  async function revoke(e: FormEvent) {
    e.preventDefault();
    const res = await fetch("/api/revoke", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ key: revokeKey }),
    });
    const data = await res.json();
    setMessage(res.ok ? (data.revoked ? "Key revoked." : "Key not found.") : (data.error ?? "Revoke failed"));
  }

  return (
    <main className="wrap">
      <section className="hero">
        <span className="badge">OWNER-BOUND KEY SYSTEM</span>
        <h1>Owner-only keys</h1>
        <p>Bind every key to an owner ID. Select N/A TIME for a permanent key.</p>
      </section>

      <div className="grid">
        <section className="card">
          <h2>Generate</h2>
          <form onSubmit={generate}>
            <label>Admin token</label>
            <input type="password" value={adminToken} onChange={e => setAdminToken(e.target.value)} required />
            <label>Owner ID</label>
            <input value={ownerId} onChange={e => setOwnerId(e.target.value)} placeholder="owner-123" required />
            <label>Time</label>
            <select value={mode} onChange={e => setMode(e.target.value as "na_time" | "duration")}>
              <option value="na_time">N/A TIME — permanent</option>
              <option value="duration">Expire after X</option>
            </select>

            {mode === "duration" && (
              <div className="row">
                <div>
                  <label>Duration</label>
                  <input type="number" min="1" value={duration} onChange={e => setDuration(e.target.value)} required />
                </div>
                <div>
                  <label>Unit</label>
                  <select value={unit} onChange={e => setUnit(e.target.value as "hours" | "days")}>
                    <option value="hours">Hours</option>
                    <option value="days">Days</option>
                  </select>
                </div>
              </div>
            )}

            <button type="submit">Generate Key</button>
          </form>

          {generated && <pre className="result">{generated}</pre>}
        </section>

        <section className="card">
          <h2>Verify</h2>
          <form onSubmit={verify}>
            <label>Key</label>
            <input value={verifyKey} onChange={e => setVerifyKey(e.target.value)} required />
            <label>Owner ID</label>
            <input value={verifyOwner} onChange={e => setVerifyOwner(e.target.value)} required />
            <button type="submit">Verify Ownership</button>
          </form>
          {verifyResult && <div className="result">{verifyResult}</div>}
        </section>

        <section className="card">
          <h2>Revoke</h2>
          <form onSubmit={revoke}>
            <label>Admin token</label>
            <input type="password" value={adminToken} onChange={e => setAdminToken(e.target.value)} required />
            <label>Key</label>
            <input value={revokeKey} onChange={e => setRevokeKey(e.target.value)} required />
            <button className="danger" type="submit">Revoke Key</button>
          </form>
          {message && <div className="result">{message}</div>}
        </section>
      </div>
    </main>
  );
      }
