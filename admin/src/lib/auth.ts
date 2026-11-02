const TOKEN_KEY = "sd_admin_token";
const STAFF_KEY = "sd_admin_staff";

export type StoredStaff = {
  id: string;
  email: string;
  displayName: string;
  role: string;
};

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

export function getStaff(): StoredStaff | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STAFF_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as StoredStaff;
  } catch {
    return null;
  }
}

export function setSession(token: string, staff: StoredStaff) {
  window.localStorage.setItem(TOKEN_KEY, token);
  window.localStorage.setItem(STAFF_KEY, JSON.stringify(staff));
}

export function clearSession() {
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(STAFF_KEY);
}
