# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=line-too-long

from knack.arguments import CLIArgumentType


def load_arguments(self, _):

    with self.argument_context('fhir-tools load-bundles') as c:
        c.argument('fhir_endpoint', options_list=['--fhir-endpoint'], id_part=None)
        c.argument('bundles', nargs='*', options_list=['--bundles'])
