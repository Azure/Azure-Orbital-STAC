import logging
import os
from typing import Tuple

from azure.storage.blob.aio import BlobClient
from opencensus.ext.azure.log_exporter import AzureLogHandler

from _env_variables import (AZURE_LOG_CONNECTION_STRING,
                            DATA_STORAGE_ACCOUNT_CONNECTION_STRING,
                            STACIFY_STORAGE_CONTAINER_NAME, DATA_STORAGE_PGSTAC_CONTAINER_NAME)

LOCAL_FILE_PATH = './'

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=AZURE_LOG_CONNECTION_STRING))


async def check_if_blob_exists(blob_file: str, container: str) -> bool:
    """
    Checks if a blob exists in the storage account
    """
    blob = BlobClient.from_connection_string(
        conn_str=DATA_STORAGE_ACCOUNT_CONNECTION_STRING, container_name=container, blob_name=blob_file)
    async with blob:
        exists = await blob.exists()
        return exists


async def upload_file_from_local_folder_to_storage(file_name: str) -> None:
    """
    Upload file to a blob.
    """
    blob = BlobClient.from_connection_string(
        conn_str=DATA_STORAGE_ACCOUNT_CONNECTION_STRING, container_name=DATA_STORAGE_PGSTAC_CONTAINER_NAME, blob_name=file_name)

    try:
        async with blob:
            blob_exists = await check_if_blob_exists(f"{file_name}", container=DATA_STORAGE_PGSTAC_CONTAINER_NAME)
            if blob_exists:
                logger.info(f"{file_name} already exists")
            else:
                # [START upload_blob_to_container]
                with open(file_name, "rb") as blob_data:
                    await blob.upload_blob(data=blob_data)
                    logger.info(
                        f"{file_name} uploaded")
    except:
        logger.exception(f"{file_name} not uploaded")


async def upload_blob(file_path: str, file_name: str) -> None:
    """
    Uploads a blob to the storage account
    """
    blob = BlobClient.from_connection_string(
        conn_str=DATA_STORAGE_ACCOUNT_CONNECTION_STRING, container_name=STACIFY_STORAGE_CONTAINER_NAME, blob_name=f"{file_path}/{file_name}")
    async with blob:
        # [START upload_blob_to_container]
        with open(file_name, "rb") as blob_data:
            await blob.upload_blob(data=blob_data)
            logger.info(f"{file_path}/{file_name} uploaded")


async def download_blob(file_path: str) -> Tuple[str, str]:
    """
    Downloads a blob from the storage account
    """
    async with BlobClient.from_connection_string(
            conn_str=DATA_STORAGE_ACCOUNT_CONNECTION_STRING, container_name=STACIFY_STORAGE_CONTAINER_NAME, blob_name=file_path) as blob:

        file_path, file_name = os.path.split(
            blob.blob_name)
        downloaded_file_path = os.path.join(
            LOCAL_FILE_PATH, file_name)

        with open(downloaded_file_path, "wb") as blob_data:
            stream = await blob.download_blob()
            data = await stream.readall()
            blob_data.write(data)

    return (file_path, file_name)
