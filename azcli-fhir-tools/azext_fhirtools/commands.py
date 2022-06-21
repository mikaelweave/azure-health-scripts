# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

# pylint: disable=line-too-long
from azure.cli.core.commands import CliCommandType

def load_command_table(self, _):

    with self.command_group('fhir-tools') as g:
        g.custom_command('load-bundles', 'load_bundles')

    with self.command_group('fhir-tools', is_preview=True):
        pass

