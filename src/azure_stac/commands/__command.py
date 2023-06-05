# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from abc import ABCMeta, abstractmethod


class BaseCommand(metaclass=ABCMeta):
    @abstractmethod
    def list_sub_commands(self) -> None:
        """Gets a list of Commands for the Command Group. Each Class is treated as a Command
        Group and the commands under them are considered sub-commands.
        :abstract
        """
        raise NotImplementedError

    @abstractmethod
    def show_help(self) -> None:
        """Gets the help text for the Command Group.
        :abstract
        """
        raise NotImplementedError
