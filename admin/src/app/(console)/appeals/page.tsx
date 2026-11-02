"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen, shortId } from "@/lib/format";
import { canSupportWrite, canSuperadmin } from "@/lib/rbac";
import type { AdminAppealItem } from "@/lib/types";

export default function AppealsPage() {
  const search = useSearchParams();
  const [status, setStatus] = useState("open");
  const [sla, setSla] = useState(search.get("sla") ?? "");
  const [items, setItems] = useState<AdminAppealItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const role = getStaff()?.role;
  const canWrite = canSupportWrite(role);
  const isSuper = canSuperadmin(role);

  async function load(s = status, slaFilter = sla) {
    setError(null);
    try {
      const res = await api.listAppeals(s || undefined, slaFilter || undefined);
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(status, sla);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, sla]);

  useEffect(() => {
    const fromUrl = search.get("sla") ?? "";
    if (fromUrl !== sla) setSla(fromUrl);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  async function resolve(id: string, decision: "accept" | "reject") {
    const note = window.prompt("Resolution note (optional)") ?? undefined;
    setBusyId(id);
    try {
      await api.resolveAppeal(id, decision, note || undefined);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Resolve failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Appeals</h1>
          <p className="muted text-sm mt-1">
            Restriction appeals with SLA — accept lifts ban / suspend / shadow ban
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <select
            className="field w-40"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="open">open</option>
            <option value="accepted">accepted</option>
            <option value="rejected">rejected</option>
            <option value="">all</option>
          </select>
          <select
            className="field w-40"
            value={sla}
            onChange={(e) => setSla(e.target.value)}
          >
            <option value="">any SLA</option>
            <option value="overdue">overdue</option>
            <option value="due_soon">due soon</option>
            <option value="ok">within SLA</option>
            <option value="closed">closed</option>
          </select>
        </div>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>User</th>
              <th>Kind</th>
              <th>Appeal</th>
              <th>SLA</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((a) => (
              <tr key={a.id}>
                <td className="muted text-sm">{formatWhen(a.createdAt)}</td>
                <td>
                  <Link
                    className="text-[var(--accent)]"
                    href={`/users/${a.accountId}`}
                  >
                    {a.accountName ?? shortId(a.accountId)}
                  </Link>
                  <div className="muted text-xs">via {a.filedBy}</div>
                </td>
                <td>
                  <span className="badge badge-open">{a.kind}</span>
                  <div className="muted text-xs mt-1">{a.status}</div>
                </td>
                <td className="text-sm max-w-sm whitespace-pre-wrap">{a.body}</td>
                <td>
                  <span
                    className={`badge ${
                      a.slaState === "ok" ? "badge-ok" : "badge-open"
                    }`}
                  >
                    {a.slaState}
                  </span>
                  <div className="muted text-xs mt-1">{a.ageHours}h</div>
                </td>
                <td>
                  {canWrite && a.status === "open" && (
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={
                          busyId === a.id || (a.kind === "ban" && !isSuper)
                        }
                        title={
                          a.kind === "ban" && !isSuper
                            ? "Ban appeals need superadmin"
                            : undefined
                        }
                        onClick={() => void resolve(a.id, "accept")}
                      >
                        Accept
                      </button>
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={busyId === a.id}
                        onClick={() => void resolve(a.id, "reject")}
                      >
                        Reject
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No appeals.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
