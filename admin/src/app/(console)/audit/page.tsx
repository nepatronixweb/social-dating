"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatWhen, shortId } from "@/lib/format";
import type { AdminAuditItem } from "@/lib/types";

export default function AuditPage() {
  const [items, setItems] = useState<AdminAuditItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [action, setAction] = useState("");
  const [staffEmail, setStaffEmail] = useState("");

  async function load(
    next: { q: string; action: string; staffEmail: string } = {
      q,
      action,
      staffEmail,
    }
  ) {
    setError(null);
    try {
      const res = await api.listAudit({
        q: next.q || undefined,
        action: next.action || undefined,
        staffEmail: next.staffEmail || undefined,
      });
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load({ q: "", action: "", staffEmail: "" });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Audit log</h1>
          <p className="muted text-sm mt-1">Staff actions with filters</p>
        </div>
        <button
          type="button"
          className="btn text-sm"
          onClick={() => {
            void api
              .downloadAuditCsv({
                q: q || undefined,
                action: action || undefined,
                staffEmail: staffEmail || undefined,
              })
              .catch((err) =>
                setError(err instanceof ApiError ? err.message : "Export failed")
              );
          }}
        >
          Export CSV
        </button>
      </header>

      <form
        className="flex flex-wrap gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          void load();
        }}
      >
        <input
          className="field w-48"
          placeholder="Search detail/target…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <input
          className="field w-40"
          placeholder="Action contains…"
          value={action}
          onChange={(e) => setAction(e.target.value)}
        />
        <input
          className="field w-48"
          placeholder="Staff email…"
          value={staffEmail}
          onChange={(e) => setStaffEmail(e.target.value)}
        />
        <button type="submit" className="btn text-sm">
          Filter
        </button>
      </form>

      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Staff</th>
              <th>Action</th>
              <th>Target</th>
              <th>Detail</th>
            </tr>
          </thead>
          <tbody>
            {items.map((a) => (
              <tr key={a.id}>
                <td className="muted text-sm">{formatWhen(a.createdAt)}</td>
                <td>{a.staffEmail}</td>
                <td>{a.action}</td>
                <td className="muted text-sm">
                  {a.targetType ?? "—"}
                  {a.targetId ? ` · ${shortId(a.targetId)}` : ""}
                </td>
                <td className="text-sm">{a.detail}</td>
              </tr>
            ))}
            {items.length === 0 && !error && (
              <tr>
                <td colSpan={5} className="muted">
                  No audit events match.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
