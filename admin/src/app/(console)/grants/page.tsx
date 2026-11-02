"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints, formatWhen } from "@/lib/format";
import type { AdminDailyGrantList } from "@/lib/types";

export default function GrantsPage() {
  const [dayKey, setDayKey] = useState("");
  const [data, setData] = useState<AdminDailyGrantList | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load(key?: string) {
    setError(null);
    try {
      setData(await api.dailyFreeGrants(key || undefined));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load();
  }, []);

  function onSearch(e: FormEvent) {
    e.preventDefault();
    void load(dayKey.trim() || undefined);
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            Nepal-day free points
          </h1>
          <p className="muted text-sm mt-1">
            Male promotional daily grants (`dailyFree:YYYY-MM-DD`)
          </p>
        </div>
        <form onSubmit={onSearch} className="flex gap-2">
          <input
            className="field w-40"
            placeholder="YYYY-MM-DD"
            value={dayKey}
            onChange={(e) => setDayKey(e.target.value)}
          />
          <button className="btn" type="submit">
            Load
          </button>
        </form>
      </header>
      {error && <p className="err">{error}</p>}
      {data && (
        <>
          <div className="grid sm:grid-cols-3 gap-3">
            <div className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">Day</div>
              <div className="text-xl font-semibold mt-1 font-[family-name:var(--font-mono)]">
                {data.dayKey}
              </div>
            </div>
            <div className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">
                Recipients
              </div>
              <div className="text-xl font-semibold mt-1 font-[family-name:var(--font-mono)]">
                {data.recipientCount}
              </div>
            </div>
            <div className="panel p-4">
              <div className="muted text-xs uppercase tracking-wide">
                Total granted
              </div>
              <div className="text-xl font-semibold mt-1 font-[family-name:var(--font-mono)]">
                {formatPoints(data.totalPointsGranted)}
              </div>
            </div>
          </div>
          <div className="panel overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>When</th>
                  <th>User</th>
                  <th>Gender</th>
                  <th>Points</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((g) => (
                  <tr key={`${g.accountId}-${g.sourceId}`}>
                    <td className="muted text-sm">
                      {formatWhen(g.occurredAt)}
                    </td>
                    <td>
                      <Link
                        className="text-[var(--accent)]"
                        href={`/users/${g.accountId}`}
                      >
                        {g.displayName ?? g.accountId.slice(0, 8)}
                      </Link>
                    </td>
                    <td>{g.gender ?? "—"}</td>
                    <td className="font-[family-name:var(--font-mono)]">
                      {formatPoints(g.points)}
                    </td>
                    <td className="font-[family-name:var(--font-mono)] text-xs">
                      {g.sourceId}
                    </td>
                  </tr>
                ))}
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={5} className="muted">
                      No grants for this Nepal day yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
