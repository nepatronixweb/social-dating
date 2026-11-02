"use client";

import { FormEvent, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { canSupportWrite } from "@/lib/rbac";

export default function BroadcastPage() {
  const canWrite = canSupportWrite(getStaff()?.role);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [gender, setGender] = useState("");
  const [city, setCity] = useState("");
  const [incompleteOnly, setIncompleteOnly] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!canWrite) return;
    if (!window.confirm("Send this system notification to the matching segment?")) {
      return;
    }
    setBusy(true);
    setError(null);
    setNote(null);
    try {
      const res = await api.broadcast({
        title: title.trim(),
        body: body.trim(),
        gender: gender || undefined,
        city: city.trim() || undefined,
        incompleteOnly,
      });
      setNote(res.message);
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Send failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-5 max-w-xl">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Broadcast</h1>
        <p className="muted text-sm mt-1">
          System inbox push to a segment (max 5000). Not a push notification
          vendor.
        </p>
      </header>
      {!canWrite && (
        <p className="muted text-sm">Support / trust / superadmin can send.</p>
      )}
      {error && <p className="err">{error}</p>}
      {note && <p className="text-[var(--accent)] text-sm">{note}</p>}

      <form onSubmit={onSubmit} className="panel p-4 flex flex-col gap-3">
        <label className="text-sm flex flex-col gap-1">
          Title
          <input
            className="field"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            required
            minLength={2}
            maxLength={80}
            disabled={!canWrite || busy}
          />
        </label>
        <label className="text-sm flex flex-col gap-1">
          Body
          <textarea
            className="field min-h-28"
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
            minLength={2}
            maxLength={300}
            disabled={!canWrite || busy}
          />
        </label>
        <label className="text-sm flex flex-col gap-1">
          Gender filter
          <select
            className="field"
            value={gender}
            onChange={(e) => setGender(e.target.value)}
            disabled={!canWrite || busy}
          >
            <option value="">all</option>
            <option value="male">male</option>
            <option value="female">female</option>
            <option value="lgbtq">lgbtq</option>
            <option value="other">other</option>
          </select>
        </label>
        <label className="text-sm flex flex-col gap-1">
          City filter
          <input
            className="field"
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder="Optional exact city"
            disabled={!canWrite || busy}
          />
        </label>
        <label className="text-sm flex items-center gap-2">
          <input
            type="checkbox"
            checked={incompleteOnly}
            onChange={(e) => setIncompleteOnly(e.target.checked)}
            disabled={!canWrite || busy}
          />
          Incomplete profiles only
        </label>
        <button className="btn btn-primary self-start" disabled={!canWrite || busy}>
          {busy ? "Sending…" : "Send broadcast"}
        </button>
      </form>
    </div>
  );
}
