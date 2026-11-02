import { clearSession, getToken } from "./auth";
import type {
  AdminAuditItem,
  AdminDailyGrantList,
  AdminLedgerItem,
  AdminFraudSignal,
  AdminMarketplaceHealth,
  AdminMessageQueueItem,
  AdminOverview,
  AdminPhotoQueueItem,
  AdminPromoCode,
  AdminTimelineItem,
  AttentionQueue,
  MarkPayoutRunResponse,
  PayoutRunSummary,
  RevenueSnapshot,
  AdminReferralCommissionItem,
  AdminReferralInviteItem,
  AdminRefundItem,
  AdminAppealItem,
  AdminReportItem,
  AdminRuntimeConfig,
  AdminSubscriptionOverview,
  AdminUserDetail,
  AdminUserSummary,
  AdminWithdrawalItem,
  RefundChargeResponse,
  StaffLoginResponse,
  StaffProfile,
} from "./types";

const BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") ??
  "http://localhost:5088";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public detail?: string
  ) {
    super(message);
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  auth = true
): Promise<T> {
  const headers = new Headers(init.headers);
  if (!headers.has("Content-Type") && init.body) {
    headers.set("Content-Type", "application/json");
  }
  if (auth) {
    const token = getToken();
    if (!token) throw new ApiError(401, "Not signed in.");
    headers.set("Authorization", `Bearer ${token}`);
  }

  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  if (res.status === 401 && auth) {
    clearSession();
    if (typeof window !== "undefined") {
      window.location.href = "/login";
    }
    throw new ApiError(401, "Session expired.");
  }

  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    let detail: string | undefined;
    try {
      const body = (await res.json()) as {
        title?: string;
        detail?: string;
        message?: string;
      };
      message = body.title ?? body.message ?? message;
      detail = body.detail;
    } catch {
      /* ignore */
    }
    throw new ApiError(res.status, message, detail);
  }

  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

function postOk(path: string, body?: unknown) {
  return request<{ ok: boolean }>(path, {
    method: "POST",
    body: JSON.stringify(body ?? {}),
  });
}

export const api = {
  login(email: string, password: string) {
    return request<StaffLoginResponse>(
      "/v1/admin/auth/login",
      {
        method: "POST",
        body: JSON.stringify({ email, password }),
      },
      false
    );
  },

  me() {
    return request<StaffProfile>("/v1/admin/me");
  },

  overview() {
    return request<AdminOverview>("/v1/admin/overview");
  },

  attentionQueue() {
    return request<AttentionQueue>("/v1/admin/queues/attention");
  },

  payoutRun() {
    return request<PayoutRunSummary>("/v1/admin/payouts/run");
  },

  markPayoutRun(ids: string[], expectedTotalPoints?: number, note?: string) {
    return request<MarkPayoutRunResponse>("/v1/admin/payouts/run/mark-paid", {
      method: "POST",
      body: JSON.stringify({
        ids,
        expectedTotalPoints: expectedTotalPoints ?? null,
        note: note ?? null,
      }),
    });
  },

  revenueToday() {
    return request<RevenueSnapshot>("/v1/admin/revenue/today");
  },

  marketplaceHealth() {
    return request<AdminMarketplaceHealth>("/v1/admin/marketplace/health");
  },

  getConfig() {
    return request<AdminRuntimeConfig>("/v1/admin/config");
  },

  configHistory() {
    return request<{
      items: {
        id: string;
        snapshotJson: string;
        changedByEmail: string | null;
        createdAt: string;
      }[];
    }>("/v1/admin/config/history");
  },

  updateConfig(body: Partial<AdminRuntimeConfig>) {
    return request<AdminRuntimeConfig>("/v1/admin/config", {
      method: "PUT",
      body: JSON.stringify(body),
    });
  },

  photoQueue(filter?: string) {
    const qs = filter ? `?filter=${encodeURIComponent(filter)}` : "";
    return request<{ items: AdminPhotoQueueItem[] }>(
      `/v1/admin/moderation/photos${qs}`
    );
  },

  setPhotoHidden(id: string, hidden: boolean, note?: string) {
    return postOk(`/v1/admin/moderation/photos/${id}/visibility`, {
      hidden,
      note: note ?? null,
    });
  },

  reviewPhoto(id: string, status: string, reason?: string, note?: string) {
    return postOk(`/v1/admin/moderation/photos/${id}/review`, {
      status,
      reason: reason ?? null,
      note: note ?? null,
    });
  },

  bulkReviewPhotos(
    ids: string[],
    status: "approved" | "rejected",
    reason?: string,
    note?: string
  ) {
    return request<{
      updated: number;
      skippedIds: string[];
      message: string;
    }>("/v1/admin/moderation/photos/bulk-review", {
      method: "POST",
      body: JSON.stringify({
        ids,
        status,
        reason: reason ?? null,
        note: note ?? null,
      }),
    });
  },

  staffActivity() {
    return request<{
      nepalDayKey: string;
      actionsToday: number;
      actions7d: number;
      byStaffToday: { staffEmail: string; role: string | null; actions: number }[];
      topActionsToday: { action: string; count: number }[];
    }>("/v1/admin/staff/activity");
  },

  forceLogout(id: string) {
    return request<{ revokedSessions: number; message: string }>(
      `/v1/admin/users/${id}/force-logout`,
      { method: "POST", body: "{}" }
    );
  },

  listKeywordHits(status?: string) {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    return request<{
      items: {
        id: string;
        messageId: string;
        matchId: string;
        senderAccountId: string;
        senderName: string | null;
        keyword: string;
        messageBody: string;
        status: string;
        createdAt: string;
        resolvedAt: string | null;
      }[];
    }>(`/v1/admin/moderation/keyword-hits${qs}`);
  },

  resolveKeywordHit(id: string, decision: "dismiss" | "actioned", note?: string) {
    return request(`/v1/admin/moderation/keyword-hits/${id}/resolve`, {
      method: "POST",
      body: JSON.stringify({ decision, note: note ?? null }),
    });
  },

  watchlist() {
    return request<{
      items: {
        id: string;
        accountId: string;
        accountName: string | null;
        status: string | null;
        note: string;
        createdAt: string;
      }[];
    }>("/v1/admin/watchlist");
  },

  watchUser(id: string, note?: string) {
    return request(`/v1/admin/users/${id}/watch`, {
      method: "POST",
      body: JSON.stringify({ note: note ?? null }),
    });
  },

  unwatchUser(id: string) {
    return postOk(`/v1/admin/users/${id}/unwatch`);
  },

  casePacket(id: string) {
    return request<{
      accountId: string;
      displayName: string | null;
      status: string;
      onMyWatchlist: boolean;
      openReportsAbout: number;
      openAppeals: number;
      openKeywordHits: number;
      activeMatches: number;
      messagesSent7d: number;
      recentReports: { id: string; kind: string; title: string; detail: string; at: string }[];
      recentAppeals: { id: string; kind: string; title: string; detail: string; at: string }[];
      recentKeywordHits: { id: string; kind: string; title: string; detail: string; at: string }[];
      recentNotes: { id: string; kind: string; title: string; detail: string; at: string }[];
    }>(`/v1/admin/users/${id}/case-packet`);
  },

  linkedAccounts(id: string) {
    return request<{
      accountId: string;
      deviceIds: string[];
      ipAddresses: string[];
      items: {
        accountId: string;
        displayName: string | null;
        status: string;
        linkKind: string;
        linkValue: string;
        lastSeenAt: string;
      }[];
    }>(`/v1/admin/users/${id}/linked-accounts`);
  },

  listAuthBlocks(active?: boolean) {
    const qs =
      active === undefined ? "" : `?active=${active ? "true" : "false"}`;
    return request<{
      items: {
        id: string;
        kind: string;
        value: string;
        reason: string;
        active: boolean;
        createdAt: string;
        clearedAt: string | null;
      }[];
    }>(`/v1/admin/auth-blocks${qs}`);
  },

  addAuthBlock(kind: "device" | "ip", value: string, reason?: string) {
    return request(`/v1/admin/auth-blocks`, {
      method: "POST",
      body: JSON.stringify({ kind, value, reason: reason ?? null }),
    });
  },

  clearAuthBlock(id: string) {
    return postOk(`/v1/admin/auth-blocks/${id}/clear`);
  },

  fraudSignals() {
    return request<{ items: AdminFraudSignal[] }>("/v1/admin/fraud/signals");
  },

  userTimeline(id: string) {
    return request<{ items: AdminTimelineItem[] }>(
      `/v1/admin/users/${id}/timeline`
    );
  },

  addCaseNote(id: string, body: string) {
    return postOk(`/v1/admin/users/${id}/case-notes`, { body });
  },

  shadowBan(id: string, reason?: string) {
    return postOk(`/v1/admin/users/${id}/shadow-ban`, {
      reason: reason ?? null,
    });
  },

  unshadowBan(id: string) {
    return postOk(`/v1/admin/users/${id}/unshadow-ban`);
  },

  messageQueue(q?: string) {
    const qs = q ? `?q=${encodeURIComponent(q)}` : "";
    return request<{ items: AdminMessageQueueItem[] }>(
      `/v1/admin/moderation/messages${qs}`
    );
  },

  setMessageHidden(id: string, hidden: boolean, note?: string) {
    return postOk(`/v1/admin/moderation/messages/${id}/visibility`, {
      hidden,
      note: note ?? null,
    });
  },

  mediaUrl(path: string) {
    if (path.startsWith("http")) return path;
    return `${BASE}${path.startsWith("/") ? "" : "/"}${path}`;
  },

  listUsers(opts?: {
    q?: string;
    gender?: string;
    status?: string;
    city?: string;
    incomplete?: boolean;
  }) {
    const qs = new URLSearchParams();
    if (opts?.q) qs.set("q", opts.q);
    if (opts?.gender) qs.set("gender", opts.gender);
    if (opts?.status) qs.set("status", opts.status);
    if (opts?.city) qs.set("city", opts.city);
    if (opts?.incomplete) qs.set("incomplete", "true");
    const suffix = qs.toString() ? `?${qs}` : "";
    return request<{ items: AdminUserSummary[] }>(`/v1/admin/users${suffix}`);
  },

  getUser(id: string) {
    return request<AdminUserDetail>(`/v1/admin/users/${id}`);
  },

  banUser(id: string, reason?: string) {
    return postOk(`/v1/admin/users/${id}/ban`, { reason: reason ?? null });
  },

  unbanUser(id: string) {
    return postOk(`/v1/admin/users/${id}/unban`);
  },

  suspendUser(id: string, reason?: string) {
    return postOk(`/v1/admin/users/${id}/suspend`, { reason: reason ?? null });
  },

  unsuspendUser(id: string) {
    return postOk(`/v1/admin/users/${id}/unsuspend`);
  },

  warnUser(id: string, reason?: string) {
    return postOk(`/v1/admin/users/${id}/warn`, { reason: reason ?? null });
  },

  clearPhotos(id: string) {
    return postOk(`/v1/admin/users/${id}/clear-photos`);
  },

  unmatchAll(id: string) {
    return postOk(`/v1/admin/users/${id}/unmatch-all`);
  },

  resetSwipeDay(id: string) {
    return postOk(`/v1/admin/users/${id}/reset-swipe-day`);
  },

  refundCharge(id: string, sourceId: string, note?: string) {
    return request<RefundChargeResponse>(
      `/v1/admin/users/${id}/refund-charge`,
      {
        method: "POST",
        body: JSON.stringify({ sourceId, note: note ?? null }),
      }
    );
  },

  setComplimentary(id: string, enabled: boolean) {
    return postOk(`/v1/admin/users/${id}/complimentary-premium`, { enabled });
  },

  adjustPoints(
    id: string,
    body: { points: number; bucket: string; title: string; detail?: string }
  ) {
    return postOk(`/v1/admin/users/${id}/adjust-points`, body);
  },

  adminLedger(take = 80) {
    return request<{ items: AdminLedgerItem[] }>(
      `/v1/admin/ledger/admin?take=${take}`
    );
  },

  listWithdrawals(status?: string) {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    return request<{ items: AdminWithdrawalItem[] }>(
      `/v1/admin/withdrawals${qs}`
    );
  },

  withdrawalsExportUrl(status?: string) {
    const token = getToken();
    const qs = new URLSearchParams();
    if (status) qs.set("status", status);
    // Browser <a download> cannot set Authorization; open via fetch blob instead in UI if needed.
    // For staff local use we append token as a temporary workaround only when exporting via fetch.
    void token;
    return `${BASE}/v1/admin/withdrawals/export.csv${
      qs.toString() ? `?${qs}` : ""
    }`;
  },

  async downloadWithdrawalsCsv(status?: string) {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    const token = getToken();
    if (!token) throw new ApiError(401, "Not signed in.");
    const res = await fetch(`${BASE}/v1/admin/withdrawals/export.csv${qs}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new ApiError(res.status, "Export failed");
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `withdrawals-${status || "all"}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  },

  resolveWithdrawal(id: string, decision: string, note?: string) {
    return request<AdminWithdrawalItem>(
      `/v1/admin/withdrawals/${id}/resolve`,
      {
        method: "POST",
        body: JSON.stringify({ decision, note: note ?? null }),
      }
    );
  },

  listRefunds(status?: string) {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    return request<{ items: AdminRefundItem[] }>(`/v1/admin/refunds${qs}`);
  },

  resolveRefund(id: string, decision: string, note?: string) {
    return request<AdminRefundItem>(`/v1/admin/refunds/${id}/resolve`, {
      method: "POST",
      body: JSON.stringify({ decision, note: note ?? null }),
    });
  },

  listReferralInvites() {
    return request<{ items: AdminReferralInviteItem[] }>(
      "/v1/admin/referrals/invites"
    );
  },

  listReferralCommissions(status?: string) {
    const qs = status ? `?status=${encodeURIComponent(status)}` : "";
    return request<{ items: AdminReferralCommissionItem[] }>(
      `/v1/admin/referrals/commissions${qs}`
    );
  },

  clawbackCommission(id: string, note?: string) {
    return postOk(`/v1/admin/referrals/commissions/${id}/clawback`, {
      note: note ?? null,
    });
  },

  dailyFreeGrants(dayKey?: string) {
    const qs = dayKey ? `?dayKey=${encodeURIComponent(dayKey)}` : "";
    return request<AdminDailyGrantList>(`/v1/admin/grants/daily-free${qs}`);
  },

  subscriptionOverview() {
    return request<AdminSubscriptionOverview>(
      "/v1/admin/subscriptions/overview"
    );
  },

  listAppeals(status?: string, sla?: string) {
    const qs = new URLSearchParams();
    if (status) qs.set("status", status);
    if (sla) qs.set("sla", sla);
    const q = qs.toString();
    return request<{ items: AdminAppealItem[] }>(
      `/v1/admin/appeals${q ? `?${q}` : ""}`
    );
  },

  createAppeal(userId: string, body: string, kind?: string) {
    return request<AdminAppealItem>(`/v1/admin/users/${userId}/appeals`, {
      method: "POST",
      body: JSON.stringify({ body, kind: kind ?? null }),
    });
  },

  resolveAppeal(id: string, decision: "accept" | "reject", note?: string) {
    return request<AdminAppealItem>(`/v1/admin/appeals/${id}/resolve`, {
      method: "POST",
      body: JSON.stringify({ decision, note: note ?? null }),
    });
  },

  listReports(status?: string, sla?: string, claim?: string) {
    const qs = new URLSearchParams();
    if (status) qs.set("status", status);
    if (sla) qs.set("sla", sla);
    if (claim) qs.set("claim", claim);
    const q = qs.toString();
    return request<{ items: AdminReportItem[] }>(
      `/v1/admin/reports${q ? `?${q}` : ""}`
    );
  },

  claimReport(id: string) {
    return request<AdminReportItem>(`/v1/admin/reports/${id}/claim`, {
      method: "POST",
      body: "{}",
    });
  },

  unclaimReport(id: string) {
    return request<AdminReportItem>(`/v1/admin/reports/${id}/unclaim`, {
      method: "POST",
      body: "{}",
    });
  },

  async downloadUsersCsv(opts?: {
    q?: string;
    gender?: string;
    status?: string;
    city?: string;
    incomplete?: boolean;
  }) {
    const token = getToken();
    const qs = new URLSearchParams();
    if (opts?.q) qs.set("q", opts.q);
    if (opts?.gender) qs.set("gender", opts.gender);
    if (opts?.status) qs.set("status", opts.status);
    if (opts?.city) qs.set("city", opts.city);
    if (opts?.incomplete != null) qs.set("incomplete", String(opts.incomplete));
    const res = await fetch(`${BASE}/v1/admin/users/export.csv?${qs}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    if (!res.ok) throw new ApiError(res.status, "Users export failed");
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "users.csv";
    a.click();
    URL.revokeObjectURL(url);
  },

  async downloadUserExport(id: string) {
    const token = getToken();
    const res = await fetch(`${BASE}/v1/admin/users/${id}/export.json`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    if (!res.ok) {
      const text = await res.text();
      throw new ApiError(res.status, text || "Export failed", text);
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `user-${id}-export.json`;
    a.click();
    URL.revokeObjectURL(url);
  },

  eraseUser(id: string, reason?: string) {
    return request<{ accountId: string; message: string; erasedAt: string }>(
      `/v1/admin/users/${id}/erase`,
      {
        method: "POST",
        body: JSON.stringify({ confirm: true, reason: reason ?? null }),
      }
    );
  },

  resolveReport(
    id: string,
    status: string,
    note?: string,
    moderationAction?: string
  ) {
    return request<AdminReportItem>(`/v1/admin/reports/${id}/resolve`, {
      method: "POST",
      body: JSON.stringify({
        status,
        note: note ?? null,
        moderationAction: moderationAction ?? null,
      }),
    });
  },

  listAudit(opts?: {
    q?: string;
    action?: string;
    staffEmail?: string;
    take?: number;
  }) {
    const qs = new URLSearchParams();
    if (opts?.q) qs.set("q", opts.q);
    if (opts?.action) qs.set("action", opts.action);
    if (opts?.staffEmail) qs.set("staffEmail", opts.staffEmail);
    qs.set("take", String(opts?.take ?? 80));
    return request<{ items: AdminAuditItem[] }>(`/v1/admin/audit?${qs}`);
  },

  async downloadAuditCsv(opts?: {
    q?: string;
    action?: string;
    staffEmail?: string;
  }) {
    const qs = new URLSearchParams();
    if (opts?.q) qs.set("q", opts.q);
    if (opts?.action) qs.set("action", opts.action);
    if (opts?.staffEmail) qs.set("staffEmail", opts.staffEmail);
    qs.set("take", "1000");
    const token = getToken();
    if (!token) throw new ApiError(401, "Not signed in.");
    const res = await fetch(`${BASE}/v1/admin/audit/export.csv?${qs}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new ApiError(res.status, "Export failed");
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "audit.csv";
    a.click();
    URL.revokeObjectURL(url);
  },

  listPromos() {
    return request<{ items: AdminPromoCode[] }>("/v1/admin/promos");
  },

  createPromo(body: {
    code: string;
    points: number;
    bucket?: string;
    maxRedemptions?: number;
    expiresAt?: string | null;
  }) {
    return request<AdminPromoCode>("/v1/admin/promos", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },

  setPromoActive(id: string, active: boolean) {
    return postOk(`/v1/admin/promos/${id}/active`, { active });
  },

  broadcast(body: {
    title: string;
    body: string;
    gender?: string;
    city?: string;
    incompleteOnly?: boolean;
  }) {
    return request<{ recipients: number; message: string }>(
      "/v1/admin/broadcast",
      {
        method: "POST",
        body: JSON.stringify({
          title: body.title,
          body: body.body,
          gender: body.gender ?? null,
          city: body.city ?? null,
          incompleteOnly: body.incompleteOnly ?? false,
        }),
      }
    );
  },

  listStaff() {
    return request<{ items: StaffMember[] }>("/v1/admin/staff");
  },

  createStaff(body: {
    email: string;
    displayName: string;
    role: string;
    temporaryPassword: string;
  }) {
    return request<StaffMember>("/v1/admin/staff", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },

  resetStaffPassword(id: string, temporaryPassword: string) {
    return request<StaffMember>(`/v1/admin/staff/${id}/reset-password`, {
      method: "POST",
      body: JSON.stringify({ temporaryPassword }),
    });
  },

  disableStaff(id: string) {
    return postOk(`/v1/admin/staff/${id}/disable`);
  },

  enableStaff(id: string) {
    return postOk(`/v1/admin/staff/${id}/enable`);
  },

  setStaffRole(id: string, role: string) {
    return request<StaffMember>(`/v1/admin/staff/${id}/role`, {
      method: "POST",
      body: JSON.stringify({ role }),
    });
  },

  revokeStaffSessions(id: string) {
    return postOk(`/v1/admin/staff/${id}/revoke-sessions`);
  },
};

export type StaffMember = {
  id: string;
  email: string;
  displayName: string;
  role: string;
  createdAt: string;
  disabledAt: string | null;
  lastLoginAt: string | null;
};
