using System;
using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;

namespace Jellyfin2Samsung.Helpers.Core
{
    public class GitHubAuthHandler : DelegatingHandler
    {
        private readonly string? _token;

        public GitHubAuthHandler(string? token)
            : base(new HttpClientHandler())
        {
            _token = token;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            if (!string.IsNullOrEmpty(_token) && IsGitHubRequest(request.RequestUri))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
            }

            return base.SendAsync(request, cancellationToken);
        }

        private static bool IsGitHubRequest(Uri? uri)
        {
            if (uri == null) return false;
            var host = uri.Host;
            return host.Equals("api.github.com", StringComparison.OrdinalIgnoreCase)
                || host.Equals("raw.githubusercontent.com", StringComparison.OrdinalIgnoreCase)
                || host.Equals("github.com", StringComparison.OrdinalIgnoreCase);
        }

        public static string? ResolveToken(AppSettings settings)
        {
            // 1. Explicit setting
            if (!string.IsNullOrWhiteSpace(settings.GitHubToken))
                return settings.GitHubToken.Trim();

            // 2. Environment variable
            var envToken = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
            if (!string.IsNullOrWhiteSpace(envToken))
                return envToken.Trim();

            // 3. GitHub CLI (gh auth token)
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "gh",
                    Arguments = "auth token",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = Process.Start(psi);
                if (process != null)
                {
                    var output = process.StandardOutput.ReadToEnd().Trim();
                    process.WaitForExit(5000);

                    if (process.ExitCode == 0 && !string.IsNullOrWhiteSpace(output))
                        return output;
                }
            }
            catch
            {
                // gh CLI not installed or not authenticated — ignore
            }

            // 4. No token available — unauthenticated requests
            return null;
        }
    }
}
