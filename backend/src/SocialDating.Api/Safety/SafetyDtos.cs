namespace SocialDating.Api.Safety;

public sealed record SubmitReportRequest(
    string ReportedAccountId,
    string Category,
    string? Details
);

public sealed record SafetyReportResponse(
    string Id,
    string Category,
    string Details,
    string? SubjectName,
    string ReportedAccountId,
    DateTimeOffset CreatedAt
);
