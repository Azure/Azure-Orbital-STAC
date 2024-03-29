# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from abc import ABCMeta, abstractmethod
from typing import Any, Callable, Tuple


class Metrics(object, metaclass=ABCMeta):
    CONNECTION_STRING = ""
    MMAP = None

    def _setup_open_census(self, views: Any) -> None:
        """
        Bootstrap opencensus for sending metrics
        :param views: List of view to register
        """

        from opencensus.ext.azure import metrics_exporter
        from opencensus.stats import stats as stats_module

        stats = stats_module.stats

        view_manager = stats.view_manager

        exporter = metrics_exporter.new_metrics_exporter(
            connection_string=self.CONNECTION_STRING
        )

        view_manager.register_exporter(exporter)

        for view in views:
            view_manager.register_view(view)

        stats_recorder = stats.stats_recorder

        self.MMAP = stats_recorder.new_measurement_map()

    @abstractmethod
    def register_metrics(self) -> None:
        pass

    @abstractmethod
    def send_metrics(self, metrics: dict[str, Any]) -> None:
        pass


def sendmetrics(func: Callable) -> Callable:
    """
    Decorator to send metrics to App Insights
    """

    def wrapper(*args: Tuple, **kwargs: dict[str, Any]) -> None:
        """
        Wrapper to send the metrics at the end of a processor run
        """

        func(*args, **kwargs)

        # todo: send metrics

        pass

    return wrapper
