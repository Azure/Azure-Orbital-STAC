import logging
import os
from urllib.parse import urlparse

from azure.storage.blob.aio import BlobClient

from _env_variables import (DATA_STORAGE_ACCOUNT_CONNECTION_STRING,
                            STACCOLLECTION_STORAGE_CONTAINER_NAME)

LOCAL_FILE_PATH = "./"
async def download_collection_json(file_path: str):
    """
    Downloads the metadata file from the Azure Blob Storage.
    """
    json_file = os.path.basename(file_path)

    try:
        async with BlobClient.from_connection_string(
                conn_str=DATA_STORAGE_ACCOUNT_CONNECTION_STRING, container_name=STACCOLLECTION_STORAGE_CONTAINER_NAME, blob_name=json_file) as blob_client:

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
            return file_name
    except Exception as e:
        logging.error(f"There was an error downloading your json. Details: {e}")
