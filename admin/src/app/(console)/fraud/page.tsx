"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatWhen, shortId } from "@/lib/format";
import type { AdminFraudSignal } from "@/lib/types";

export default function FraudPage() {
  const [items, setItems] = useState<AdminFraudSignal[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .fraudSignals()
      .then((res) => setItems(res.items))
      .catch((err) =>
        setError(err instanceof ApiError ? err.message : "Failed to load")
      );
  }, []);

  if (error) return <p className="err">{error}</p>;

  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Fraud desk</h1>
        <p className="muted text-sm mt-1">
          Heuristic signals — repeat reporters, swipe spam, referral rings,
          withdraw-then-restrict, multi-account device/IP. Block devices from{" "}
          <Link className="text-[var(--accent)]" href="/blocks">
            Auth blocks
          </Link>
          .
        </p>
      </header>
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Severity</th>
              <th>Kind</th>
              <th>Signal</th>
              <th>Account</th>
              <th>Score</th>
              <th>When</th>
            </tr>
          </thead>
          <tbody>
            {items.map((s) => (
              <tr key={s.id}>
                <td>
                  <span
                    className={`badge ${
                      s.severity === "high" ? "badge-open" : "badge-ok"
                    }`}
                  >
                    {s.severity}
                  </span>
                </td>
                <td className="muted text-sm">{s.kind}</td>
                <td>
                  <div className="font-medium text-sm">{s.title}</div>
                  <div className="muted text-xs mt-0.5">{s.detail}</div>
                </td>
                <td>
                  {s.accountId ? (
                    <Link
                      className="text-[var(--accent)]"
                      href={`/users/${s.accountId}`}
                    >
                      {s.accountName ?? shortId(s.accountId)}
                    </Link>
                  ) : (
                    "—"
                  )}
                </td>
                <td className="font-[family-name:var(--font-mono)]">{s.score}</td>
                <td className="muted text-sm">{formatWhen(s.detectedAt)}</td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted text-sm">
                  No signals right now.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
