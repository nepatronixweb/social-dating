"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen, shortId } from "@/lib/format";
import { canSupportWrite } from "@/lib/rbac";

type Hit = {
  id: string;
  messageId: string;
  matchId: string;
  senderAccountId: string;
  senderName: string | null;
  keyword: string;
  messageBody: string;
  status: string;
  createdAt: string;
  resolvedAt: string | null;
};

export default function KeywordsPage() {
  const [status, setStatus] = useState("open");
  const [items, setItems] = useState<Hit[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const canWrite = canSupportWrite(getStaff()?.role);

  async function load(s = status) {
    setError(null);
    try {
      const res = await api.listKeywordHits(s || undefined);
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(status);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  async function resolve(id: string, decision: "dismiss" | "actioned") {
    const note = window.prompt("Note (optional)") ?? undefined;
    setBusyId(id);
    try {
      await api.resolveKeywordHit(id, decision, note || undefined);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Resolve failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Keyword hits</h1>
          <p className="muted text-sm mt-1">
            Messages matching config keyword list
          </p>
        </div>
        <select
          className="field w-40"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
        >
          <option value="open">open</option>
          <option value="dismissed">dismissed</option>
          <option value="actioned">actioned</option>
          <option value="">all</option>
        </select>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Sender</th>
              <th>Keyword</th>
              <th>Message</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((h) => (
              <tr key={h.id}>
                <td className="muted text-sm">{formatWhen(h.createdAt)}</td>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${h.senderAccountId}`}
                  >
                    {h.senderName ?? shortId(h.senderAccountId)}
                  </Link>
                </td>
                <td>
                  <span className="badge badge-open">{h.keyword}</span>
                </td>
                <td className="text-sm max-w-md whitespace-pre-wrap">
                  {h.messageBody}
                </td>
                <td>{h.status}</td>
                <td>
                  {canWrite && h.status === "open" && (
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={busyId === h.id}
                        onClick={() => void resolve(h.id, "actioned")}
                      >
                        Actioned
                      </button>
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={busyId === h.id}
                        onClick={() => void resolve(h.id, "dismiss")}
                      >
                        Dismiss
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No keyword hits.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
