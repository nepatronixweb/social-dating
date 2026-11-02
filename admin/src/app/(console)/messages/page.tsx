"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen, shortId } from "@/lib/format";
import { canSupportWrite } from "@/lib/rbac";
import type { AdminMessageQueueItem } from "@/lib/types";

export default function MessagesPage() {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<AdminMessageQueueItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const canWrite = canSupportWrite(getStaff()?.role);

  async function load(term = q) {
    setError(null);
    try {
      const res = await api.messageQueue(term || undefined);
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load("");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function toggle(item: AdminMessageQueueItem) {
    const next = !item.hidden;
    const note = window.prompt("Note (optional)") ?? undefined;
    setBusyId(item.id);
    try {
      await api.setMessageHidden(item.id, next, note || undefined);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Update failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Chat queue</h1>
          <p className="muted text-sm mt-1">
            Search recent messages and hide them from conversations
          </p>
        </div>
        <form
          className="flex gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            void load(q);
          }}
        >
          <input
            className="field w-56"
            placeholder="Search body…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          <button type="submit" className="btn text-sm">
            Search
          </button>
        </form>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Sender</th>
              <th>Body</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((m) => (
              <tr key={m.id}>
                <td className="muted text-sm whitespace-nowrap">
                  {formatWhen(m.createdAt)}
                </td>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${m.senderAccountId}`}
                  >
                    {m.senderName ?? shortId(m.senderAccountId)}
                  </Link>
                </td>
                <td className="max-w-md truncate text-sm">{m.body || "—"}</td>
                <td className="text-sm">{m.hidden ? "hidden" : "visible"}</td>
                <td>
                  {canWrite && (
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busyId === m.id}
                      onClick={() => void toggle(m)}
                    >
                      {m.hidden ? "Unhide" : "Hide"}
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={5} className="muted text-sm">
                  No messages.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}