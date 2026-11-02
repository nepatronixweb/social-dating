"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError, api, type StaffMember } from "@/lib/api";
import { getStaff } from "@/lib/auth";
import { formatWhen } from "@/lib/format";
import { canSuperadmin } from "@/lib/rbac";

export default function StaffPage() {
  const router = useRouter();
  const [items, setItems] = useState<StaffMember[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [email, setEmail] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [role, setRole] = useState("support");
  const [password, setPassword] = useState("");

  async function load() {
    setError(null);
    try {
      setItems((await api.listStaff()).items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to load staff");
    }
  }

  useEffect(() => {
    if (!canSuperadmin(getStaff()?.role)) {
      router.replace("/overview");
      return;
    }
    void load();
  }, [router]);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setNote(null);
    setError(null);
    try {
      await api.createStaff({
        email: email.trim(),
        displayName: displayName.trim(),
        role,
        temporaryPassword: password,
      });
      setEmail("");
      setDisplayName("");
      setPassword("");
      setNote("Staff invited. Share the temporary password out of band.");
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Create failed");
    } finally {
      setBusy(false);
    }
  }

  async function resetPassword(id: string) {
    const next = window.prompt("New temporary password (min 8 chars)");
    if (!next) return;
    setBusy(true);
    try {
      await api.resetStaffPassword(id, next);
      setNote("Password reset.");
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.detail ?? err.message : "Reset failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Staff</h1>
        <p className="muted text-sm mt-1">
          Invite support / finance / superadmin. Bootstrap seed is only used when
          the table is empty.
        </p>
      </header>

      {error && <p className="err">{error}</p>}
      {note && <p className="text-[var(--accent)] text-sm">{note}</p>}

      <form onSubmit={onCreate} className="panel p-4 grid md:grid-cols-2 gap-3">
        <h2 className="font-semibold md:col-span-2">Invite staff</h2>
        <label className="text-sm flex flex-col gap-1">
          Email
          <input
            className="field"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </label>
        <label className="text-sm flex flex-col gap-1">
          Display name
          <input
            className="field"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            required
          />
        </label>
        <label className="text-sm flex flex-col gap-1">
          Role
          <select
            className="field"
            value={role}
            onChange={(e) => setRole(e.target.value)}
          >
            <option value="support">support</option>
            <option value="finance">finance</option>
            <option value="superadmin">superadmin</option>
          </select>
        </label>
        <label className="text-sm flex flex-col gap-1">
          Temporary password
          <input
            className="field"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            minLength={8}
            required
          />
        </label>
        <button className="btn btn-primary md:col-span-2" type="submit" disabled={busy}>
          Create staff
        </button>
      </form>

      <div className="panel overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Status</th>
              <th>Joined</th>
              <th>Last login</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((s) => (
              <tr key={s.id}>
                <td className="font-medium">{s.displayName}</td>
                <td>{s.email}</td>
                <td>
                  <select
                    className="field"
                    value={s.role}
                    disabled={busy}
                    onChange={(e) => {
                      void (async () => {
                        setBusy(true);
                        try {
                          await api.setStaffRole(s.id, e.target.value);
                          await load();
                        } catch (err) {
                          setError(
                            err instanceof ApiError
                              ? err.detail ?? err.message
                              : "Role update failed"
                          );
                        } finally {
                          setBusy(false);
                        }
                      })();
                    }}
                  >
                    <option value="support">support</option>
                    <option value="finance">finance</option>
                    <option value="superadmin">superadmin</option>
                  </select>
                </td>
                <td>
                  <span
                    className={`badge ${
                      s.disabledAt ? "badge-open" : "badge-ok"
                    }`}
                  >
                    {s.disabledAt ? "disabled" : "active"}
                  </span>
                </td>
                <td className="muted text-sm">{formatWhen(s.createdAt)}</td>
                <td className="muted text-sm">
                  {s.lastLoginAt ? formatWhen(s.lastLoginAt) : "—"}
                </td>
                <td className="whitespace-nowrap">
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busy}
                      onClick={() => void resetPassword(s.id)}
                    >
                      Reset password
                    </button>
                    <button
                      type="button"
                      className="btn text-sm"
                      disabled={busy}
                      onClick={() =>
                        void (async () => {
                          if (
                            !window.confirm(
                              `Revoke all sessions for ${s.email}?`
                            )
                          ) {
                            return;
                          }
                          setBusy(true);
                          try {
                            await api.revokeStaffSessions(s.id);
                            setNote("Sessions revoked.");
                          } catch (err) {
                            setError(
                              err instanceof ApiError
                                ? err.detail ?? err.message
                                : "Revoke failed"
                            );
                          } finally {
                            setBusy(false);
                          }
                        })()
                      }
                    >
                      Revoke sessions
                    </button>
                    {s.disabledAt ? (
                      <button
                        type="button"
                        className="btn text-sm"
                        disabled={busy}
                        onClick={() =>
                          void (async () => {
                            setBusy(true);
                            try {
                              await api.enableStaff(s.id);
                              await load();
                            } catch (err) {
                              setError(
                                err instanceof ApiError
                                  ? err.detail ?? err.message
                                  : "Enable failed"
                              );
                            } finally {
                              setBusy(false);
                            }
                          })()
                        }
                      >
                        Enable
                      </button>
                    ) : (
                      <button
                        type="button"
                        className="btn btn-danger text-sm"
                        disabled={busy}
                        onClick={() =>
                          void (async () => {
                            if (!window.confirm(`Disable ${s.email}?`)) return;
                            setBusy(true);
                            try {
                              await api.disableStaff(s.id);
                              await load();
                            } catch (err) {
                              setError(
                                err instanceof ApiError
                                  ? err.detail ?? err.message
                                  : "Disable failed"
                              );
                            } finally {
                              setBusy(false);
                            }
                          })()
                        }
                      >
                        Disable
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No staff yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
