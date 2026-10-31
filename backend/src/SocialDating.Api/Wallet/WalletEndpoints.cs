using SocialDating.Api.Auth;

namespace SocialDating.Api.Wallet;

public static class WalletEndpoints
{
    public static void MapWalletEndpoints(this WebApplication app)
    {
        var wallet = app.MapGroup("/v1/wallet").WithTags("Wallet").RequireAuthorization();
        wallet.MapGet("", FetchSummary);
        wallet.MapGet("/transactions", FetchTransactions);
        wallet.MapGet("/transactions/{id:guid}", FetchTransaction);

        var withdrawals = wallet.MapGroup("/withdrawals");
        withdrawals.MapGet("/eligibility", FetchEligibility);
        withdrawals.MapGet("", FetchWithdrawals);
        withdrawals.MapGet("{id:guid}", FetchWithdrawal);
        withdrawals.MapPost("", SubmitWithdrawal);
        withdrawals.MapPost("{id:guid}/cancel", CancelWithdrawal);
    }

    static async Task<IResult> FetchSummary(
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.FetchSummaryAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchTransactions(
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.FetchTransactionsAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchTransaction(
        Guid id,
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.FetchTransactionAsync(http.User.RequireAccountId(), id, ct));

    static async Task<IResult> FetchEligibility(
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.FetchEligibilityAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchWithdrawals(
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.FetchWithdrawalsAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchWithdrawal(
        Guid id,
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.FetchWithdrawalAsync(http.User.RequireAccountId(), id, ct));

    static async Task<IResult> SubmitWithdrawal(
        SubmitWithdrawalRequest body,
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.SubmitWithdrawalAsync(http.User.RequireAccountId(), body, ct));

    static async Task<IResult> CancelWithdrawal(
        Guid id,
        HttpContext http,
        IWalletService wallet,
        CancellationToken ct
    ) => Results.Ok(await wallet.CancelWithdrawalAsync(http.User.RequireAccountId(), id, ct));
}
