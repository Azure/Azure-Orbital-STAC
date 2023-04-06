# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os

from typing import Optional
from azure.storage.blob.aio import BlobClient


async def check_if_blob_exists(conn_str: str, container_name: str, blob_name: str) -> bool:
    """Checks if a blob exists in the storage account
    :param conn_str: Connection String to the Storage Account hosting the Blob
    :type conn_str: str
    :param container_name: Name of the Container where the blob is hosted
        in the Azure Storage Account
    :type container_name: str
    :param blob_name: Relative path to the blob with ref. to the container
    :type blob_name: str
    :returns: True if the blob exists; otherwise false
    :rtype: bool
    """

    blob = BlobClient.from_connection_string(
        conn_str=conn_str, container_name=container_name, blob_name=blob_name
    )
    async with blob:
        exists = await blob.exists()
        return exists


async def get_blob_size(conn_str: str, container_name: str, file_path: str) -> int:
    """Get the size of the blob in Storage Account (in bytes)
    :param conn_str: Connection String to the Storage Account hosting the Blob
    :type conn_str: str
    :param container_name: Name of the Container where the blob is hosted
        in the Azure Storage Account
    :type container_name: str
    :param file_path: Relative path to the blob with ref. to the container
    :type file_path: str
    :returns: Size of the blob in bytes
    :rtype: int
    """

    async with BlobClient.from_connection_string(
        conn_str=conn_str, container_name=container_name, blob_name=file_path
    ) as blob:
        blob_size = (await blob.get_blob_properties()).size

    return blob_size


async def upload_blob_async(
    conn_str: str, container_name: str, file_name: str, file_path: Optional[str] = None
) -> None:
    """Uploads a blob to the storage account
    :param conn_str: Connection String to the Storage Account hosting the Blob
    :type conn_str: str
    :param container_name: Name of the Container where the blob is hosted
        in the Azure Storage Account
    :type container_name: str
    :param file_path: Relative path to the blob with ref. to the container
    :type file_path: str
    :param file_name: Name of the blob in storage account
    :type file_name: str
    :returns: None
    :rtype: None
    """
    blob = BlobClient.from_connection_string(
        conn_str=conn_str,
        container_name=container_name,
        blob_name=f"{file_path}/{file_name}" if file_path is not None else file_name,
    )

    async with blob:
        # [START upload_blob_to_container]
        with open(file_name, "rb") as blob_data:
            await blob.upload_blob(data=blob_data)


# Data is being downloaded locally and will need to be cleaned up
# by the calling module.
async def download_blob_async(
    conn_str: str, container_name: str, file_path: str, destination_path: str
) -> str:
    """Download blob from azure storage account. Will not overwrite
    if the file already exists
    :param conn_str: Connection String to the Storage Account hosting the Blob
    :type conn_str: str
    :param container_name: Name of the Container where the blob is hosted
        in the Azure Storage Account
    :type container_name: str
    :param file_path: Relative path to the blob with ref. to the container
    :type file_path: str
    :param destination_path: Absolute location to the local folder where
        the blob needs to be downloaded to
    :type destination_path: str
    :returns: Path to the local downloaded file
    :rtype: str
    """

    blob_name = os.path.basename(file_path)

    try:
        async with BlobClient.from_connection_string(
            conn_str=conn_str, container_name=container_name, blob_name=blob_name
        ) as blob_client:
            _, file_name = os.path.split(blob_client.blob_name)

            # get the full path for the destination where the file will be
            # downloaded including the leaf file name
            download_file_path = os.path.join(destination_path, file_name)

            does_blob_exist = await blob_client.exists()

            # check for blob existence
            if does_blob_exist:
                with open(download_file_path, "wb") as fh:
                    stream = await blob_client.download_blob()
                    data = await stream.readall()
                    fh.write(data)

            return download_file_path

    except Exception as e:
        raise e


def generate_sas_token(conn_str: str) -> str:
    """Generate SAS Token for reading objects from Storage Account. Future use will be
    extended to include settings to let users specific resource types and permissions
    :param conn_str: Connection string to the Storage Account
    :type conn_str: str
    :returns: SAS token as string
    :rtype: str
    """

    from datetime import datetime, timedelta

    from azure.storage.blob import (
        AccountSasPermissions,
        BlobServiceClient,
        ResourceTypes,
        generate_account_sas,
    )

    blob_service_client = BlobServiceClient.from_connection_string(conn_str=conn_str)

    expiration = None

    if expiration is None or datetime.utcnow() >= expiration:
        # set expiration time for the SAS token to be 1 days
        expiration = datetime.utcnow() + timedelta(days=1)

        sas_token = generate_account_sas(
            blob_service_client.account_name,
            account_key=blob_service_client.credential.account_key,
            resource_types=ResourceTypes(object=True),
            permission=AccountSasPermissions(read=True),
            expiry=expiration,
        )

        return sas_token
