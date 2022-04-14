# FHIR With Proxy

This sample is a turnkey deployment of [FHIR Proxy](https://github.com/microsoft/fhir-proxy) with Azure Health Data Services (AHDS). I use this script to help me quickly deploy a FHIR Proxy and a FHIR Service in a AHDS workplace. This deployment doesn't require admin consent to operate.

This deployment contains
- Azure Health Data Services
    - FHIR Service
- Function App
- Function App Code (Proxy)
- App Insights for debugging


## Usage

1. Copy `.env.sample` to `.env` to get started. Ensure your `.env` file has the required parameters filled out (`RESOURCE_GROUP`, `PREFIX`, `LOCATION`). Ensure there is a newline at the end of the file.

2. Make sure you are logged into the Azure CLI and have the correct subscription selected.

3. Run `make deploy`


## Related

I use `.env` files because I like them - [read this](https://platform.sh/blog/2021/we-need-to-talk-about-the-env/) to learn more about them.
