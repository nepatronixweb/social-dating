"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatPoints, formatWhen, shortId } from "@/lib/format";
import { canFinanceWrite } from "@/lib/rbac";
import type { AdminWithdrawalItem, PayoutRunSummary } from "@/lib/types";

export default function PayoutsPage() {
  const [run, setRun] = useState<PayoutRunSummary | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const finance = canFinanceWrite(getStaff()?.role);

  async function load() {
    setError(null);
    try {
      const data = await api.payoutRun();
      setRun(data);
      setSelected(new Set(data.items.map((i) => i.id)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const selectedTotal = useMemo(() => {
    if (!run) return 0;
    return run.items
      .filter((i) => selected.has(i.id))
      .reduce((sum, i) => sum + i.points, 0);
  }, [run, selected]);

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll(items: AdminWithdrawalItem[]) {
    if (selected.size === items.length) setSelected(new Set());
    else setSelected(new Set(items.map((i) => i.id)));
  }

  async function markPaid() {
    if (!run || selected.size === 0) return;
    if (
      !window.confirm(
        `Mark ${selected.size} withdrawal(s) paid (${formatPoints(selectedTotal)})? This does not send money to a bank.`
      )
    ) {
      return;
    }
    const opsNote =
      window.prompt("Ops note (optional)") ?? undefined;
    setBusy(true);
    setError(null);
    setNote(null);
    try {
      const res = await api.markPayoutRun(
        [...selected],
        selectedTotal,
        opsNote || undefined
      );
      setNote(res.message);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Mark failed");
    } finally {
      setBusy(false);
    }
  }

  if (error && !run) return <p className="err">{error}</p>;
  if (!run) return <p className="muted">Loading payout run…</p>;

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Payout run</h1>
          <p className="muted text-sm mt-1">
            Nepal {run.nepalDayKey} · recorded holds only · mark paid is an ops
            marker
          </p>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            className="btn text-sm"
            onClick={() => {
              void api
                .downloadWithdrawalsCsv("recorded")
                .catch((err) =>
                  setError(
                    err instanceof ApiError ? err.message : "Export failed"
                  )
                );
            }}
          >
            Export CSV
          </button>
          {finance && (
            <button
              type="button"
              className="btn btn-primary text-sm"
              disabled={busy || selected.size === 0}
              onClick={() => void markPaid()}
            >
              Mark selected paid
            </button>
          )}
        </div>
      </header>

      {error && <p className="err">{error}</p>}
      {note && <p className="text-[var(--accent)] text-sm">{note}</p>}

      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-3">
        {[
          ["In queue", String(run.count)],
          ["Total points", formatPoints(run.totalPoints)],
          ["Selected", formatPoints(selectedTotal)],
          ["Net (all)", formatPoints(run.totalNetPoints)],
        ].map(([label, value]) => (
          <div key={label} className="panel p-4">
            <div className="muted text-xs uppercase tracking-wide">{label}</div>
            <div className="text-xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
              {value}
            </div>
          </div>
        ))}
      </div>

      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>
                <input
                  type="checkbox"
                  checked={
                    run.items.length > 0 && selected.size === run.items.length
                  }
                  onChange={() => toggleAll(run.items)}
                />
              </th>
              <th>When</th>
              <th>User</th>
              <th>Points</th>
              <th>Eligibility</th>
            </tr>
          </thead>
          <tbody>
            {run.items.map((w) => (
              <tr key={w.id}>
                <td>
                  <input
                    type="checkbox"
                    checked={selected.has(w.id)}
                    onChange={() => toggle(w.id)}
                  />
                </td>
                <td className="muted text-sm">{formatWhen(w.createdAt)}</td>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${w.accountId}`}
                  >
                    {w.accountName ?? shortId(w.accountId)}
                  </Link>
                  <div className="muted text-xs">{w.phoneMasked}</div>
                </td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(w.points)}
                </td>
                <td className="text-sm">
                  {w.eligibilityLooksOk ? "ok" : w.eligibilityNote}
                </td>
              </tr>
            ))}
            {run.items.length === 0 && (
              <tr>
                <td colSpan={5} className="muted text-sm">
                  No recorded withdrawals.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
