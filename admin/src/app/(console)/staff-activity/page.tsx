"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";

type Activity = {
  nepalDayKey: string;
  actionsToday: number;
  actions7d: number;
  byStaffToday: { staffEmail: string; role: string | null; actions: number }[];
  topActionsToday: { action: string; count: number }[];
};

export default function StaffActivityPage() {
  const [data, setData] = useState<Activity | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const res = await api.staffActivity();
        if (!cancelled) {
          setData(res);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof ApiError ? err.message : "Failed to load");
        }
      }
    }
    void load();
    const timer = window.setInterval(() => void load(), 60_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, []);

  if (error) return <p className="err">{error}</p>;
  if (!data) return <p className="muted">Loading staff activity…</p>;

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Staff activity</h1>
        <p className="muted text-sm mt-1">
          Audit volume for Nepal day {data.nepalDayKey} (auto-refresh 60s)
        </p>
      </header>

      <div className="grid sm:grid-cols-2 gap-3">
        <div className="panel p-4">
          <div className="muted text-xs uppercase tracking-wide">Actions today</div>
          <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
            {data.actionsToday.toLocaleString()}
          </div>
        </div>
        <div className="panel p-4">
          <div className="muted text-xs uppercase tracking-wide">Actions 7d</div>
          <div className="text-2xl font-semibold mt-2 font-[family-name:var(--font-mono)]">
            {data.actions7d.toLocaleString()}
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-2 gap-4">
        <section className="panel overflow-x-auto">
          <div className="p-4 font-semibold border-b border-[var(--line)]">
            By staff (today)
          </div>
          <table className="table">
            <thead>
              <tr>
                <th>Email</th>
                <th>Role</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.byStaffToday.map((r) => (
                <tr key={r.staffEmail}>
                  <td className="text-sm">{r.staffEmail}</td>
                  <td className="muted text-sm">{r.role ?? "—"}</td>
                  <td className="font-[family-name:var(--font-mono)]">
                    {r.actions}
                  </td>
                </tr>
              ))}
              {data.byStaffToday.length === 0 && (
                <tr>
                  <td colSpan={3} className="muted">
                    No staff actions today.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </section>

        <section className="panel overflow-x-auto">
          <div className="p-4 font-semibold border-b border-[var(--line)]">
            Top actions (today)
          </div>
          <table className="table">
            <thead>
              <tr>
                <th>Action</th>
                <th>Count</th>
              </tr>
            </thead>
            <tbody>
              {data.topActionsToday.map((r) => (
                <tr key={r.action}>
                  <td className="text-sm font-[family-name:var(--font-mono)]">
                    {r.action}
                  </td>
                  <td>{r.count}</td>
                </tr>
              ))}
              {data.topActionsToday.length === 0 && (
                <tr>
                  <td colSpan={2} className="muted">
                    No actions today.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </section>
      </div>
    </div>
  );
}
