# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from typing import Any
from typing_extensions import override
from azure_stac.core.metrics import Metrics


class MessageMetrics(Metrics):
    @override
    def register_metrics(self) -> None:
        pass

    @override
    def send_metrics(self, metrics: dict[str, Any]) -> None:
        pass
