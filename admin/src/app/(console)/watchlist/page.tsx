"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen, shortId } from "@/lib/format";
import { canSupportWrite } from "@/lib/rbac";

type Item = {
  id: string;
  accountId: string;
  accountName: string | null;
  status: string | null;
  note: string;
  createdAt: string;
};

export default function WatchlistPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const canWrite = canSupportWrite(getStaff()?.role);

  async function load() {
    setError(null);
    try {
      const res = await api.watchlist();
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function unwatch(accountId: string) {
    setBusyId(accountId);
    try {
      await api.unwatchUser(accountId);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Unwatch failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Watchlist</h1>
        <p className="muted text-sm mt-1">
          Accounts you are tracking — add from a user case page
        </p>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>User</th>
              <th>Status</th>
              <th>Note</th>
              <th>Added</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((w) => (
              <tr key={w.id}>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${w.accountId}`}
                  >
                    {w.accountName ?? shortId(w.accountId)}
                  </Link>
                </td>
                <td>
                  <span className="badge">{w.status ?? "—"}</span>
                </td>
                <td className="text-sm">{w.note || "—"}</td>
                <td className="muted text-sm">{formatWhen(w.createdAt)}</td>
                <td>
                  {canWrite && (
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busyId === w.accountId}
                      onClick={() => void unwatch(w.accountId)}
                    >
                      Remove
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  Watchlist empty.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
