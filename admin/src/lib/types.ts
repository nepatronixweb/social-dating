export type StaffProfile = {
  id: string;
  email: string;
  displayName: string;
  role: string;
};

export type StaffLoginResponse = {
  accessToken: string;
  expiresAt: string;
  staff: StaffProfile;
};

export type OpsKillSwitches = {
  killWithdrawals: boolean;
  killPremiumCharges: boolean;
  killReferrals: boolean;
  killDiscovery: boolean;
  killChatMessaging: boolean;
};

export type AdminOverview = {
  totalAccounts: number;
  accountsToday: number;
  activeToday: number;
  matchesToday: number;
  swipesToday: number;
  messagesToday: number;
  paidActionsToday: number;
  openReports: number;
  openWithdrawals: number;
  pendingRefunds: number;
  hiddenPhotos: number;
  hiddenMessages: number;
  adminWalletPoints: number;
  premiumSpendPointsToday: number;
  nepalDayKey: string;
  alerts: string[];
  kills: OpsKillSwitches;
};

export type AdminMarketplaceHealth = {
  nepalDayKey: string;
  discoverableMale: number;
  discoverableFemale: number;
  discoverableLgbtq: number;
  discoverableOther: number;
  discoverableTotal: number;
  femaleShare: number;
  swipesToday: number;
  likesToday: number;
  matchesToday: number;
  incompleteMaleProfiles: number;
  supplyNote: string;
  alerts: string[];
  cities: {
    city: string;
    total: number;
    male: number;
    female: number;
    lgbtq: number;
    other: number;
  }[];
};

export type AdminPromoCode = {
  id: string;
  code: string;
  points: number;
  bucket: string;
  maxRedemptions: number;
  redemptionCount: number;
  expiresAt: string | null;
  active: boolean;
  createdByEmail: string | null;
  createdAt: string;
};

export type AdminRuntimeConfig = {
  premiumActionPoints: number;
  extraSwipePoints: number;
  dailyFreePointsMale: number;
  freeDailySwipesMale: number;
  minWithdrawalPoints: number;
  killWithdrawals: boolean;
  killPremiumCharges: boolean;
  killReferrals: boolean;
  killDiscovery: boolean;
  killChatMessaging: boolean;
  maintenanceMode: boolean;
  minClientBuild: number;
  bannerEnabled: boolean;
  bannerTitle: string | null;
  bannerBody: string | null;
  chatKeywordList: string;
  updatedAt: string;
  updatedByEmail: string | null;
};

export type AdminAppealItem = {
  id: string;
  accountId: string;
  accountName: string | null;
  kind: string;
  body: string;
  status: string;
  filedBy: string;
  createdAt: string;
  resolvedAt: string | null;
  slaDueAt: string | null;
  slaState: string;
  ageHours: number;
};

export type AdminPhotoQueueItem = {
  id: string;
  accountId: string;
  accountName: string | null;
  url: string;
  kind: string;
  hidden: boolean;
  reviewStatus: string;
  reviewReason: string | null;
  createdAt: string;
};

export type AdminTimelineItem = {
  id: string;
  kind: string;
  title: string;
  detail: string;
  actorEmail: string | null;
  relatedId: string | null;
  at: string;
};

export type AdminFraudSignal = {
  id: string;
  kind: string;
  severity: string;
  title: string;
  detail: string;
  accountId: string | null;
  accountName: string | null;
  score: number;
  detectedAt: string;
};

export type AttentionQueue = {
  openReports: number;
  overdueReports: number;
  openAppeals: number;
  openKeywordHits: number;
  openWithdrawals: number;
  pendingRefunds: number;
  pendingPhotos: number;
  activeKills: number;
  fraudSignalCount: number;
  items: {
    kind: string;
    severity: string;
    title: string;
    detail: string;
    href: string;
    at: string | null;
  }[];
};

export type PayoutRunSummary = {
  nepalDayKey: string;
  count: number;
  totalPoints: number;
  totalFeePoints: number;
  totalNetPoints: number;
  items: AdminWithdrawalItem[];
};

export type MarkPayoutRunResponse = {
  marked: number;
  totalPoints: number;
  skippedIds: string[];
  message: string;
};

export type RevenueSnapshot = {
  nepalDayKey: string;
  totalSpendPoints: number;
  adminReceivePoints: number;
  byKind: { kind: string; count: number; points: number }[];
};

export type AdminMessageQueueItem = {
  id: string;
  matchId: string;
  senderAccountId: string;
  senderName: string | null;
  body: string;
  hidden: boolean;
  createdAt: string;
};

export type AdminUserSummary = {
  id: string;
  displayName: string | null;
  gender: string | null;
  city: string | null;
  phoneMasked: string;
  spendablePoints: number;
  promotionalPoints: number;
  earnedPoints: number;
  status: string;
  createdAt: string;
  deletedAt: string | null;
  suspendedAt: string | null;
  shadowBannedAt: string | null;
};

export type AdminLedgerItem = {
  id: string;
  accountId: string;
  accountName: string | null;
  points: number;
  bucket: string;
  kind: string;
  title: string;
  detail: string;
  occurredAt: string;
  sourceId: string | null;
};

export type AdminUserDetail = {
  id: string;
  displayName: string | null;
  gender: string | null;
  city: string | null;
  bio: string | null;
  phoneMasked: string;
  phoneE164: string | null;
  spendablePoints: number;
  promotionalPoints: number;
  earnedPoints: number;
  pendingWithdrawalPoints: number;
  status: string;
  createdAt: string;
  deletedAt: string | null;
  suspendedAt: string | null;
  shadowBannedAt: string | null;
  lastWarnedAt: string | null;
  termsAcceptedAt: string | null;
  ageEligible: boolean | null;
  complimentaryPremium: boolean;
  photoCount: number;
  photoUrls: string[];
  activeMatchCount: number;
  blockedByCount: number;
  blockingCount: number;
  swipeDayKey: string | null;
  previewUsed: number;
  dailyUsed: number;
  recentLedger: AdminLedgerItem[];
};

export type AdminWithdrawalItem = {
  id: string;
  accountId: string;
  accountName: string | null;
  phoneMasked: string;
  gender: string | null;
  points: number;
  feePoints: number;
  netPoints: number;
  status: string;
  statusLabel: string;
  currentEarnedPoints: number;
  minWithdrawalPoints: number;
  genderEligible: boolean;
  eligibilityLooksOk: boolean;
  eligibilityNote: string;
  createdAt: string;
  resolvedAt: string | null;
};

export type RefundChargeResponse = {
  ok: boolean;
  requiresApproval: boolean;
  refundRequestId: string | null;
  message: string;
};

export type AdminRefundItem = {
  id: string;
  accountId: string;
  accountName: string | null;
  sourceId: string;
  points: number;
  status: string;
  requestedByEmail: string;
  resolvedByEmail: string | null;
  note: string;
  createdAt: string;
  resolvedAt: string | null;
};

export type AdminReferralInviteItem = {
  id: string;
  referrerAccountId: string;
  referrerName: string | null;
  inviteeAccountId: string;
  inviteeName: string | null;
  codeUsed: string;
  status: string;
  createdAt: string;
  purchasedAt: string | null;
  refundedAt: string | null;
};

export type AdminReferralCommissionItem = {
  id: string;
  inviteId: string;
  referrerAccountId: string;
  referrerName: string | null;
  amountPaisa: number;
  status: string;
  detail: string;
  createdAt: string;
  resolvedAt: string | null;
};

export type AdminDailyGrantList = {
  dayKey: string;
  grantPoints: number;
  recipientCount: number;
  totalPointsGranted: number;
  items: {
    accountId: string;
    displayName: string | null;
    gender: string | null;
    points: number;
    occurredAt: string;
    sourceId: string;
  }[];
};

export type AdminSubscriptionOverview = {
  maleAccounts: number;
  complimentaryByGender: number;
  staffComplimentaryOverrides: number;
  needingPaidPath: number;
  paymentsEnabled: boolean;
  note: string;
};

export type AdminReportItem = {
  id: string;
  reporterAccountId: string;
  reportedAccountId: string;
  reportedName: string | null;
  reason: string;
  detail: string;
  status: string;
  createdAt: string;
  resolvedAt: string | null;
  slaDueAt: string | null;
  slaState: "ok" | "due_soon" | "overdue" | "closed" | string;
  ageHours: number;
  claimedByStaffId: string | null;
  claimedByEmail: string | null;
  claimedAt: string | null;
};

export type AdminAuditItem = {
  id: string;
  staffEmail: string;
  action: string;
  targetType: string | null;
  targetId: string | null;
  detail: string;
  createdAt: string;
};
