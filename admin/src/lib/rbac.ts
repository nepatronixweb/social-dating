export type StaffRole = "support" | "trust" | "finance" | "superadmin" | string;

export function canSupportWrite(role: StaffRole | null | undefined): boolean {
  const r = (role ?? "").toLowerCase();
  return r === "support" || r === "trust" || r === "superadmin";
}

export function canFinanceWrite(role: StaffRole | null | undefined): boolean {
  const r = (role ?? "").toLowerCase();
  return r === "finance" || r === "superadmin";
}

export function canSuperadmin(role: StaffRole | null | undefined): boolean {
  return (role ?? "").toLowerCase() === "superadmin";
}

/** Nav visibility — everyone can read these; finance-heavy items stay visible to all for overview. */
export function navVisible(
  href: string,
  role: StaffRole | null | undefined
): boolean {
  if (href === "/staff" || href === "/config") return canSuperadmin(role);
  return true;
}

/** Post-login home by role. */
export function homeForRole(role: StaffRole | null | undefined): string {
  const r = (role ?? "").toLowerCase();
  if (r === "finance") return "/payouts";
  if (r === "support" || r === "trust") return "/attention";
  return "/attention";
}
