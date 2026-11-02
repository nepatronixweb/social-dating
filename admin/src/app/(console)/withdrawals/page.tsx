"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints, formatWhen } from "@/lib/format";
import type { AdminWithdrawalItem } from "@/lib/types";

export default function WithdrawalsPage() {
  const [status, setStatus] = useState("recorded");
  const [items, setItems] = useState<AdminWithdrawalItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function load(s = status) {
    setError(null);
    try {
      const res = await api.listWithdrawals(s || undefined);
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(status);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  async function resolve(id: string, decision: "decline" | "markPaid") {
    const note =
      window.prompt(
        decision === "decline"
          ? "Decline note (optional)"
          : "Ops note (optional) — marking paid does not send money to a bank"
      ) ?? undefined;
    setBusyId(id);
    try {
      await api.resolveWithdrawal(id, decision, note || undefined);
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
          <h1 className="text-2xl font-semibold tracking-tight">Withdrawals</h1>
          <p className="muted text-sm mt-1">
            Desk for recorded holds. Paid = ops marker only — this API never
            pays a bank.
          </p>
        </div>
        <div className="flex gap-2">
          <select
            className="field w-40"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="recorded">recorded</option>
            <option value="paid">paid (ops)</option>
            <option value="declined">declined</option>
            <option value="">all</option>
          </select>
          <button
            type="button"
            className="btn text-sm"
            onClick={() => {
              void api
                .downloadWithdrawalsCsv(status || undefined)
                .catch((err) =>
                  setError(
                    err instanceof ApiError ? err.message : "Export failed"
                  )
                );
            }}
          >
            Export CSV
          </button>
        </div>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Created</th>
              <th>User</th>
              <th>Points / net</th>
              <th>Eligibility</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((w) => (
              <tr key={w.id}>
                <td className="muted text-sm">{formatWhen(w.createdAt)}</td>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${w.accountId}`}
                  >
                    {w.accountName ?? "—"}
                  </Link>
                  <div className="muted text-xs">
                    {w.phoneMasked}
                    {w.gender ? ` · ${w.gender}` : ""}
                  </div>
                </td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(w.points)} / {formatPoints(w.netPoints)}
                </td>
                <td className="text-sm">
                  <div>
                    Earned now {formatPoints(w.currentEarnedPoints)} (min{" "}
                    {formatPoints(w.minWithdrawalPoints)})
                  </div>
                  <div
                    className={
                      w.eligibilityLooksOk ? "muted text-xs" : "err text-xs"
                    }
                  >
                    {w.eligibilityNote}
                  </div>
                </td>
                <td>
                  <span
                    className={`badge ${
                      w.status === "recorded" ? "badge-open" : "badge-ok"
                    }`}
                  >
                    {w.status}
                  </span>
                  <div className="muted text-xs mt-1">{w.statusLabel}</div>
                </td>
                <td className="whitespace-nowrap">
                  {w.status === "recorded" && (
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={busyId === w.id}
                        onClick={() => void resolve(w.id, "markPaid")}
                      >
                        Mark paid (ops)
                      </button>
                      <button
                        type="button"
                        className="btn btn-danger text-sm"
                        disabled={busyId === w.id}
                        onClick={() => void resolve(w.id, "decline")}
                      >
                        Decline
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No withdrawals.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
