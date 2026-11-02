"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen, shortId } from "@/lib/format";
import { canSupportWrite } from "@/lib/rbac";
import type { AdminPhotoQueueItem } from "@/lib/types";

const REASONS = ["nudity", "fake", "underage", "spam", "other"] as const;

export default function PhotosPage() {
  const [filter, setFilter] = useState("pending");
  const [items, setItems] = useState<AdminPhotoQueueItem[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);
  const canWrite = canSupportWrite(getStaff()?.role);

  async function load(f = filter) {
    setError(null);
    try {
      const res = await api.photoQueue(f);
      setItems(res.items);
      setSelected(new Set());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load");
    }
  }

  useEffect(() => {
    void load(filter);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    if (selected.size === items.length) {
      setSelected(new Set());
      return;
    }
    setSelected(new Set(items.map((p) => p.id)));
  }

  async function review(
    item: AdminPhotoQueueItem,
    status: "approved" | "rejected" | "pending",
    reason?: string
  ) {
    setBusyId(item.id);
    try {
      await api.reviewPhoto(item.id, status, reason);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Review failed");
    } finally {
      setBusyId(null);
    }
  }

  async function reject(item: AdminPhotoQueueItem) {
    const reason =
      window.prompt(`Reject reason (${REASONS.join(", ")})`, "spam") ?? "";
    if (!REASONS.includes(reason as (typeof REASONS)[number])) {
      setError("Use nudity, fake, underage, spam, or other.");
      return;
    }
    await review(item, "rejected", reason);
  }

  async function bulk(status: "approved" | "rejected") {
    const ids = [...selected];
    if (ids.length === 0) return;
    let reason: string | undefined;
    if (status === "rejected") {
      reason =
        window.prompt(`Reject reason (${REASONS.join(", ")})`, "spam") ?? "";
      if (!REASONS.includes(reason as (typeof REASONS)[number])) {
        setError("Use nudity, fake, underage, spam, or other.");
        return;
      }
    }
    setBulkBusy(true);
    try {
      const res = await api.bulkReviewPhotos(ids, status, reason);
      setError(null);
      window.alert(res.message);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Bulk review failed");
    } finally {
      setBulkBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Photo queue</h1>
          <p className="muted text-sm mt-1">
            Review workflow — pending → approved / rejected · bulk select
          </p>
        </div>
        <select
          className="field w-40"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        >
          <option value="pending">pending</option>
          <option value="approved">approved</option>
          <option value="rejected">rejected</option>
          <option value="hidden">hidden</option>
          <option value="recent">all visible</option>
        </select>
      </header>
      {error && <p className="err">{error}</p>}
      {canWrite && items.length > 0 && (
        <div className="flex flex-wrap items-center gap-3">
          <button type="button" className="btn text-sm" onClick={toggleAll}>
            {selected.size === items.length ? "Clear selection" : "Select all"}
          </button>
          <span className="muted text-sm">{selected.size} selected</span>
          <button
            type="button"
            className="btn text-sm"
            disabled={bulkBusy || selected.size === 0}
            onClick={() => void bulk("approved")}
          >
            Approve selected
          </button>
          <button
            type="button"
            className="btn text-sm"
            disabled={bulkBusy || selected.size === 0}
            onClick={() => void bulk("rejected")}
          >
            Reject selected
          </button>
        </div>
      )}
      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">
        {items.map((p) => (
          <div key={p.id} className="panel overflow-hidden">
            {canWrite && (
              <label className="flex items-center gap-2 px-3 pt-3 text-sm">
                <input
                  type="checkbox"
                  checked={selected.has(p.id)}
                  onChange={() => toggle(p.id)}
                />
                Select
              </label>
            )}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={api.mediaUrl(p.url)}
              alt=""
              className="w-full aspect-[3/4] object-cover bg-[#eef2f6]"
            />
            <div className="p-3 flex flex-col gap-2">
              <Link
                className="text-sm text-[var(--accent)]"
                href={`/users/${p.accountId}`}
              >
                {p.accountName ?? shortId(p.accountId)}
              </Link>
              <div className="muted text-xs">
                {p.reviewStatus}
                {p.reviewReason ? ` · ${p.reviewReason}` : ""} ·{" "}
                {formatWhen(p.createdAt)}
              </div>
              {canWrite && (
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busyId === p.id}
                    onClick={() => void review(p, "approved")}
                  >
                    Approve
                  </button>
                  <button
                    type="button"
                    className="btn text-sm"
                    disabled={busyId === p.id}
                    onClick={() => void reject(p)}
                  >
                    Reject
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
        {items.length === 0 && (
          <p className="muted text-sm">No photos in this filter.</p>
        )}
      </div>
    </div>
  );
}
