import asyncio
import json
import logging
import os
import subprocess
from datetime import datetime
from pathlib import Path

from azure.servicebus import ServiceBusClient
from azure.storage.blob.aio import BlobClient
from opencensus.ext.azure.log_exporter import AzureLogHandler

from _env_variables import (AZURE_LOG_CONNECTION_STRING,
                            DATA_STORAGE_ACCOUNT_CONNECTION_STRING,
                            DATA_STORAGE_PGSTAC_CONTAINER_NAME,
                            PGSTAC_SERVICE_BUS_CONNECTION_STRING,
                            PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME,
                            PGSTAC_SERVICE_BUS_TOPIC_NAME)

LOCAL_FILE_PATH = './'

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.addHandler(AzureLogHandler(
    connection_string=AZURE_LOG_CONNECTION_STRING))

async def download_blob_data(file_path: str):
    """
    Download blob data from Blob Storage
    """
    json_file = os.path.basename(file_path)
    try:
        async with BlobClient.from_connection_string(
                conn_str=DATA_STORAGE_ACCOUNT_CONNECTION_STRING, container_name=DATA_STORAGE_PGSTAC_CONTAINER_NAME, blob_name=json_file) as blob_client:

            _, file_name = os.path.split(
                blob_client.blob_name)

            download_file_path = os.path.join(
                LOCAL_FILE_PATH, file_name)

            does_blob_exist = await blob_client.exists()
            if does_blob_exist:
                with open(download_file_path, "wb") as fh:
                    stream = await blob_client.download_blob()
                    data = await stream.readall()
                    fh.write(data)
            return download_file_path
    except Exception as e:
        logging.error(f"There was an error downloading your json. Details: {e}")


def pypgstac_load_item(file_path: str):
    with open(file_path, "r") as data:

        cmd = f"pypgstac load items {file_path} --method insert".split()
        try:
            subprocess.check_call(cmd)
        except Exception as e:
            logger.exception(f"There was an error executing: 'pypgstac'\nError: {e}")

    logging.info(f"{file_path} is in pgstac now")
    return Path(file_path).stem


def convert_json_to_ndjson(file_path: str):
    ndjson_name = Path(file_path).stem + ".ndjson"
    file_content = ''

    try:
        with open(file_path, "r") as file:
            data = json.load(file)
            file_content = json.dumps(data, separators=(',',':'))

    except Exception as e:
        logging.error(f"There was an error reading your json. Details: {e}")

    try:
        with open(ndjson_name, 'w') as outfile:
            outfile.write(f'{file_content}\n')

    except Exception as e:
        logging.error(f"There was an error creating the ndjson. Details: {e}")

    return ndjson_name

def main():
    with ServiceBusClient.from_connection_string(PGSTAC_SERVICE_BUS_CONNECTION_STRING, retry_total=1, retry_backoff_factor=10, retry_mode="fixed") as client:
        receiver = client.get_subscription_receiver(
            topic_name=PGSTAC_SERVICE_BUS_TOPIC_NAME, subscription_name=PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME)

        messages = receiver.receive_messages(max_message_count=1)

        with receiver:
            for msg in messages:

                # start time for processing
                start_time = datetime.utcnow()

                data = json.loads(str(msg))
                try:
                    json_file_path = asyncio.run(download_blob_data(data['data']['url']))
                    ndjson_file_path = convert_json_to_ndjson(json_file_path)
                    item_id = pypgstac_load_item(ndjson_file_path)

                    os.remove(json_file_path)
                    os.remove(ndjson_file_path)

                    # end time for processing
                    end_time = datetime.utcnow()

                    # calculate processing time
                    time_to_process_file = end_time - start_time

                    start_time_str = start_time.strftime(
                        "%Y-%m-%d %H:%M:%S.%f")
                    end_time_str = end_time.strftime("%Y-%m-%d %H:%M:%S.%f")

                    # Create a custom event for the Azure Application Insights
                    properties = {'custom_dimensions': {
                        'process': 'pgstac_insert', 'item_id_pgstac': item_id, 'start_time': start_time_str, 'end_time': end_time_str, 'process_time': time_to_process_file.total_seconds(), 'file_name': item_id + '.ndjson'}}

                    logger.info('action', extra=properties)
                    receiver.complete_message(msg)
                except Exception as e:
                    logger.error(
                        "error", f"item_id: {item_id} error message: {e}")
                    receiver.abandon_message(msg)


if __name__ == "__main__":
    main()
