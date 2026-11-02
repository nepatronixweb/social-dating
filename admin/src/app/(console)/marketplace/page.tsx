"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import type { AdminMarketplaceHealth } from "@/lib/types";

export default function MarketplacePage() {
  const [data, setData] = useState<AdminMarketplaceHealth | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .marketplaceHealth()
      .then(setData)
      .catch((err) =>
        setError(err instanceof ApiError ? err.message : "Failed to load")
      );
  }, []);

  if (error) return <p className="err">{error}</p>;
  if (!data) return <p className="muted">Loading marketplace…</p>;

  const mix = [
    { label: "Male", value: data.discoverableMale },
    { label: "Female", value: data.discoverableFemale },
    { label: "LGBTQ+", value: data.discoverableLgbtq },
    { label: "Other", value: data.discoverableOther },
    { label: "Total discoverable", value: data.discoverableTotal },
  ];

  const funnel = [
    { label: "Swipes (24h)", value: data.swipesToday },
    { label: "Likes (24h)", value: data.likesToday },
    { label: "Matches (24h)", value: data.matchesToday },
    { label: "Incomplete male profiles", value: data.incompleteMaleProfiles },
  ];

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Marketplace health</h1>
        <p className="muted text-sm mt-1">
          Nepal day {data.nepalDayKey} · {data.supplyNote}
        </p>
      </header>

      {data.alerts.length > 0 && (
        <div className="panel p-4">
          <div className="text-xs uppercase tracking-wide muted">Alerts</div>
          <ul className="mt-2 space-y-1 text-sm">
            {data.alerts.map((a) => (
              <li key={a}>{a}</li>
            ))}
          </ul>
        </div>
      )}

      <section>
        <h2 className="text-sm font-medium mb-3">Gender mix (discoverable)</h2>
        <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">
          {mix.map((c) => (
            <div key={c.label} className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">{c.label}</div>
              <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
                {c.value.toLocaleString()}
              </div>
            </div>
          ))}
          <div className="panel p-4">
            <div className="muted text-xs uppercase tracking-wide">Non-male share</div>
            <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
              {(data.femaleShare * 100).toFixed(1)}%
            </div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-medium mb-3">Funnel (24h)</h2>
        <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-3">
          {funnel.map((c) => (
            <div key={c.label} className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">{c.label}</div>
              <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
                {c.value.toLocaleString()}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-medium mb-3">City supply heat</h2>
        <div className="panel overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>City</th>
                <th>Total</th>
                <th>Male</th>
                <th>Female</th>
                <th>LGBTQ+</th>
                <th>Other</th>
              </tr>
            </thead>
            <tbody>
              {(data.cities ?? []).map((c) => (
                <tr key={c.city}>
                  <td>{c.city}</td>
                  <td className="font-[family-name:var(--font-mono)]">{c.total}</td>
                  <td className="font-[family-name:var(--font-mono)]">{c.male}</td>
                  <td className="font-[family-name:var(--font-mono)]">{c.female}</td>
                  <td className="font-[family-name:var(--font-mono)]">{c.lgbtq}</td>
                  <td className="font-[family-name:var(--font-mono)]">{c.other}</td>
                </tr>
              ))}
              {(data.cities ?? []).length === 0 && (
                <tr>
                  <td colSpan={6} className="muted text-sm">
                    No city supply yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
