# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from knack.util import CLIError
from knack.log import get_logger

import requests
from glob import glob
import json

from azure.cli.core._profile import Profile

logger = get_logger(__name__)

def load_bundles(cmd, fhir_endpoint, bundles):
    token = get_access_token(cmd, fhir_endpoint)
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {token}'
    }

    for bundle_path in bundles:
        bundle = load_bundle(bundle_path)

        logger.debug(f'Sending bundle:\n {bundle}')

        response = requests.post(
            f'{fhir_endpoint}Patient',
            data=json.dumps(bundle),
            headers=headers
        )

        if (response.ok):
            logger.info(f'Successfully posted bundle {bundle_path}')
        else:
            logger.error(f'Error posting bundle {bundle_path}. {response.status_code}\n{response.json()}')

    return

def get_access_token(cmd, fhir_endpoint):
    profile = Profile(cli_ctx=cmd.cli_ctx)
    creds, _, _ = profile.get_raw_token(subscription=None, resource=fhir_endpoint, scopes=None, tenant=None)
    return creds[1]

def load_bundle(bundle_path):
    bundle = None
    with open(bundle_path) as f:
        bundle = json.load(f)
    return bundle

