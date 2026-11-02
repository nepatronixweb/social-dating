"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError, api } from "@/lib/api";
import { getStaff, getToken, setSession } from "@/lib/auth";
import { homeForRole } from "@/lib/rbac";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("admin@local.test");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (getToken()) router.replace(homeForRole(getStaff()?.role));
  }, [router]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await api.login(email.trim(), password);
      setSession(res.accessToken, res.staff);
      router.replace(homeForRole(res.staff.role));
    } catch (err) {
      const msg =
        err instanceof ApiError
          ? err.detail ?? err.message
          : "Could not sign in.";
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen grid place-items-center p-6">
      <form
        onSubmit={onSubmit}
        className="panel w-full max-w-md p-8 flex flex-col gap-4"
      >
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Staff sign-in</h1>
          <p className="muted text-sm mt-1">
            Local bootstrap: admin@local.test / ChangeMeNow1
          </p>
        </div>
        <label className="flex flex-col gap-1 text-sm">
          Email
          <input
            className="field"
            type="email"
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Password
          <input
            className="field"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>
        {error && <p className="err">{error}</p>}
        <button className="btn btn-primary" type="submit" disabled={busy}>
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}
