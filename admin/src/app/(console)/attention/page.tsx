"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints } from "@/lib/format";
import type { AttentionQueue, RevenueSnapshot } from "@/lib/types";

export default function AttentionPage() {
  const [queue, setQueue] = useState<AttentionQueue | null>(null);
  const [revenue, setRevenue] = useState<RevenueSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const [q, r] = await Promise.all([
          api.attentionQueue(),
          api.revenueToday(),
        ]);
        if (!cancelled) {
          setQueue(q);
          setRevenue(r);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof ApiError ? err.message : "Failed to load");
        }
      }
    }
    void load();
    const timer = window.setInterval(() => void load(), 45_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, []);

  if (error) return <p className="err">{error}</p>;
  if (!queue) return <p className="muted">Loading work queue…</p>;

  const counters = [
    { label: "Reports", value: queue.openReports, href: "/reports" },
    {
      label: "Overdue SLA",
      value: queue.overdueReports ?? 0,
      href: "/reports?sla=overdue",
    },
    {
      label: "Appeals",
      value: queue.openAppeals ?? 0,
      href: "/appeals",
    },
    {
      label: "Keyword hits",
      value: queue.openKeywordHits ?? 0,
      href: "/keywords",
    },
    { label: "Withdrawals", value: queue.openWithdrawals, href: "/payouts" },
    { label: "Refunds", value: queue.pendingRefunds, href: "/refunds" },
    { label: "Photos", value: queue.pendingPhotos, href: "/photos" },
    { label: "Kills on", value: queue.activeKills, href: "/config" },
    { label: "Fraud signals", value: queue.fraudSignalCount, href: "/fraud" },
  ];

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Needs attention</h1>
        <p className="muted text-sm mt-1">
          Single work queue across trust, money, and ops kills
        </p>
      </header>

      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">
        {counters.map((c) => (
          <Link key={c.label} href={c.href} className="panel p-4 block hover:bg-[#f7fafc]">
            <div className="muted text-xs uppercase tracking-wide">{c.label}</div>
            <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
              {c.value.toLocaleString()}
            </div>
          </Link>
        ))}
      </div>

      <section className="panel overflow-x-auto">
        <div className="p-4 font-semibold border-b border-[var(--line)]">
          Priority items
        </div>
        <table className="table">
          <thead>
            <tr>
              <th>Severity</th>
              <th>Item</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {queue.items.map((i) => (
              <tr key={`${i.kind}-${i.title}`}>
                <td>
                  <span
                    className={`badge ${
                      i.severity === "high" ? "badge-open" : "badge-ok"
                    }`}
                  >
                    {i.severity}
                  </span>
                </td>
                <td>
                  <div className="font-medium text-sm">{i.title}</div>
                  <div className="muted text-xs mt-0.5">{i.detail}</div>
                </td>
                <td>
                  <Link className="text-[var(--accent)] text-sm" href={i.href}>
                    Open
                  </Link>
                </td>
              </tr>
            ))}
            {queue.items.length === 0 && (
              <tr>
                <td colSpan={3} className="muted text-sm">
                  Nothing queued — quiet day.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </section>

      {revenue && (
        <section>
          <h2 className="text-sm font-medium mb-3">
            Revenue today (Nepal {revenue.nepalDayKey})
          </h2>
          <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-3 mb-3">
            <div className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">User spend</div>
              <div className="text-xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
                {formatPoints(revenue.totalSpendPoints)}
              </div>
            </div>
            <div className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">Admin receive</div>
              <div className="text-xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
                {formatPoints(revenue.adminReceivePoints)}
              </div>
            </div>
          </div>
          <div className="panel overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Kind</th>
                  <th>Count</th>
                  <th>Points</th>
                </tr>
              </thead>
              <tbody>
                {revenue.byKind.map((r) => (
                  <tr key={r.kind}>
                    <td className="text-sm">{r.kind}</td>
                    <td className="font-[family-name:var(--font-mono)]">{r.count}</td>
                    <td className="font-[family-name:var(--font-mono)]">
                      {formatPoints(r.points)}
                    </td>
                  </tr>
                ))}
                {revenue.byKind.length === 0 && (
                  <tr>
                    <td colSpan={3} className="muted text-sm">
                      No spend recorded today.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
