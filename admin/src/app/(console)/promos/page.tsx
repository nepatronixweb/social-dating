"use client";

import { FormEvent, useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatPoints, formatWhen } from "@/lib/format";
import { canFinanceWrite } from "@/lib/rbac";
import type { AdminPromoCode } from "@/lib/types";

export default function PromosPage() {
  const finance = canFinanceWrite(getStaff()?.role);
  const [items, setItems] = useState<AdminPromoCode[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [code, setCode] = useState("");
  const [points, setPoints] = useState("100");
  const [bucket, setBucket] = useState("promotional");
  const [max, setMax] = useState("1000");

  async function load() {
    setError(null);
    try {
      setItems((await api.listPromos()).items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!finance) return;
    setBusy(true);
    try {
      await api.createPromo({
        code: code.trim(),
        points: Number(points),
        bucket,
        maxRedemptions: Number(max),
      });
      setCode("");
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Create failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Promo codes</h1>
        <p className="muted text-sm mt-1">
          Grant promotional or earned points via redeemable codes
        </p>
      </header>
      {error && <p className="err">{error}</p>}

      {finance && (
        <form onSubmit={onCreate} className="panel p-4 grid sm:grid-cols-2 gap-3 max-w-2xl">
          <label className="text-sm flex flex-col gap-1">
            Code
            <input
              className="field"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              required
              minLength={4}
              maxLength={32}
            />
          </label>
          <label className="text-sm flex flex-col gap-1">
            Points
            <input
              className="field"
              type="number"
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
            Max redemptions
            <input
              className="field"
              type="number"
              value={max}
              onChange={(e) => setMax(e.target.value)}
              required
            />
          </label>
          <button className="btn btn-primary sm:col-span-2 self-start" disabled={busy}>
            Create code
          </button>
        </form>
      )}

      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Points</th>
              <th>Uses</th>
              <th>Status</th>
              <th>Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((p) => (
              <tr key={p.id}>
                <td className="font-[family-name:var(--font-mono)]">{p.code}</td>
                <td>
                  {formatPoints(p.points)}{" "}
                  <span className="muted text-xs">{p.bucket}</span>
                </td>
                <td className="font-[family-name:var(--font-mono)]">
                  {p.redemptionCount}/{p.maxRedemptions}
                </td>
                <td>{p.active ? "active" : "off"}</td>
                <td className="muted text-sm">{formatWhen(p.createdAt)}</td>
                <td>
                  {finance && (
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busy}
                      onClick={() => {
                        void (async () => {
                          setBusy(true);
                          try {
                            await api.setPromoActive(p.id, !p.active);
                            await load();
                          } catch (err) {
                            setError(
                              err instanceof ApiError
                                ? err.message
                                : "Update failed"
                            );
                          } finally {
                            setBusy(false);
                          }
                        })();
                      }}
                    >
                      {p.active ? "Disable" : "Enable"}
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted text-sm">
                  No promo codes yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
