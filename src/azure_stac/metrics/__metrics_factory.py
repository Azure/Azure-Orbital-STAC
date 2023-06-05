# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from azure_stac.metrics.data_metrics import DataMetrics
from azure_stac.metrics.message_metrics import MessageMetrics
from azure_stac.metrics.pod_metrics import PodMetrics
from azure_stac.core.metrics import Metrics


class MetricsFactory:
    @staticmethod
    def get_metrics_provider(metric_type: str) -> Metrics:
        """
        Factory to create the required Metrics class
        """

        if metric_type == "data":
            return DataMetrics()
        elif metric_type == "message":
            return MessageMetrics()
        elif metric_type == "pod":
            return PodMetrics()
        raise ValueError(f"Invalid metric type: {metric_type}")
