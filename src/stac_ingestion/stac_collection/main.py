import asyncio
import json
import logging
import os

import psycopg
from azure.servicebus import ServiceBusClient
from opencensus.ext.azure.log_exporter import AzureLogHandler

from _env_variables import (AZURE_LOG_CONNECTION_STRING, PGDATABASE, PGHOST,
                            PGPASSWORD, PGUSER,
                            STACCOLLECTION_SERVICE_BUS_CONNECTION_STRING,
                            STACCOLLECTION_SERVICE_BUS_SUBSCRIPTION_NAME,
                            STACCOLLECTION_SERVICE_BUS_TOPIC_NAME)
from blob_service import download_collection_json

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.addHandler(AzureLogHandler(
    connection_string=AZURE_LOG_CONNECTION_STRING))


def incoming_messages():
    # Database connector
    conn = ''

    # Construct connection string
    conn_string = "host={0} user={1} dbname={2} password={3}".format(
        PGHOST, PGUSER, PGDATABASE, PGPASSWORD)
    try:
        conn = psycopg.connect(conn_string)
        logging.info("Connection established")
    except Exception as e:
        logging.error(f"Error connecting to database. Details: {e}")

    with ServiceBusClient.from_connection_string(conn_str=STACCOLLECTION_SERVICE_BUS_CONNECTION_STRING, retry_total=1, retry_backoff_factor=10, retry_mode="fixed") as client:
        receiver = client.get_subscription_receiver(
            topic_name=STACCOLLECTION_SERVICE_BUS_TOPIC_NAME, subscription_name=STACCOLLECTION_SERVICE_BUS_SUBSCRIPTION_NAME)

        with receiver:
            for msg in receiver:

                if conn.closed:
                    try:
                        conn = psycopg.connect(conn_string)
                        logging.info("Re-connection established")
                    except Exception as e:
                        logging.error(f"Error re-connecting to database. Details: {e}")

                response = json.loads(str(msg))
                file_url = response['data']['url']

                try:
                    collection_json = asyncio.run(
                        download_collection_json(file_url))

                    with open('./' + collection_json, 'r') as f:
                        data = json.dumps(json.load(f))
                        try:
                            conn.execute(
                                'SELECT pgstac.create_collection(%s)', [data])
                            print('Added collection to database')
                        except Exception as e:
                            print(e)
                            conn.rollback()
                            logger.exception(
                                f"Error adding collection to database. Error: {e}")
                            print("Rolling back...")
                        else:
                            conn.commit()

                        os.remove(collection_json)
                        receiver.complete_message(msg)
                        properties = {'custom_dimensions': {
                            'process': 'stac_collection', 'status': 'success', 'message': 'Collection added to database', 'url': file_url}}
                        logger.info('action', extra=properties)
                except Exception as e:
                    print(
                        f"There was an error in this process of file {collection_json}")
                    logger.exception(e)
                    receiver.abandon_message(msg)


if __name__ == "__main__":
    incoming_messages()
