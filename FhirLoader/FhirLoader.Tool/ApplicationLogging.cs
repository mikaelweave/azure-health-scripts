using Microsoft.Extensions.Logging;


namespace FhirLoader.Tool
{
    /// <summary>
    /// Class to create loggers for our application.
    /// https://stackoverflow.com/a/65046691
    /// </summary>
    internal static class ApplicationLogging
    {
        public static ILoggerFactory LogFactory { get; } = LoggerFactory.Create(builder =>
        {
            builder.ClearProviders();
            // Clear Microsoft's default providers (like eventlogs and others)
            builder.AddSimpleConsole(options =>
            {
                options.IncludeScopes = true;
                options.TimestampFormat = "hh:mm:ss ";
                options.SingleLine = true;
            })
            .SetMinimumLevel(LogLevel.Debug);
        });

        public static ILogger<T> CreateLogger<T>() => LogFactory.CreateLogger<T>();

        public static ILogger CreateLogger(string name) => LogFactory.CreateLogger(name);
    }
}
