# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os
import sys
import traceback
from collections import OrderedDict
from importlib.machinery import SourceFileLoader
from pathlib import Path

from knack.arguments import ArgumentsContext, CLIArgumentType  # pylint: disable=unused-import
from knack.cli import CLI
from knack.commands import CLICommandsLoader, CommandGroup
from knack.completion import ARGCOMPLETE_ENV_NAME
from knack.experimental import ExperimentalItem
from knack.introspection import extract_args_from_signature, extract_full_summary_from_signature
from knack.log import get_logger
from knack.preview import PreviewItem
from knack.util import CLIError

from azure_stac.commands.processor import processor_cf

EXCLUDED_PARAMS = ["self", "kwargs", "client"]


def _configure_knack():
    """Configure a Azure Orbital STAC specific cli"""

    from knack.util import status_tag_messages


class StacCli(CLI):
    def __init__(self, **kwargs):
        super(StacCli, self).__init__(**kwargs)

    def get_cli_version(self):
        return self.__version__


class StacCommandsLoader(CLICommandsLoader):
    CMD_MODULES = []

    def __init__(self, *args, **kwargs):
        try:
            commands_path = os.path.join(
                Path(__file__).parents[
                    1
                ],  # gets the path of the parent's parent folder of the running code
                "commands",  # static folder name where all processors will reside
            )

            for root, d, files in os.walk(commands_path):
                processors = [
                    fname
                    for fname in files
                    if fname.endswith(".py") and not fname.startswith("__")
                ]
                for p in processors:
                    modname = p
                try:
                    module = SourceFileLoader(
                        modname, os.path.join(Path(__file__).parents[1], "commands", p)
                    ).load_module()

                    # todo: add asset to make sure the module contain load_commands
                    # and then dynamically invoke the loading of the commands

                except (SystemError, ImportError, NotImplementedError, SystemError) as ex:
                    traceback.print_exc()
                    # error loading a specific processor module
                    # ignore and move on
                    continue

        except ImportError:
            # unable to load one or more command module
            # do not let invalid command module break the flow
            pass

        super(StacCommandsLoader, self).__init__(
            *args, excluded_command_handler_args=EXCLUDED_PARAMS, **kwargs
        )

    def load_command_table(self, args):
        with CommandGroup(
            self,
            "processor",
            operations_tmpl="azure_stac.commands.processor#{}",
            client_factory=processor_cf,
        ) as group:
            group.command("run", "run_processor")
            group.command("list", "list_processors")

        return OrderedDict(self.command_table)

    def load_arguments(self, command):
        with ArgumentsContext(self, "processor run") as ac:
            ac.argument(
                "name", arg_type=CLIArgumentType(type=str, help="Name of the processor to run")
            )

        super(StacCommandsLoader, self).load_arguments(command)


def get_default_cli():
    return StacCli(cli_name="stac", commands_loader_cls=StacCommandsLoader)
