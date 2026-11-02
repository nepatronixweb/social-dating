"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints } from "@/lib/format";
import type { AdminOverview } from "@/lib/types";

export default function OverviewPage() {
  const [data, setData] = useState<AdminOverview | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const next = await api.overview();
        if (!cancelled) {
          setData(next);
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
  if (!data) return <p className="muted">Loading overview…</p>;

  const cards = [
    { label: "Accounts", value: data.totalAccounts.toLocaleString() },
    { label: "New today", value: data.accountsToday.toLocaleString() },
    { label: "Active (24h)", value: data.activeToday.toLocaleString() },
    { label: "Matches (24h)", value: data.matchesToday.toLocaleString() },
    { label: "Swipes (24h)", value: data.swipesToday.toLocaleString() },
    { label: "Messages (24h)", value: data.messagesToday.toLocaleString() },
    { label: "Paid actions (24h)", value: data.paidActionsToday.toLocaleString() },
    { label: "Open reports", value: data.openReports.toLocaleString() },
    { label: "Open withdrawals", value: data.openWithdrawals.toLocaleString() },
    { label: "Pending refunds", value: data.pendingRefunds.toLocaleString() },
    { label: "Hidden photos", value: data.hiddenPhotos.toLocaleString() },
    { label: "Hidden messages", value: data.hiddenMessages.toLocaleString() },
    {
      label: "Admin wallet",
      value: formatPoints(data.adminWalletPoints),
    },
    {
      label: "Premium spend today",
      value: formatPoints(data.premiumSpendPointsToday),
    },
  ];

  const killLabels: { key: keyof AdminOverview["kills"]; label: string }[] = [
    { key: "killDiscovery", label: "Discovery" },
    { key: "killChatMessaging", label: "Chat" },
    { key: "killPremiumCharges", label: "Premium charges" },
    { key: "killWithdrawals", label: "Withdrawals" },
    { key: "killReferrals", label: "Referrals" },
  ];

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Live overview</h1>
        <p className="muted text-sm mt-1">Nepal day {data.nepalDayKey}</p>
      </header>

      {data.alerts.length > 0 && (
        <div className="panel p-4 border-[var(--danger,#b42318)]">
          <div className="text-xs uppercase tracking-wide muted">Alerts</div>
          <ul className="mt-2 space-y-1 text-sm">
            {data.alerts.map((a) => (
              <li key={a}>{a}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="panel p-4">
        <div className="text-xs uppercase tracking-wide muted">Kill switches</div>
        <div className="mt-3 flex flex-wrap gap-2">
          {killLabels.map(({ key, label }) => {
            const on = data.kills[key];
            return (
              <span
                key={key}
                className={`text-xs px-2 py-1 border ${
                  on
                    ? "border-[var(--danger,#b42318)] text-[var(--danger,#b42318)]"
                    : "border-[var(--line)] muted"
                }`}
              >
                {label}: {on ? "OFF" : "on"}
              </span>
            );
          })}
        </div>
      </div>

      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="panel p-4">
            <div className="muted text-xs uppercase tracking-wide">{c.label}</div>
            <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
              {c.value}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
