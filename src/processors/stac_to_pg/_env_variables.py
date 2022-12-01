import os

def get_env_variable(variable_name):
    value = os.getenv(variable_name)
    if value is None:
        raise ValueError(variable_name + " is not set")
    return value

PGSTAC_SERVICE_BUS_CONNECTION_STRING = get_env_variable('PGSTAC_SERVICE_BUS_CONNECTION_STRING')
PGSTAC_SERVICE_BUS_TOPIC_NAME = get_env_variable('PGSTAC_SERVICE_BUS_TOPIC_NAME')
PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME = get_env_variable('PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME')
DATA_STORAGE_PGSTAC_CONTAINER_NAME = get_env_variable('DATA_STORAGE_PGSTAC_CONTAINER_NAME')
DATA_STORAGE_ACCOUNT_CONNECTION_STRING = get_env_variable('DATA_STORAGE_ACCOUNT_CONNECTION_STRING')
AZURE_LOG_CONNECTION_STRING = get_env_variable('AZURE_LOG_CONNECTION_STRING')