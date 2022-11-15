import pystac
import os
from pystac.extensions.eo import Band
from pystac.provider import ProviderRole
from dotenv import load_dotenv

load_dotenv()  # take environment variables from .env.


def get_env_variable(variable_name, default_value=None):
    value = os.getenv(variable_name)
    if value is None:
        if default_value is None:
            raise ValueError(variable_name + " is not set")
        else:
            value = default_value
    return value

USDA_PROVIDER = get_env_variable('USDA_PROVIDER', pystac.Provider(
    name="USDA Farm Service Agency",
    url=(
        "https://www.fsa.usda.gov/programs-and-services/aerial-photography"
        "/imagery-programs/naip-imagery/"
    ),
    roles=[ProviderRole.PRODUCER, ProviderRole.LICENSOR],
))
STAC_BANDS = get_env_variable('STAC_BANDS', [
    Band.create(name="Red", common_name="red"),
    Band.create(name="Green", common_name="green"),
    Band.create(name="Blue", common_name="blue"),
    Band.create(name="NIR", common_name="nir", description="near-infrared"),
])

AZURE_LOG_CONNECTION_STRING = get_env_variable('AZURE_LOG_CONNECTION_STRING')
DATA_STORAGE_ACCOUNT_NAME = get_env_variable('DATA_STORAGE_ACCOUNT_NAME')

STACIFY_STORAGE_CONTAINER_NAME = get_env_variable(
    'STACIFY_STORAGE_CONTAINER_NAME')
STACIFY_SERVICE_BUS_TOPIC_NAME = get_env_variable(
    'STACIFY_SERVICE_BUS_TOPIC_NAME')
STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME = get_env_variable(
    'STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME')
STACIFY_SERVICE_BUS_CONNECTION_STRING = get_env_variable(
    'STACIFY_SERVICE_BUS_CONNECTION_STRING')
STAC_METADATA_TYPE_NAME = get_env_variable('STAC_METADATA_TYPE_NAME')
JPG_EXTENSION = get_env_variable('JPG_EXTENSION')
XML_EXTENSION = get_env_variable('XML_EXTENSION')

DATA_STORAGE_ACCOUNT_CONNECTION_STRING = get_env_variable(
    'DATA_STORAGE_ACCOUNT_CONNECTION_STRING')
DATA_STORAGE_ACCOUNT_KEY = get_env_variable('DATA_STORAGE_ACCOUNT_KEY')

DATA_STORAGE_PGSTAC_CONTAINER_NAME = get_env_variable('DATA_STORAGE_PGSTAC_CONTAINER_NAME')

COLLECTION_ID = get_env_variable('COLLECTION_ID', 'naip')

MESSAGE_COUNT = get_env_variable('MESSAGE_COUNT')
