using System.Text;
using Polly;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Polly.Wrap;
using System.Net;
using Polly.CircuitBreaker;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

namespace FhirLoader.Tool
{
    internal class BundleSender
    {
        HttpClient _client;

        ILogger<BundleSender> _logger;

        internal BundleSender(HttpClient client, ILogger<BundleSender> logger)
        {
            _client = client;
            _logger = logger;
        }

        internal async Task SendIt(string bundleString, int resourceCount)
        {
            var timer = new Stopwatch();
            timer.Start();

            var resiliencyStrategy = DefineAndRetrieveResiliencyStrategy();
            var content = new StringContent(bundleString, Encoding.UTF8, "application/json");

            HttpResponseMessage response;

            try
            {
                _logger.LogTrace($"Sending {resourceCount} resources to {_client.BaseAddress}...");
                // Execute the REST API call, implementing our resiliency strategy.
                response = await resiliencyStrategy.ExecuteAsync(() => _client.PostAsync("", content));
            }
            catch (BrokenCircuitException bce)
            {
                _logger.LogCritical($"Could not contact the FHIR API service due to the following error: {bce.Message}");
                Environment.Exit(1);
                throw;
            }
            catch (Exception e)
            {
                _logger.LogCritical($"Critical error: {e.Message}", e);
                Environment.Exit(1);
                throw;
            }

            timer.Stop();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError($"ERROR: {response.StatusCode}");
                _logger.LogError(JValue.Parse(response.Content.ToString() ?? "{}").ToString(Formatting.Indented));
            }
            else
            {

                Metrics.Instance.RecordBundlesSent(resourceCount, timer.ElapsedMilliseconds);
                _logger.LogTrace("Successfully sent bundle.");
            }
        }

        // http://www.thepollyproject.org/2018/03/06/policy-recommendations-for-azure-cognitive-services/
        private AsyncPolicyWrap<HttpResponseMessage> DefineAndRetrieveResiliencyStrategy()
        {
            var rnd = new Random();

            // Retry when these status codes are encountered.
            HttpStatusCode[] httpStatusCodesWorthRetrying = {
               HttpStatusCode.InternalServerError, // 500
               HttpStatusCode.BadGateway, // 502
               HttpStatusCode.GatewayTimeout, // 504
            };

            // Define our waitAndRetry policy: retry n times with an exponential backoff in case the FHIR API throttles us for too many requests.
            var waitAndRetryPolicy = Policy
                .HandleResult<HttpResponseMessage>(e => e.StatusCode == HttpStatusCode.ServiceUnavailable || e.StatusCode == (HttpStatusCode)429)
                .WaitAndRetryAsync(5, // Retry 5 times with a delay between retries before ultimately giving up
                    attempt => TimeSpan.FromMilliseconds(2000 + rnd.Next(50) * Math.Pow(2, attempt)), // Back off!  2, 4, 8, 16 etc times 2 seconds plus a random number
                                                                                  //attempt => TimeSpan.FromSeconds(6), // Wait 6 seconds between retries
                    (exception, calculatedWaitDuration) =>
                    {
                        _logger.LogWarning($"FHIR API server throttling our requests. Automatically delaying for {calculatedWaitDuration.TotalMilliseconds}ms");
                    }
                );

            // Define our first CircuitBreaker policy: Break if the action fails 4 times in a row.
            // This is designed to handle Exceptions from the FHIR API, as well as
            // a number of recoverable status messages, such as 500, 502, and 504.
            var circuitBreakerPolicyForRecoverable = Policy
                .Handle<HttpRequestException>()
                .OrResult<HttpResponseMessage>(r => httpStatusCodesWorthRetrying.Contains(r.StatusCode))
                .CircuitBreakerAsync(
                    handledEventsAllowedBeforeBreaking: 3,
                    durationOfBreak: TimeSpan.FromSeconds(3),
                    onBreak: (outcome, breakDelay) =>
                    {
                        _logger.LogWarning($"Polly Circuit Breaker logging: Breaking the circuit for {breakDelay.TotalMilliseconds}ms due to: {outcome.Exception?.Message ?? outcome.Result.StatusCode.ToString()}");
                    },
                    onReset: () => _logger.LogWarning("Polly Circuit Breaker logging: Call ok... closed the circuit again"),
                    onHalfOpen: () => _logger.LogWarning("Polly Circuit Breaker logging: Half-open: Next call is a trial")
                );

            // Combine the waitAndRetryPolicy and circuit breaker policy into a PolicyWrap. This defines our resiliency strategy.
            return Policy.WrapAsync(waitAndRetryPolicy, circuitBreakerPolicyForRecoverable);
        }
    }
}
