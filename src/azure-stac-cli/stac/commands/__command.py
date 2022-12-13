# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os
import sys
from abc import ABCMeta, abstractmethod


class BaseCommand():
    
    def __init__(self):
        return None
    
    @abstractmethod
    def list_sub_commands(self):
        raise NotImplementedError
    
    @abstractmethod
    def show_help(self):
        raise NotImplementedError