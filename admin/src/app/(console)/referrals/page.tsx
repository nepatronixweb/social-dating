"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatWhen } from "@/lib/format";
import type {
  AdminReferralCommissionItem,
  AdminReferralInviteItem,
} from "@/lib/types";

export default function ReferralsPage() {
  const [tab, setTab] = useState<"invites" | "commissions">("commissions");
  const [status, setStatus] = useState("");
  const [invites, setInvites] = useState<AdminReferralInviteItem[]>([]);
  const [commissions, setCommissions] = useState<AdminReferralCommissionItem[]>(
    []
  );
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function load() {
    setError(null);
    try {
      if (tab === "invites") {
        setInvites((await api.listReferralInvites()).items);
      } else {
        setCommissions(
          (await api.listReferralCommissions(status || undefined)).items
        );
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, status]);

  async function clawback(id: string) {
    const note = window.prompt("Clawback note (optional)") ?? undefined;
    setBusyId(id);
    try {
      await api.clawbackCommission(id, note || undefined);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Clawback failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Referrals</h1>
          <p className="muted text-sm mt-1">
            Invites and commissions — clawback reverses commission status
          </p>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            className={`btn text-sm ${tab === "commissions" ? "btn-primary" : ""}`}
            onClick={() => setTab("commissions")}
          >
            Commissions
          </button>
          <button
            type="button"
            className={`btn text-sm ${tab === "invites" ? "btn-primary" : ""}`}
            onClick={() => setTab("invites")}
          >
            Invites
          </button>
          {tab === "commissions" && (
            <select
              className="field w-36"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              <option value="">all</option>
              <option value="pending">pending</option>
              <option value="approved">approved</option>
              <option value="paid">paid</option>
              <option value="reversed">reversed</option>
            </select>
          )}
        </div>
      </header>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        {tab === "invites" ? (
          <table className="table">
            <thead>
              <tr>
                <th>When</th>
                <th>Referrer</th>
                <th>Invitee</th>
                <th>Code</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {invites.map((i) => (
                <tr key={i.id}>
                  <td className="muted text-sm">{formatWhen(i.createdAt)}</td>
                  <td>
                    <Link
                      className="text-[var(--accent)]"
                      href={`/users/${i.referrerAccountId}`}
                    >
                      {i.referrerName ?? i.referrerAccountId.slice(0, 8)}
                    </Link>
                  </td>
                  <td>
                    <Link
                      className="text-[var(--accent)]"
                      href={`/users/${i.inviteeAccountId}`}
                    >
                      {i.inviteeName ?? i.inviteeAccountId.slice(0, 8)}
                    </Link>
                  </td>
                  <td className="font-[family-name:var(--font-mono)]">
                    {i.codeUsed}
                  </td>
                  <td>
                    <span className="badge">{i.status}</span>
                  </td>
                </tr>
              ))}
              {invites.length === 0 && (
                <tr>
                  <td colSpan={5} className="muted">
                    No invites.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>When</th>
                <th>Referrer</th>
                <th>Amount (paisa)</th>
                <th>Status</th>
                <th>Detail</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {commissions.map((c) => (
                <tr key={c.id}>
                  <td className="muted text-sm">{formatWhen(c.createdAt)}</td>
                  <td>
                    <Link
                      className="text-[var(--accent)]"
                      href={`/users/${c.referrerAccountId}`}
                    >
                      {c.referrerName ?? c.referrerAccountId.slice(0, 8)}
                    </Link>
                  </td>
                  <td className="font-[family-name:var(--font-mono)]">
                    {c.amountPaisa}
                  </td>
                  <td>
                    <span
                      className={`badge ${
                        c.status === "reversed" ? "badge-open" : "badge-ok"
                      }`}
                    >
                      {c.status}
                    </span>
                  </td>
                  <td className="text-sm">{c.detail}</td>
                  <td>
                    {c.status !== "reversed" && (
                      <button
                        type="button"
                        className="btn btn-danger text-sm"
                        disabled={busyId === c.id}
                        onClick={() => void clawback(c.id)}
                      >
                        Clawback
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {commissions.length === 0 && (
                <tr>
                  <td colSpan={6} className="muted">
                    No commissions.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
