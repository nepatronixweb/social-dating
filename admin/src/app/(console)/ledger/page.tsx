"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints, formatWhen } from "@/lib/format";
import type { AdminLedgerItem } from "@/lib/types";

export default function LedgerPage() {
  const [items, setItems] = useState<AdminLedgerItem[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .adminLedger()
      .then((r) => setItems(r.items))
      .catch((err) =>
        setError(err instanceof ApiError ? err.message : "Failed to load")
      );
  }, []);

  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Admin ledger</h1>
        <p className="muted text-sm mt-1">
          Platform wallet movements (charges, payouts, adjustments)
        </p>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Account</th>
              <th>Title</th>
              <th>Kind</th>
              <th>Points</th>
            </tr>
          </thead>
          <tbody>
            {items.map((e) => (
              <tr key={e.id}>
                <td className="muted text-sm">{formatWhen(e.occurredAt)}</td>
                <td>{e.accountName ?? e.accountId.slice(0, 8)}</td>
                <td>
                  <div>{e.title}</div>
                  <div className="muted text-xs">{e.detail}</div>
                </td>
                <td>{e.kind}</td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(e.points)}
                </td>
              </tr>
            ))}
            {items.length === 0 && !error && (
              <tr>
                <td colSpan={5} className="muted">
                  No ledger entries yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
