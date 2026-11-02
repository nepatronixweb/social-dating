"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { clearSession, getStaff, getToken, type StoredStaff } from "@/lib/auth";
import { navVisible } from "@/lib/rbac";

const NAV = [
  { href: "/attention", label: "Needs attention" },
  { href: "/overview", label: "Overview" },
  { href: "/marketplace", label: "Marketplace" },
  { href: "/users", label: "Users" },
  { href: "/ledger", label: "Admin ledger" },
  { href: "/payouts", label: "Payout run" },
  { href: "/withdrawals", label: "Withdrawals" },
  { href: "/refunds", label: "Refunds" },
  { href: "/referrals", label: "Referrals" },
  { href: "/grants", label: "Daily grants" },
  { href: "/promos", label: "Promo codes" },
  { href: "/broadcast", label: "Broadcast" },
  { href: "/subscriptions", label: "Subscriptions" },
  { href: "/reports", label: "Reports" },
  { href: "/appeals", label: "Appeals" },
  { href: "/fraud", label: "Fraud desk" },
  { href: "/blocks", label: "Auth blocks" },
  { href: "/photos", label: "Photo queue" },
  { href: "/messages", label: "Chat queue" },
  { href: "/keywords", label: "Keyword hits" },
  { href: "/watchlist", label: "Watchlist" },
  { href: "/config", label: "Config / kills" },
  { href: "/staff", label: "Staff" },
  { href: "/staff-activity", label: "Staff activity" },
  { href: "/audit", label: "Audit" },
];

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [staff, setStaff] = useState<StoredStaff | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    setStaff(getStaff());
    setReady(true);
  }, [router]);

  if (!ready) {
    return (
      <div className="min-h-screen grid place-items-center muted">
        Checking session…
      </div>
    );
  }

  return (
    <div className="min-h-screen grid md:grid-cols-[220px_1fr]">
      <aside className="panel border-y-0 border-l-0 p-5 flex flex-col gap-6">
        <div>
          <div className="text-lg font-semibold tracking-tight">Social Dating</div>
          <div className="muted text-sm mt-0.5">Staff console</div>
        </div>
        <nav className="flex flex-col gap-1">
          {NAV.filter((item) => navVisible(item.href, staff?.role)).map(
            (item) => {
              const active =
                pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`px-3 py-2 text-sm ${
                    active
                      ? "bg-[var(--accent-soft)] text-[var(--accent)]"
                      : "hover:bg-[#f7fafc]"
                  }`}
                >
                  {item.label}
                </Link>
              );
            }
          )}
        </nav>
        <div className="mt-auto pt-4 border-t border-[var(--line)]">
          <div className="text-sm font-medium truncate">
            {staff?.displayName ?? "Staff"}
          </div>
          <div className="muted text-xs truncate">{staff?.email}</div>
          <div className="muted text-xs mt-1 uppercase tracking-wide">
            {staff?.role}
          </div>
          <button
            type="button"
            className="btn mt-3 w-full text-sm"
            onClick={() => {
              clearSession();
              router.replace("/login");
            }}
          >
            Sign out
          </button>
        </div>
      </aside>
      <main className="p-5 md:p-8 overflow-auto">{children}</main>
    </div>
  );
}
