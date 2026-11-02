"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints, formatWhen } from "@/lib/format";
import type { AdminRefundItem } from "@/lib/types";

export default function RefundsPage() {
  const [status, setStatus] = useState("pending");
  const [items, setItems] = useState<AdminRefundItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function load(s = status) {
    setError(null);
    try {
      setItems((await api.listRefunds(s || undefined)).items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(status);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  async function resolve(id: string, decision: "approve" | "reject") {
    const note = window.prompt("Note (optional)") ?? undefined;
    setBusyId(id);
    try {
      await api.resolveRefund(id, decision, note || undefined);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            Dual-control refunds
          </h1>
          <p className="muted text-sm mt-1">
            Charges at/above the threshold need a second staff member to approve
          </p>
        </div>
        <select
          className="field w-40"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
        >
          <option value="pending">pending</option>
          <option value="approved">approved</option>
          <option value="rejected">rejected</option>
          <option value="">all</option>
        </select>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>User</th>
              <th>Source</th>
              <th>Points</th>
              <th>Requested by</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((r) => (
              <tr key={r.id}>
                <td className="muted text-sm">{formatWhen(r.createdAt)}</td>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${r.accountId}`}
                  >
                    {r.accountName ?? r.accountId.slice(0, 8)}
                  </Link>
                </td>
                <td className="font-[family-name:var(--font-mono)] text-xs">
                  {r.sourceId}
                </td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(r.points)}
                </td>
                <td className="text-sm">{r.requestedByEmail}</td>
                <td>
                  <span
                    className={`badge ${
                      r.status === "pending" ? "badge-open" : "badge-ok"
                    }`}
                  >
                    {r.status}
                  </span>
                </td>
                <td>
                  {r.status === "pending" && (
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={busyId === r.id}
                        onClick={() => void resolve(r.id, "approve")}
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        className="btn btn-danger text-sm"
                        disabled={busyId === r.id}
                        onClick={() => void resolve(r.id, "reject")}
                      >
                        Reject
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
                  No refund requests.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
