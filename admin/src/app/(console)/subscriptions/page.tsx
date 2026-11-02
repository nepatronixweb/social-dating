"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import type { AdminSubscriptionOverview } from "@/lib/types";

export default function SubscriptionsPage() {
  const [data, setData] = useState<AdminSubscriptionOverview | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .subscriptionOverview()
      .then(setData)
      .catch((err) =>
        setError(err instanceof ApiError ? err.message : "Failed to load")
      );
  }, []);

  if (error) return <p className="err">{error}</p>;
  if (!data) return <p className="muted">Loading…</p>;

  const cards = [
    ["Male accounts", data.maleAccounts],
    ["Complimentary by gender", data.complimentaryByGender],
    ["Staff overrides", data.staffComplimentaryOverrides],
    ["Needing paid path", data.needingPaidPath],
  ] as const;

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Subscriptions</h1>
        <p className="muted text-sm mt-1">
          Payments / Khalti are not enabled. Grant complimentary Premium on a
          male user&apos;s 360 page.
        </p>
      </header>
      <div className="panel p-4 text-sm">{data.note}</div>
      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-3">
        {cards.map(([label, value]) => (
          <div key={label} className="panel p-4">
            <div className="muted text-xs uppercase tracking-wide">{label}</div>
            <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
              {value.toLocaleString()}
            </div>
          </div>
        ))}
      </div>
      <div className="panel p-4">
        <div className="font-semibold">Checkout outcomes</div>
        <p className="muted text-sm mt-2">
          No purchase history exists yet —{" "}
          {data.paymentsEnabled ? "payments on" : "payments off"}. Failed
          Khalti rows will appear here when checkout is wired.
        </p>
      </div>
    </div>
  );
}
