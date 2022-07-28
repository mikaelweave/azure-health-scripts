using Microsoft.Identity.Client;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FhirLoader.Tool
{
    internal static class Auth
    {
    internal static async Task<string> SignInUserAndGetTokenUsingMSAL(PublicClientApplicationOptions configuration, string fhirUrl)
    {
        string authority = string.Concat(configuration.Instance, configuration.TenantId);

        // Initialize the MSAL library by building a public client application
        IPublicClientApplication application = PublicClientApplicationBuilder.Create(configuration.ClientId)
                                                  .WithAuthority(authority)
                                                  .WithDefaultRedirectUri()
                                                  .Build();

        AuthenticationResult result;
        var scopes = new List<string>() { $"{fhirUrl}/.default" };
        try
        {
            var accounts = await application.GetAccountsAsync();
            result = await application.AcquireTokenSilent(scopes, accounts.FirstOrDefault()).ExecuteAsync();
        }
        catch (MsalUiRequiredException ex)
        {
            result = await application.AcquireTokenInteractive(scopes)
            .WithClaims(ex.Claims)
            .ExecuteAsync();
        }

        return result.AccessToken;
    }
    }
}
