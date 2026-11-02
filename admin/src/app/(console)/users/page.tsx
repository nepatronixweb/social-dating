"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { ApiError, api } from "@/lib/api";
import { formatPoints, formatWhen } from "@/lib/format";
import type { AdminUserSummary } from "@/lib/types";

export default function UsersPage() {
  const [q, setQ] = useState("");
  const [gender, setGender] = useState("");
  const [status, setStatus] = useState("");
  const [city, setCity] = useState("");
  const [incomplete, setIncomplete] = useState(false);
  const [items, setItems] = useState<AdminUserSummary[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    setBusy(true);
    setError(null);
    try {
      const res = await api.listUsers({
        q: q.trim() || undefined,
        gender: gender || undefined,
        status: status || undefined,
        city: city.trim() || undefined,
        incomplete: incomplete || undefined,
      });
      setItems(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load users");
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function onSearch(e: FormEvent) {
    e.preventDefault();
    void load();
  }

  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Users</h1>
        <p className="muted text-sm mt-1">
          Search and filter by status, gender, city, incomplete profile
        </p>
      </header>
      <form
        onSubmit={onSearch}
        className="flex flex-wrap gap-2 items-end"
      >
        <input
          className="field w-48"
          placeholder="Search…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <select
          className="field w-36"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
        >
          <option value="">any status</option>
          <option value="active">active</option>
          <option value="suspended">suspended</option>
          <option value="shadowBanned">shadowBanned</option>
          <option value="banned">banned</option>
        </select>
        <select
          className="field w-32"
          value={gender}
          onChange={(e) => setGender(e.target.value)}
        >
          <option value="">any gender</option>
          <option value="male">male</option>
          <option value="female">female</option>
          <option value="lgbtq">lgbtq</option>
          <option value="other">other</option>
        </select>
        <input
          className="field w-36"
          placeholder="City…"
          value={city}
          onChange={(e) => setCity(e.target.value)}
        />
        <label className="text-sm flex items-center gap-2 px-2">
          <input
            type="checkbox"
            checked={incomplete}
            onChange={(e) => setIncomplete(e.target.checked)}
          />
          Incomplete
        </label>
        <button className="btn" type="submit" disabled={busy}>
          Apply
        </button>
        <button
          className="btn"
          type="button"
          disabled={busy}
          onClick={() => {
            void api
              .downloadUsersCsv({
                q: q.trim() || undefined,
                gender: gender || undefined,
                status: status || undefined,
                city: city.trim() || undefined,
                incomplete: incomplete || undefined,
              })
              .catch((err) =>
                setError(
                  err instanceof ApiError ? err.message : "Export failed"
                )
              );
          }}
        >
          Export CSV
        </button>
      </form>
      {error && <p className="err">{error}</p>}
      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Status</th>
              <th>Phone</th>
              <th>City</th>
              <th>Spendable</th>
              <th>Earned</th>
              <th>Joined</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((u) => (
              <tr key={u.id}>
                <td>
                  <div className="font-medium">{u.displayName ?? "—"}</div>
                  <div className="muted text-xs">{u.gender ?? ""}</div>
                </td>
                <td>
                  <span
                    className={`badge ${
                      u.status === "active" ? "badge-ok" : "badge-open"
                    }`}
                  >
                    {u.status}
                  </span>
                </td>
                <td>{u.phoneMasked}</td>
                <td>{u.city ?? "—"}</td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(u.spendablePoints)}
                </td>
                <td className="font-[family-name:var(--font-mono)]">
                  {formatPoints(u.earnedPoints)}
                </td>
                <td className="muted text-sm">{formatWhen(u.createdAt)}</td>
                <td>
                  <Link className="text-[var(--accent)] text-sm" href={`/users/${u.id}`}>
                    Open
                  </Link>
                </td>
              </tr>
            ))}
            {!busy && items.length === 0 && (
              <tr>
                <td colSpan={8} className="muted">
                  No users found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
