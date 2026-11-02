"use client";

import Link from "next/link";
import { FormEvent, use, useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatPoints, formatWhen } from "@/lib/format";
import {
  canFinanceWrite,
  canSupportWrite,
  canSuperadmin,
} from "@/lib/rbac";
import type { AdminTimelineItem, AdminUserDetail } from "@/lib/types";

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") ??
  "http://localhost:5088";

export default function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const role = getStaff()?.role;
  const finance = canFinanceWrite(role);
  const support = canSupportWrite(role);
  const superadmin = canSuperadmin(role);
  const [user, setUser] = useState<AdminUserDetail | null>(null);
  const [timeline, setTimeline] = useState<AdminTimelineItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  const [points, setPoints] = useState("100");
  const [bucket, setBucket] = useState("promotional");
  const [title, setTitle] = useState("Staff adjustment");
  const [actionReason, setActionReason] = useState("");
  const [caseNote, setCaseNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [packet, setPacket] = useState<Awaited<
    ReturnType<typeof api.casePacket>
  > | null>(null);
  const [linked, setLinked] = useState<Awaited<
    ReturnType<typeof api.linkedAccounts>
  > | null>(null);

  async function load() {
    setError(null);
    try {
      const [u, tl, pk, ln] = await Promise.all([
        api.getUser(id),
        api.userTimeline(id),
        api.casePacket(id),
        api.linkedAccounts(id),
      ]);
      setUser(u);
      setTimeline(tl.items);
      setPacket(pk);
      setLinked(ln);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load user");
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  async function run(label: string, fn: () => Promise<unknown>) {
    setBusy(true);
    setNote(null);
    setError(null);
    try {
      await fn();
      setNote(label);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Action failed");
    } finally {
      setBusy(false);
    }
  }

  async function onAdjust(e: FormEvent) {
    e.preventDefault();
    await run("Points adjusted.", () =>
      api.adjustPoints(id, {
        points: Number(points),
        bucket,
        title: title.trim() || "Staff adjustment",
      })
    );
  }

  if (error && !user) return <p className="err">{error}</p>;
  if (!user) return <p className="muted">Loading user…</p>;

  const reason = actionReason.trim() || undefined;

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/users" className="muted text-sm">
          ← Users
        </Link>
        <div className="flex flex-wrap items-center gap-3 mt-2">
          <h1 className="text-2xl font-semibold tracking-tight">
            {user.displayName ?? "Unnamed"}
          </h1>
          <span
            className={`badge ${
              user.status === "active" ? "badge-ok" : "badge-open"
            }`}
          >
            {user.status}
          </span>
        </div>
        <p className="muted text-sm mt-1">
          {user.phoneMasked}
          {user.phoneE164 ? ` · ${user.phoneE164}` : ""}
          {user.city ? ` · ${user.city}` : ""}
          {user.gender ? ` · ${user.gender}` : ""}
        </p>
      </div>

      {error && <p className="err">{error}</p>}
      {note && <p className="text-[var(--accent)] text-sm">{note}</p>}

      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-3">
        {[
          ["Spendable", formatPoints(user.spendablePoints)],
          ["Promotional", formatPoints(user.promotionalPoints)],
          ["Earned", formatPoints(user.earnedPoints)],
          ["Pending withdrawal", formatPoints(user.pendingWithdrawalPoints)],
          ["Matches", String(user.activeMatchCount)],
          ["Blocking / blocked-by", `${user.blockingCount} / ${user.blockedByCount}`],
          [
            "Swipe day",
            user.swipeDayKey
              ? `${user.swipeDayKey} · preview ${user.previewUsed} · daily ${user.dailyUsed}`
              : "—",
          ],
          [
            "Premium",
            user.complimentaryPremium ? "Complimentary" : "Male paid path",
          ],
        ].map(([label, value]) => (
          <div key={label} className="panel p-4">
            <div className="muted text-xs uppercase tracking-wide">{label}</div>
            <div className="text-lg font-semibold mt-1 font-[family-name:var(--font-mono)]">
              {value}
            </div>
          </div>
        ))}
      </div>

      {user.photoUrls.length > 0 && (
        <div className="panel p-4">
          <div className="font-semibold mb-3">
            Photos ({user.photoCount})
          </div>
          <div className="flex flex-wrap gap-2">
            {user.photoUrls.map((url) => (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                key={url}
                src={url.startsWith("http") ? url : `${API_BASE}${url}`}
                alt=""
                className="w-20 h-20 object-cover border border-[var(--line)]"
              />
            ))}
          </div>
        </div>
      )}

      <div className="panel p-4 flex flex-col gap-3">
        <h2 className="font-semibold">Case timeline</h2>
        {support && (
          <form
            className="flex flex-col sm:flex-row gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              const body = caseNote.trim();
              if (!body) return;
              void run("Note added.", async () => {
                await api.addCaseNote(id, body);
                setCaseNote("");
              });
            }}
          >
            <input
              className="field flex-1"
              placeholder="Add staff note…"
              value={caseNote}
              onChange={(e) => setCaseNote(e.target.value)}
            />
            <button className="btn text-sm" type="submit" disabled={busy}>
              Add note
            </button>
          </form>
        )}
        <ul className="flex flex-col gap-3 max-h-96 overflow-auto">
          {timeline.map((t) => (
            <li
              key={`${t.kind}-${t.id}-${t.at}`}
              className="border-b border-[var(--line)] pb-2 last:border-0"
            >
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <span className="text-sm font-medium">
                  <span className="muted text-xs uppercase mr-2">{t.kind}</span>
                  {t.title}
                </span>
                <span className="muted text-xs">{formatWhen(t.at)}</span>
              </div>
              <p className="text-sm mt-1 whitespace-pre-wrap">{t.detail}</p>
              {t.actorEmail && (
                <p className="muted text-xs mt-0.5">{t.actorEmail}</p>
              )}
            </li>
          ))}
          {timeline.length === 0 && (
            <li className="muted text-sm">No timeline events yet.</li>
          )}
        </ul>
      </div>

      <div className="grid lg:grid-cols-2 gap-4">
        {finance ? (
        <form onSubmit={onAdjust} className="panel p-4 flex flex-col gap-3">
          <h2 className="font-semibold">Adjust points</h2>
          <label className="text-sm flex flex-col gap-1">
            Points (integer; 100 = 1.00)
            <input
              className="field"
              value={points}
              onChange={(e) => setPoints(e.target.value)}
              required
            />
          </label>
          <label className="text-sm flex flex-col gap-1">
            Bucket
            <select
              className="field"
              value={bucket}
              onChange={(e) => setBucket(e.target.value)}
            >
              <option value="promotional">promotional</option>
              <option value="earned">earned</option>
            </select>
          </label>
          <label className="text-sm flex flex-col gap-1">
            Title
            <input
              className="field"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </label>
          <button className="btn btn-primary" type="submit" disabled={busy}>
            Apply adjustment
          </button>
        </form>
        ) : (
          <div className="panel p-4 muted text-sm">
            Point adjustments require finance or superadmin.
          </div>
        )}

        <div className="panel p-4 flex flex-col gap-3">
          <h2 className="font-semibold">Force actions</h2>
          <label className="text-sm flex flex-col gap-1">
            Reason / note
            <input
              className="field"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              placeholder="Optional"
            />
          </label>
          <div className="flex flex-wrap gap-2">
            {support && (
              <>
                <button
                  type="button"
                  className="btn text-sm"
                  disabled={busy}
                  onClick={() =>
                    void run("Warning recorded.", () =>
                      api.warnUser(id, reason)
                    )
                  }
                >
                  Warn
                </button>
                <button
                  type="button"
                  className="btn text-sm"
                  disabled={busy}
                  onClick={() =>
                    void run("Swipe day reset.", () => api.resetSwipeDay(id))
                  }
                >
                  Reset swipe day
                </button>
                <button
                  type="button"
                  className="btn text-sm"
                  disabled={busy}
                  onClick={() => {
                    if (!window.confirm("Revoke all refresh sessions for this user?")) {
                      return;
                    }
                    void run("Sessions revoked.", () => api.forceLogout(id));
                  }}
                >
                  Force logout
                </button>
                {packet?.onMyWatchlist ? (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy}
                    onClick={() =>
                      void run("Removed from watchlist.", () =>
                        api.unwatchUser(id)
                      )
                    }
                  >
                    Unwatch
                  </button>
                ) : (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy}
                    onClick={() => {
                      const note =
                        window.prompt("Watch note (optional)") ?? undefined;
                      void run("Added to watchlist.", () =>
                        api.watchUser(id, note || undefined)
                      );
                    }}
                  >
                    Watch
                  </button>
                )}
                {user.status !== "shadowBanned" ? (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy || user.status === "banned"}
                    onClick={() =>
                      void run("Shadow banned.", () =>
                        api.shadowBan(id, reason)
                      )
                    }
                  >
                    Shadow ban
                  </button>
                ) : (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy}
                    onClick={() =>
                      void run("Shadow ban lifted.", () =>
                        api.unshadowBan(id)
                      )
                    }
                  >
                    Lift shadow ban
                  </button>
                )}
                {(user.status === "banned" ||
                  user.status === "suspended" ||
                  user.status === "shadowBanned") && (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy}
                    onClick={() => {
                      const body =
                        window.prompt(
                          "Appeal text (filed by staff on behalf of user)"
                        ) ?? "";
                      if (body.trim().length < 8) return;
                      void run("Appeal filed.", () =>
                        api.createAppeal(id, body.trim())
                      );
                    }}
                  >
                    File appeal
                  </button>
                )}
              </>
            )}
            {superadmin && (
              <>
                {user.status !== "suspended" ? (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy || user.status === "banned"}
                    onClick={() =>
                      void run("Suspended.", () =>
                        api.suspendUser(id, reason)
                      )
                    }
                  >
                    Suspend
                  </button>
                ) : (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy}
                    onClick={() =>
                      void run("Unsuspended.", () => api.unsuspendUser(id))
                    }
                  >
                    Unsuspend
                  </button>
                )}
                {user.status !== "banned" ? (
                  <button
                    type="button"
                    className="btn btn-danger text-sm"
                    disabled={busy}
                    onClick={() => {
                      if (!window.confirm("Ban this account?")) return;
                      void run("Banned.", () => api.banUser(id, reason));
                    }}
                  >
                    Ban
                  </button>
                ) : (
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busy}
                    onClick={() =>
                      void run("Unbanned.", () => api.unbanUser(id))
                    }
                  >
                    Unban
                  </button>
                )}
                <button
                  type="button"
                  className="btn text-sm"
                  disabled={busy}
                  onClick={() => {
                    if (!window.confirm("Clear all profile photos?")) return;
                    void run("Photos cleared.", () => api.clearPhotos(id));
                  }}
                >
                  Clear photos
                </button>
                <button
                  type="button"
                  className="btn text-sm"
                  disabled={busy}
                  onClick={() => {
                    if (!window.confirm("Unmatch all active pairs?")) return;
                    void run("Unmatched all.", () => api.unmatchAll(id));
                  }}
                >
                  Unmatch all
                </button>
                <button
                  type="button"
                  className="btn btn-danger text-sm"
                  disabled={busy}
                  onClick={() => {
                    if (
                      !window.confirm(
                        "Erase PII and ban this account? This cannot be undone from the console."
                      )
                    ) {
                      return;
                    }
                    void run("Account erased.", () =>
                      api.eraseUser(id, reason)
                    );
                  }}
                >
                  Erase PII
                </button>
              </>
            )}
            <button
              type="button"
              className="btn text-sm"
              disabled={busy}
              onClick={() =>
                void run("Export downloaded.", () =>
                  api.downloadUserExport(id)
                )
              }
            >
              Export JSON
            </button>
            {finance && user.gender === "male" && (
              <button
                type="button"
                className="btn text-sm"
                disabled={busy}
                onClick={() =>
                  void run(
                    user.complimentaryPremium
                      ? "Complimentary Premium revoked."
                      : "Complimentary Premium granted.",
                    () =>
                      api.setComplimentary(id, !user.complimentaryPremium)
                  )
                }
              >
                {user.complimentaryPremium
                  ? "Revoke complimentary Premium"
                  : "Grant complimentary Premium"}
              </button>
            )}
          </div>
          <p className="muted text-xs">
            Joined {formatWhen(user.createdAt)} · Terms{" "}
            {formatWhen(user.termsAcceptedAt)} · Warned{" "}
            {formatWhen(user.lastWarnedAt)} · Age eligible{" "}
            {user.ageEligible == null ? "—" : String(user.ageEligible)}
          </p>
          {user.bio && <p className="text-sm">{user.bio}</p>}
        </div>
      </div>

      {linked && (
        <div className="panel p-4 flex flex-col gap-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="font-semibold">Linked accounts (90d)</h2>
            {support && linked.deviceIds[0] && (
              <button
                type="button"
                className="btn text-sm"
                disabled={busy}
                onClick={() => {
                  const note =
                    window.prompt("Block reason (optional)") ?? undefined;
                  void run("Device blocked.", () =>
                    api.addAuthBlock(
                      "device",
                      linked.deviceIds[0],
                      note || undefined
                    )
                  );
                }}
              >
                Block first device
              </button>
            )}
          </div>
          <p className="muted text-xs">
            Devices: {linked.deviceIds.length ? linked.deviceIds.join(", ") : "—"}
            {" · "}
            IPs: {linked.ipAddresses.length ? linked.ipAddresses.join(", ") : "—"}
          </p>
          {linked.items.length === 0 ? (
            <p className="muted text-sm">No shared device/IP accounts.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="table">
                <thead>
                  <tr>
                    <th>Account</th>
                    <th>Status</th>
                    <th>Link</th>
                    <th>Seen</th>
                  </tr>
                </thead>
                <tbody>
                  {linked.items.map((l) => (
                    <tr key={`${l.accountId}-${l.linkKind}-${l.linkValue}`}>
                      <td>
                        <Link
                          className="text-[var(--accent)]"
                          href={`/users/${l.accountId}`}
                        >
                          {l.displayName ?? l.accountId.slice(0, 8)}
                        </Link>
                      </td>
                      <td>{l.status}</td>
                      <td className="text-sm">
                        <span className="badge">{l.linkKind}</span>{" "}
                        <span className="font-[family-name:var(--font-mono)] text-xs">
                          {l.linkValue}
                        </span>
                      </td>
                      <td className="muted text-sm">
                        {formatWhen(l.lastSeenAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {packet && (
        <div className="panel p-4 flex flex-col gap-4">
          <h2 className="font-semibold">Case packet</h2>
          <div className="grid sm:grid-cols-2 xl:grid-cols-5 gap-3 text-sm">
            <div>
              <div className="muted text-xs uppercase tracking-wide">
                Open reports
              </div>
              <div className="font-[family-name:var(--font-mono)] mt-1">
                {packet.openReportsAbout}
              </div>
            </div>
            <div>
              <div className="muted text-xs uppercase tracking-wide">
                Open appeals
              </div>
              <div className="font-[family-name:var(--font-mono)] mt-1">
                {packet.openAppeals}
              </div>
            </div>
            <div>
              <div className="muted text-xs uppercase tracking-wide">
                Keyword hits
              </div>
              <div className="font-[family-name:var(--font-mono)] mt-1">
                {packet.openKeywordHits}
              </div>
            </div>
            <div>
              <div className="muted text-xs uppercase tracking-wide">
                Active matches
              </div>
              <div className="font-[family-name:var(--font-mono)] mt-1">
                {packet.activeMatches}
              </div>
            </div>
            <div>
              <div className="muted text-xs uppercase tracking-wide">
                Msgs 7d
              </div>
              <div className="font-[family-name:var(--font-mono)] mt-1">
                {packet.messagesSent7d}
              </div>
            </div>
          </div>
          {(
            [
              ["Reports", packet.recentReports],
              ["Appeals", packet.recentAppeals],
              ["Keywords", packet.recentKeywordHits],
              ["Notes", packet.recentNotes],
            ] as const
          ).map(([label, lines]) =>
            lines.length === 0 ? null : (
              <div key={label}>
                <div className="text-sm font-medium mb-2">{label}</div>
                <ul className="flex flex-col gap-2 text-sm">
                  {lines.map((l) => (
                    <li key={l.id} className="border-b border-[var(--line)] pb-2">
                      <div className="font-medium">{l.title}</div>
                      <div className="muted text-xs">{l.detail}</div>
                      <div className="muted text-xs mt-0.5">
                        {formatWhen(l.at)}
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            )
          )}
        </div>
      )}

      <div className="panel overflow-x-auto">
        <div className="px-4 pt-4 font-semibold">Recent ledger</div>
        <table className="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Title</th>
              <th>Bucket</th>
              <th>Points</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {user.recentLedger.map((e) => (
              <tr key={e.id}>
                <td className="muted text-sm">{formatWhen(e.occurredAt)}</td>
                <td>
                  <div>{e.title}</div>
                  <div className="muted text-xs">{e.detail}</div>
                  {e.sourceId && (
                    <div className="muted text-xs font-[family-name:var(--font-mono)]">
                      {e.sourceId}
                    </div>
                  )}
                </td>
                <td>{e.bucket}</td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(e.points)}
                </td>
                <td>
                  {finance &&
                    e.points < 0 &&
                    e.sourceId &&
                    !e.sourceId.includes(":refund") && (
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busy}
                      onClick={() =>
                        void (async () => {
                          setBusy(true);
                          setError(null);
                          try {
                            const res = await api.refundCharge(
                              id,
                              e.sourceId!,
                              reason
                            );
                            setNote(res.message);
                            await load();
                          } catch (err) {
                            setError(
                              err instanceof ApiError
                                ? err.detail ?? err.message
                                : "Refund failed"
                            );
                          } finally {
                            setBusy(false);
                          }
                        })()
                      }
                    >
                      Refund
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {user.recentLedger.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  No ledger rows.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
