"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen, shortId } from "@/lib/format";
import { canSupportWrite, canSuperadmin } from "@/lib/rbac";
import type { AdminReportItem } from "@/lib/types";

export default function ReportsPage() {
  const search = useSearchParams();
  const initialSla = search.get("sla") ?? "";
  const [status, setStatus] = useState("open");
  const [sla, setSla] = useState(initialSla);
  const [claim, setClaim] = useState("");
  const [items, setItems] = useState<AdminReportItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const staff = getStaff();
  const role = staff?.role;
  const canWrite = canSupportWrite(role);
  const canDestroy = canSuperadmin(role);

  async function load(s = status, slaFilter = sla, claimFilter = claim) {
    setError(null);
    try {
      const res = await api.listReports(
        s || undefined,
        slaFilter || undefined,
        claimFilter || undefined
      );
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(status, sla, claim);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, sla, claim]);

  useEffect(() => {
    const fromUrl = search.get("sla") ?? "";
    if (fromUrl !== sla) setSla(fromUrl);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  async function resolve(
    id: string,
    next: "investigating" | "actioned" | "dismissed",
    moderationAction?: "warn" | "suspend" | "ban" | "none"
  ) {
    const note = window.prompt("Resolution note (optional)") ?? undefined;
    setBusyId(id);
    try {
      await api.resolveReport(id, next, note || undefined, moderationAction);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Resolve failed");
    } finally {
      setBusyId(null);
    }
  }

  async function claimReport(id: string) {
    setBusyId(id);
    try {
      await api.claimReport(id);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Claim failed");
    } finally {
      setBusyId(null);
    }
  }

  async function unclaimReport(id: string) {
    setBusyId(id);
    try {
      await api.unclaimReport(id);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Unclaim failed");
    } finally {
      setBusyId(null);
    }
  }

  function slaBadge(state: string) {
    if (state === "overdue") return "badge-open";
    if (state === "due_soon") return "badge-open";
    if (state === "ok") return "badge-ok";
    return "";
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Reports</h1>
          <p className="muted text-sm mt-1">
            Claim ownership, SLA clocks — warn, hide, ban, or dismiss
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <select
            className="field w-40"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="open">open</option>
            <option value="investigating">investigating</option>
            <option value="actioned">actioned</option>
            <option value="dismissed">dismissed</option>
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
          <select
            className="field w-40"
            value={claim}
            onChange={(e) => setClaim(e.target.value)}
          >
            <option value="">any claim</option>
            <option value="unclaimed">unclaimed</option>
            <option value="mine">mine</option>
            <option value="claimed">claimed</option>
          </select>
        </div>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Reported</th>
              <th>Reason</th>
              <th>Status</th>
              <th>Claim</th>
              <th>SLA</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((r) => {
              const mine = r.claimedByStaffId === staff?.id;
              return (
                <tr key={r.id}>
                  <td className="muted text-sm">{formatWhen(r.createdAt)}</td>
                  <td>
                    <Link
                      className="text-[var(--accent)]"
                      href={`/users/${r.reportedAccountId}`}
                    >
                      {r.reportedName ?? shortId(r.reportedAccountId)}
                    </Link>
                    <div className="muted text-xs">
                      by {shortId(r.reporterAccountId)}
                    </div>
                  </td>
                  <td>
                    <div className="font-medium">{r.reason}</div>
                    <div className="muted text-xs">{r.detail}</div>
                  </td>
                  <td>
                    <span
                      className={`badge ${
                        r.status === "open" || r.status === "investigating"
                          ? "badge-open"
                          : "badge-ok"
                      }`}
                    >
                      {r.status}
                    </span>
                  </td>
                  <td className="text-sm">
                    {r.claimedByEmail ? (
                      <>
                        <div>{r.claimedByEmail}</div>
                        <div className="muted text-xs">
                          {r.claimedAt ? formatWhen(r.claimedAt) : ""}
                        </div>
                      </>
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                  <td>
                    <span className={`badge ${slaBadge(r.slaState)}`}>
                      {r.slaState}
                    </span>
                    <div className="muted text-xs mt-1">
                      {r.ageHours}h
                      {r.slaDueAt ? ` · due ${formatWhen(r.slaDueAt)}` : ""}
                    </div>
                  </td>
                  <td>
                    <div className="flex flex-wrap gap-2 mb-2">
                      <Link
                        className="text-[var(--accent)] text-sm"
                        href={`/users/${r.reportedAccountId}`}
                      >
                        Case
                      </Link>
                      {canWrite &&
                        (r.status === "open" ||
                          r.status === "investigating") &&
                        !r.claimedByStaffId && (
                          <button
                            type="button"
                            className="btn text-sm"
                            disabled={busyId === r.id}
                            onClick={() => void claimReport(r.id)}
                          >
                            Claim
                          </button>
                        )}
                      {canWrite &&
                        r.claimedByStaffId &&
                        (mine || canDestroy) &&
                        (r.status === "open" ||
                          r.status === "investigating") && (
                          <button
                            type="button"
                            className="btn text-sm"
                            disabled={busyId === r.id}
                            onClick={() => void unclaimReport(r.id)}
                          >
                            Unclaim
                          </button>
                        )}
                    </div>
                    {canWrite &&
                      (r.status === "open" || r.status === "investigating") && (
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          className="btn text-sm"
                          disabled={busyId === r.id}
                          onClick={() => void resolve(r.id, "investigating")}
                        >
                          Investigating
                        </button>
                        <button
                          type="button"
                          className="btn text-sm"
                          disabled={busyId === r.id}
                          onClick={() => void resolve(r.id, "actioned", "warn")}
                        >
                          Warn
                        </button>
                        {canDestroy && (
                          <>
                            <button
                              type="button"
                              className="btn text-sm"
                              disabled={busyId === r.id}
                              onClick={() =>
                                void resolve(r.id, "actioned", "suspend")
                              }
                            >
                              Suspend
                            </button>
                            <button
                              type="button"
                              className="btn btn-danger text-sm"
                              disabled={busyId === r.id}
                              onClick={() =>
                                void resolve(r.id, "actioned", "ban")
                              }
                            >
                              Ban
                            </button>
                          </>
                        )}
                        <button
                          type="button"
                          className="btn text-sm"
                          disabled={busyId === r.id}
                          onClick={() => void resolve(r.id, "dismissed")}
                        >
                          Dismiss
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              );
            })}
            {items.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
                  No reports.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
