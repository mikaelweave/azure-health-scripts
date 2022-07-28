using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.Metrics;
using System.Diagnostics.Tracing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FhirLoader.Tool
{
    internal class Metrics
    {
        public static Metrics Instance = new Metrics();

        private Meter s_meter;
        static Counter<int> s_resourcesProcessed;

        private MeterListener meterListener = new MeterListener();
        private ILogger _logger = ApplicationLogging.CreateLogger("Metrics");

        // Used to print resource rates
        const int OUTPUT_REFRESH = 5000;
        private DateTime _lastPrintTime = DateTime.Now;
        private DateTime _startTime = DateTime.Now;
        private readonly ConcurrentBag<int> _resourceCount;
        private int _windowIndex = 0;

        public Metrics()
        {
            s_meter = new Meter("FhirLoader.Tool", "1.0.0");
            s_resourcesProcessed = s_meter.CreateCounter<int>(name: "resources-processed", unit: "Resources", description: "The number of FHIR resources processed by the server");
            _resourceCount = new ConcurrentBag<int>();

            meterListener = new MeterListener();
            _logger = ApplicationLogging.CreateLogger("Metrics");
            meterListener.InstrumentPublished = (instrument, listener) =>
            {
                if (instrument.Meter.Name == s_meter.Name)
                {
                    listener.EnableMeasurementEvents(instrument);
                }
            };
            meterListener.SetMeasurementEventCallback<int>(OnMeasurementRecorded);
        }
        

        public void Start()
        {
            meterListener.Start();
            _lastPrintTime = DateTime.Now;
            _startTime = DateTime.Now;
        }

        public void Stop()
        {
            meterListener.Dispose();
        }

        public void RecordBundlesSent(int resourceCount, long time)
        {
            s_resourcesProcessed.Add(resourceCount);
            meterListener.RecordObservableInstruments();
        }

        void OnMeasurementRecorded(Instrument instrument, int measurement, ReadOnlySpan<KeyValuePair<string, object>> tags, object state)
        {
            if (instrument.Name != s_resourcesProcessed.Name)
            {
                _logger.LogTrace($"{instrument.Name} recorded measurement {measurement}");
                return;
            }

            _resourceCount.Add(measurement);
            int programTotal = _resourceCount.Sum();
            _logger.LogInformation($"Bundle processed with {measurement} resources. {programTotal} total resources processed.");

            var timeChange = (DateTime.Now - _lastPrintTime).TotalMilliseconds;
            if (timeChange > OUTPUT_REFRESH)
            {
                _lastPrintTime = DateTime.Now;
                int windowTotal = _resourceCount.Skip(_windowIndex).Sum();
                _windowIndex = _resourceCount.Count;

                int currentRate = (int)(Convert.ToDouble(windowTotal) / (timeChange / 1000));
                int totalRate = (int)(Convert.ToDouble(programTotal) / ((DateTime.Now - _startTime).TotalMilliseconds / 1000));
                _logger.LogInformation($"Current processing Rate: {currentRate} resources/second. Total processing rate {totalRate} resources/second.");
            }
        }
    }
}
