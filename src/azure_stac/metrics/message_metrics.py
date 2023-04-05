# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from azure_stac.core.metrics import Metrics


class MessageMetrics(Metrics):
    def __init__(self, *args, **kwargs):
        pass

    def register_metrics(self):
        pass

    def send_metrics(self):
        pass
