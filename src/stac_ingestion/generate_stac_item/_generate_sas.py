from azure.storage.blob import ResourceTypes, AccountSasPermissions, generate_account_sas
from azure.storage.blob import BlobServiceClient
from datetime import datetime, timedelta

from _env_variables import DATA_STORAGE_ACCOUNT_CONNECTION_STRING

blob_service_client = BlobServiceClient.from_connection_string(
    DATA_STORAGE_ACCOUNT_CONNECTION_STRING)

def get_sas_token() -> str:
    expiration = None
    if expiration is None or datetime.utcnow() >= expiration:
        expiration = datetime.utcnow() + timedelta(days=1)
        sas_token = generate_account_sas(
            blob_service_client.account_name,
            account_key=blob_service_client.credential.account_key,
            resource_types=ResourceTypes(object=True),
            permission=AccountSasPermissions(read=True),
            expiry=expiration)
        return sas_token
