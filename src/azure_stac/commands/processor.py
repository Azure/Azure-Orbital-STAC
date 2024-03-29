# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os
import traceback
from importlib.machinery import SourceFileLoader
from pathlib import Path
from typing import Any, Tuple

from azure_stac.commands.__command import BaseCommand

PROCESSORS_LIST: dict[str, Any] = {}

GROUP = "processor"

COMMANDS = {"run": "run_processor", "list": "list_processors"}

ARGUMENTS = {"run": {"name": str}}


class ProcessorCommand(BaseCommand):
    def __init__(self, *args: Tuple, **kwargs: dict[str, Any]) -> None:
        """Dynamically load all processors for use by commads"""

        processors_path = os.path.join(
            Path(__file__).parents[
                1
            ],  # gets the path of the parent's parent folder of the running code
            "processors",  # static folder name where all processors will reside
        )

        for root, d, files in os.walk(processors_path):
            processors = [
                fname for fname in files if fname.endswith(".py") and not fname.startswith("__")
            ]
            for p in processors:
                modname = p

                try:
                    module = SourceFileLoader(modname, os.path.join(root, p)).load_module()

                    PROCESSORS_LIST[module.__name__.replace(".py", "")] = module

                except (SystemError, ImportError, NotImplementedError, SystemError):
                    # error loading a specific processor module
                    # ignore and move on
                    # printing stack trace
                    traceback.print_exc()

                    continue

        super(ProcessorCommand, self).__init__(*args, **kwargs)

    def list_sub_commands(self) -> None:
        pass

    def show_help(self) -> None:
        pass


# --------------------------------#
# CLI command methods
# --------------------------------#


def run_processor(client: Any, name: str) -> None:
    """Knack command to run the processor by name
    :param client: Processor Client instantiated at runtime by the Client Factory based
        on the specified processor to run
    :type client: BaseProcessor
    :param name: Name of the processor to run
    :type name: str
    :returns: None
    :rtype: None
    """

    PROCESSORS_LIST[name].execute_processor()


def list_processors(client: Any) -> None:
    """Knack command to list the loaded and/or available processor for use
    :param client: Processor Client instantiated at runtime by the Client Factory based
        on the specified processor to run
    :type client: BaseProcessor
    :returns: None
    :rtype: None
    """

    for processor in PROCESSORS_LIST.keys():
        print(processor)


# --------------------------------#
# Client Factory
# --------------------------------#


def processor_cf(_: Any) -> ProcessorCommand:
    """Creates the client object for invoking the processors and passes
    that to the individual commands for use
    :param _: Client Context sent by CLI Loader when processor group is created
    :type _: Any
    :param name: Name of the processor to run
    :type name: str
    :returns: None
    :rtype: None
    """

    return ProcessorCommand()
