"use client";

import { FormEvent, useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen } from "@/lib/format";
import { canSupportWrite } from "@/lib/rbac";

type Block = {
  id: string;
  kind: string;
  value: string;
  reason: string;
  active: boolean;
  createdAt: string;
  clearedAt: string | null;
};

export default function AuthBlocksPage() {
  const [items, setItems] = useState<Block[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [activeOnly, setActiveOnly] = useState(true);
  const [kind, setKind] = useState<"device" | "ip">("device");
  const [value, setValue] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const canWrite = canSupportWrite(getStaff()?.role);

  async function load(active = activeOnly) {
    setError(null);
    try {
      const res = await api.listAuthBlocks(active ? true : undefined);
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(activeOnly);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeOnly]);

  async function onAdd(e: FormEvent) {
    e.preventDefault();
    if (!canWrite || !value.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await api.addAuthBlock(kind, value.trim(), reason.trim() || undefined);
      setValue("");
      setReason("");
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Add failed");
    } finally {
      setBusy(false);
    }
  }

  async function clear(id: string) {
    setBusy(true);
    try {
      await api.clearAuthBlock(id);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Clear failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Auth blocks</h1>
          <p className="muted text-sm mt-1">
            Block device ids or IPs from OTP verify / refresh
          </p>
        </div>
        <label className="text-sm flex items-center gap-2">
          <input
            type="checkbox"
            checked={activeOnly}
            onChange={(e) => setActiveOnly(e.target.checked)}
          />
          Active only
        </label>
      </header>
      {error && <p className="err">{error}</p>}

      {canWrite && (
        <form className="panel p-4 flex flex-wrap gap-3 items-end" onSubmit={onAdd}>
          <label className="text-sm flex flex-col gap-1">
            Kind
            <select
              className="field w-32"
              value={kind}
              onChange={(e) => setKind(e.target.value as "device" | "ip")}
            >
              <option value="device">device</option>
              <option value="ip">ip</option>
            </select>
          </label>
          <label className="text-sm flex flex-col gap-1 grow min-w-[12rem]">
            Value
            <input
              className="field"
              value={value}
              onChange={(e) => setValue(e.target.value)}
              placeholder="device id or IP"
              required
            />
          </label>
          <label className="text-sm flex flex-col gap-1 grow min-w-[12rem]">
            Reason
            <input
              className="field"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Optional"
            />
          </label>
          <button className="btn btn-primary" type="submit" disabled={busy}>
            Add block
          </button>
        </form>
      )}

      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Kind</th>
              <th>Value</th>
              <th>Reason</th>
              <th>Status</th>
              <th>When</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((b) => (
              <tr key={b.id}>
                <td>
                  <span className="badge">{b.kind}</span>
                </td>
                <td className="font-[family-name:var(--font-mono)] text-sm">
                  {b.value}
                </td>
                <td className="text-sm">{b.reason || "—"}</td>
                <td>{b.active ? "active" : "cleared"}</td>
                <td className="muted text-sm">{formatWhen(b.createdAt)}</td>
                <td>
                  {canWrite && b.active && (
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busy}
                      onClick={() => void clear(b.id)}
                    >
                      Clear
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No blocks.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
