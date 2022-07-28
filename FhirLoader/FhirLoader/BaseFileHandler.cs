using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Polly;
using Polly.CircuitBreaker;
using Polly.Wrap;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Resources;
using System.Text;
using System.Threading.Tasks;

namespace FhirLoader
{
    public abstract class BaseFileHandler
    {
        string _filePath;
        ILogger<BaseFileHandler> _logger;

        public BaseFileHandler(string filePath, ILogger<BaseFileHandler> logger)
        {
            _filePath = filePath;
            _logger = logger;
        }

        public virtual IEnumerable<(string bundle, int count)> ConvertToBundles()
        {
            throw new NotImplementedException();
        }
    }
}
