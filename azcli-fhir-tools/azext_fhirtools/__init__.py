# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from azure.cli.core import AzCommandsLoader

from azext_fhirtools._help import helps  # pylint: disable=unused-import


class FhirToolsCommandsLoader(AzCommandsLoader):

    def __init__(self, cli_ctx=None):
        from azure.cli.core.commands import CliCommandType
        fhirtools_custom = CliCommandType(
            operations_tmpl='azext_fhirtools.custom#{}')
        super(FhirToolsCommandsLoader, self).__init__(cli_ctx=cli_ctx,
                                                  custom_command_type=fhirtools_custom)

    def load_command_table(self, args):
        from azext_fhirtools.commands import load_command_table
        load_command_table(self, args)
        return self.command_table

    def load_arguments(self, command):
        from azext_fhirtools._params import load_arguments
        load_arguments(self, command)


COMMAND_LOADER_CLS = FhirToolsCommandsLoader
