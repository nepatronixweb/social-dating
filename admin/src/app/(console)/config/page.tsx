"use client";

import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { canSuperadmin } from "@/lib/rbac";
import type { AdminRuntimeConfig } from "@/lib/types";

type Draft = {
  premiumActionPoints: number;
  extraSwipePoints: number;
  dailyFreePointsMale: number;
  freeDailySwipesMale: number;
  minWithdrawalPoints: number;
  killWithdrawals: boolean;
  killPremiumCharges: boolean;
  killReferrals: boolean;
  killDiscovery: boolean;
  killChatMessaging: boolean;
  maintenanceMode: boolean;
  minClientBuild: number;
  bannerEnabled: boolean;
  bannerTitle: string;
  bannerBody: string;
  chatKeywordList: string;
};

function fromCfg(cfg: AdminRuntimeConfig): Draft {
  return {
    premiumActionPoints: cfg.premiumActionPoints,
    extraSwipePoints: cfg.extraSwipePoints,
    dailyFreePointsMale: cfg.dailyFreePointsMale,
    freeDailySwipesMale: cfg.freeDailySwipesMale,
    minWithdrawalPoints: cfg.minWithdrawalPoints,
    killWithdrawals: cfg.killWithdrawals,
    killPremiumCharges: cfg.killPremiumCharges,
    killReferrals: cfg.killReferrals,
    killDiscovery: cfg.killDiscovery,
    killChatMessaging: cfg.killChatMessaging,
    maintenanceMode: cfg.maintenanceMode,
    minClientBuild: cfg.minClientBuild,
    bannerEnabled: cfg.bannerEnabled,
    bannerTitle: cfg.bannerTitle ?? "",
    bannerBody: cfg.bannerBody ?? "",
    chatKeywordList: cfg.chatKeywordList ?? "",
  };
}

export default function ConfigPage() {
  const [draft, setDraft] = useState<Draft | null>(null);
  const [meta, setMeta] = useState<{ updatedAt: string; by: string | null } | null>(
    null
  );
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [history, setHistory] = useState<
    {
      id: string;
      snapshotJson: string;
      changedByEmail: string | null;
      createdAt: string;
    }[]
  >([]);
  const role = getStaff()?.role;
  const canWrite = canSuperadmin(role);

  async function load() {
    setError(null);
    try {
      const [cfg, hist] = await Promise.all([
        api.getConfig(),
        api.configHistory(),
      ]);
      setDraft(fromCfg(cfg));
      setMeta({ updatedAt: cfg.updatedAt, by: cfg.updatedByEmail });
      setHistory(hist.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function save() {
    if (!draft || !canWrite) return;
    setBusy(true);
    setError(null);
    try {
      const cfg = await api.updateConfig({
        ...draft,
        bannerTitle: draft.bannerTitle,
        bannerBody: draft.bannerBody,
      });
      setDraft(fromCfg(cfg));
      setMeta({ updatedAt: cfg.updatedAt, by: cfg.updatedByEmail });
      const hist = await api.configHistory();
      setHistory(hist.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }

  if (error && !draft) return <p className="err">{error}</p>;
  if (!draft) return <p className="muted">Loading config…</p>;

  function num(
    key: keyof Pick<
      Draft,
      | "premiumActionPoints"
      | "extraSwipePoints"
      | "dailyFreePointsMale"
      | "freeDailySwipesMale"
      | "minWithdrawalPoints"
      | "minClientBuild"
    >,
    label: string
  ) {
    return (
      <label className="flex flex-col gap-1 text-sm">
        <span className="muted text-xs uppercase tracking-wide">{label}</span>
        <input
          className="field"
          type="number"
          disabled={!canWrite || busy}
          value={draft![key]}
          onChange={(e) =>
            setDraft({ ...draft!, [key]: Number(e.target.value) || 0 })
          }
        />
      </label>
    );
  }

  function kill(key: keyof Draft, label: string) {
    const on = Boolean(draft![key]);
    return (
      <label className="flex items-center justify-between gap-3 panel p-3 text-sm">
        <span>{label}</span>
        <input
          type="checkbox"
          disabled={!canWrite || busy}
          checked={on}
          onChange={(e) => setDraft({ ...draft!, [key]: e.target.checked })}
        />
      </label>
    );
  }

  return (
    <div className="flex flex-col gap-6 max-w-xl">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Config / kill switches</h1>
        <p className="muted text-sm mt-1">
          Remote pricing, feature kills, and client ops. Superadmin write only.
          {meta && (
            <>
              {" "}
              Last update {new Date(meta.updatedAt).toLocaleString()}
              {meta.by ? ` by ${meta.by}` : ""}.
            </>
          )}
        </p>
      </header>
      {error && <p className="err">{error}</p>}
      {!canWrite && (
        <p className="muted text-sm">You can view config but not change it.</p>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium">Pricing (points)</h2>
        {num("premiumActionPoints", "Premium action (super / rewind / DM)")}
        {num("extraSwipePoints", "Extra swipe")}
        {num("dailyFreePointsMale", "Daily free points (male)")}
        {num("freeDailySwipesMale", "Free daily swipes (male)")}
        {num("minWithdrawalPoints", "Min withdrawal")}
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="text-sm font-medium">Kill switches (checked = paused)</h2>
        {kill("killDiscovery", "Kill discovery")}
        {kill("killChatMessaging", "Kill chat messaging")}
        {kill("killPremiumCharges", "Kill premium charges")}
        {kill("killWithdrawals", "Kill withdrawals")}
        {kill("killReferrals", "Kill referrals")}
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium">Client ops</h2>
        {kill("maintenanceMode", "Maintenance mode")}
        {num("minClientBuild", "Min client build (0 = unset)")}
        {kill("bannerEnabled", "Show banner")}
        <label className="flex flex-col gap-1 text-sm">
          <span className="muted text-xs uppercase tracking-wide">Banner title</span>
          <input
            className="field"
            disabled={!canWrite || busy}
            value={draft.bannerTitle}
            onChange={(e) =>
              setDraft({ ...draft, bannerTitle: e.target.value })
            }
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="muted text-xs uppercase tracking-wide">Banner body</span>
          <textarea
            className="field min-h-20"
            disabled={!canWrite || busy}
            value={draft.bannerBody}
            onChange={(e) =>
              setDraft({ ...draft, bannerBody: e.target.value })
            }
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="muted text-xs uppercase tracking-wide">
            Chat keyword list (comma-separated)
          </span>
          <textarea
            className="field min-h-16"
            disabled={!canWrite || busy}
            value={draft.chatKeywordList}
            placeholder="scam, western union, gift card"
            onChange={(e) =>
              setDraft({ ...draft, chatKeywordList: e.target.value })
            }
          />
        </label>
      </section>

      {canWrite && (
        <button
          type="button"
          className="btn self-start"
          disabled={busy}
          onClick={() => void save()}
        >
          {busy ? "Saving…" : "Save config"}
        </button>
      )}

      <section>
        <h2 className="text-sm font-medium mb-3">Change history (pre-save snapshots)</h2>
        <div className="panel overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>When</th>
                <th>By</th>
                <th>Snapshot</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.id}>
                  <td className="muted text-sm whitespace-nowrap">
                    {new Date(h.createdAt).toLocaleString()}
                  </td>
                  <td className="text-sm">{h.changedByEmail ?? "—"}</td>
                  <td>
                    <pre className="text-xs whitespace-pre-wrap max-w-xl overflow-auto">
                      {h.snapshotJson}
                    </pre>
                  </td>
                </tr>
              ))}
              {history.length === 0 && (
                <tr>
                  <td colSpan={3} className="muted text-sm">
                    No revisions yet — history starts after the next save.
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
