using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Resources;

namespace FhirLoader
{
    public class BulkFileHandler : BaseFileHandler
    {
        private readonly string _filePath;
        private readonly ILogger<BulkFileHandler> _logger;
        private readonly int _bundleSize;
        int pageNumber = 0;

        public BulkFileHandler(string filePath, int bundleSize, ILogger<BulkFileHandler> logger) : base(filePath, logger)
        {
            _filePath = filePath;
            _bundleSize = bundleSize;
            _logger = logger;
        }

        public override IEnumerable<(string bundle, int count)> ConvertToBundles()
        {
            IEnumerable<string> page;
            List<string> lines = new List<string>();
            while ((page = NextPage()).Any())
            {
                var resourceChunk = page.Select(line => (JObject.Parse(line)));
                var bundle = JObject.FromObject(new
                {
                    resourceType = "Bundle",
                    type = "batch",
                    entry =
                    from r in resourceChunk
                    select new
                    {
                        resource = r,
                        request = new
                        {
                            method = r.ContainsKey("id") ? "PUT" : "POST",
                            url = r.ContainsKey("id") ? $"{r["resourceType"]}/{r["id"]}" : r["resourceType"]
                        }
                    }
                });

                yield return (bundle.ToString(Formatting.Indented), resourceChunk.Count());
            }
        }

        private IEnumerable<string> NextPage()
        {
            var page = File.ReadLines(_filePath).Skip(pageNumber * _bundleSize).Take(_bundleSize);
            pageNumber++;
            return page;
        }
    }
}

