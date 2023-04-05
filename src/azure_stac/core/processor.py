# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import json
import os
from abc import ABCMeta, abstractmethod

from knack.log import get_logger

logger = get_logger(__name__)


class BaseProcessor(metaclass=ABCMeta):
    PROCESSOR_NAME = ""  # required, name of the processor
    VERSION = "1.0"  # optional, processor version
    AUTHORS = []  # optional, list of authors

    TOPIC_NAME = ""
    SUBSCRIPTION_NAME = ""

    WORKING_DIR = ""
    TEMP_FOLDER_NAME = "temp"

    def __init__(self, **kwargs):
        self.__check_integrity()
        self.__get_settings()

    def __clean_up(self) -> None:
        """Intended to clean up artifacts at the end of each data being processed"""
        import shutil

        temp_folder_path = os.path.join(self.WORKING_DIR, self.TEMP_FOLDER_NAME)

        if not os.path.exists(temp_folder_path):
            return

        for filename in os.listdir(temp_folder_path):
            file_path = os.path.join(temp_folder_path, filename)
            try:
                if os.path.isfile(file_path) or os.path.islink(file_path):
                    os.remove(file_path)
                elif os.path.isdir(file_path):
                    shutil.rmtree(file_path)

            except Exception:
                pass

    def __get_settings(self):
        """
        Retrieve settings and configuration for setting up the base
        functionality for a processor
        """
        self.TOPIC_NAME = os.getenv("TOPIC_NAME")
        self.SUBSCRIPTION_NAME = os.getenv("SUBSCRIPTION_NAME")

    def __check_integrity(self):
        """
        Ensures a list of checks to make sure that the processors correctly
        implement the behavior and attributes.
        """

        assert hasattr(self, "PROCESSOR_NAME"), "PROCESSOR_NAME must be set"
        assert hasattr(self, "VERSION"), "VERSION must be set"

    def __configure_metrics(self, metric_types: any = None):
        """
        This method wil configure the list of applicable metrics and make them
        ready for the processor to send their metrics as needed.
        """
        from azure_stac.metrics.__metrics_factory import MetricsFactory

        if metric_types is not None:
            metrics_client = [
                MetricsFactory.get_metrics_provider(type) for type in metric_types
            ]

            for client in metrics_client:
                client.register_metrics()

    def begin_listening(self):
        """
        Starts using the topic's subscription to begin receiving messages
        """
        from azure.servicebus import ServiceBusClient

        self.SERVICE_BUS_CONNECTION_STRING = os.getenv("SERVICE_BUS_CONNECTION_STRING")

        with ServiceBusClient.from_connection_string(
            conn_str=self.SERVICE_BUS_CONNECTION_STRING,
            retry_total=1,
            retry_backoff_factor=10,
            retry_mode="fixed",
        ) as client:
            receiver = client.get_subscription_receiver(
                topic_name=self.TOPIC_NAME, subscription_name=self.SUBSCRIPTION_NAME
            )

            with receiver:
                for msg in receiver:
                    try:
                        # send this message for processing
                        yield json.loads(str(msg))

                        # complete the msg
                        receiver.complete_message(msg)

                    except Exception:
                        # abandon the msg and move on
                        receiver.abandon_message(msg)

                    # clean up after processing each message
                    self.__clean_up()

    @abstractmethod
    def run(self, **kwargs):
        """
        This will be the main method that the processors need to override to
        implement their custom logic.
        """

        self.__configure_metrics()
