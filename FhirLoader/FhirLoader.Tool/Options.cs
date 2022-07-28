using CommandLine;
using CommandLine.Text;

namespace FhirLoader.Tool
{
    public class Options
    {

        [Option("path", Required = true, HelpText = "File path to the bundles or bulk data files you want to load.")]
        public string LocalPath { get; set; }

        [Option("fhir", Required = true, HelpText = "Base URL of your FHIR server.")]
        public string FhirUrl { get; set; }

        [Usage(ApplicationAlias = "mw-fhir-loader")]
        public static IEnumerable<Example> Examples
        {
            get
            {
                return new List<Example>() {
                    new Example("Load synthea files to an Azure Health Data Services FHIR service", new Options { LocalPath = "~/synthea/fhir", FhirUrl = "https://workspace-fhirservice.fhir.azurehealthcareapis.com/" })
                };
            }
        }
    }
}
