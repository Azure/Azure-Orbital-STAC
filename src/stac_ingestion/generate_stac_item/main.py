import asyncio
import json
import logging
import os
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

import pystac
from azure.servicebus import AutoLockRenewer, ServiceBusClient
from opencensus.ext.azure.log_exporter import AzureLogHandler
from osgeo import gdal

from _env_variables import *
from _blob_services import *
from _stac import create_item
from _naip_utils import remove_file

LOCAL_FILE_PATH = './'
STACIFIED_JSON_PATH = f"https://{DATA_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/{DATA_STORAGE_PGSTAC_CONTAINER_NAME}"

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.addHandler(AzureLogHandler(
    connection_string=AZURE_LOG_CONNECTION_STRING))


def create_item_in_blob(state: str, year: str, cog_href: str, dst: str, thumbnail: str, providers: str, cog_url: str, stac_metadata: str = None) -> str:
    """Creates a STAC Item based on metadata.

    STATE is the state this NAIP tile belongs to.
    COG_HREF is the href to the COG that is the NAIP tile.
    FGDC_HREF is href to the text metadata file in the NAIP fgdc format.
    DST is directory that a STAC Item JSON file will be created
    in.
    """
    additional_providers = None

    if providers is not None:
        with open(providers) as f:
            additional_providers = [
                pystac.Provider.from_dict(d) for d in json.load(f)
            ]

    item = create_item(
        state,
        year,
        cog_href,
        metadata_href=stac_metadata,
        thumbnail_href=thumbnail,
        additional_providers=additional_providers,
        cog_url=cog_url,
    )
    # join to local path
    item_path = os.path.join(LOCAL_FILE_PATH, "{}.json".format(item.id))

    # join to local path
    item_path = os.path.join(LOCAL_FILE_PATH, "{}.json".format(item.id))

    # save blob store self link
    item.set_self_href(f"{dst}/{item.id}.json")

    # save to local file system
    item.save_object(dest_href=item_path)

    return item.id


def translate_tif_to_jpeg(title: str, tif_file: str) -> None:
    """
    Translates a TIFF file to a JPEG file.
    """
    option_list = [
        '-ot byte',
        '-of JPEG',
        '-outsize 100% 100%',
    ]

    option_string = ' '.join(option_list)

    # generate jpeg and aux.xml for COG
    print("Translating {} to JPEG".format(tif_file))
    try:
        gdal.Translate(
            f"{title}.{JPG_EXTENSION}", tif_file, options=option_string)
    except Exception as e:
        print(f"{title}.jpg not translated. The error is: {e}")


def log_time_to_complete(start_time, end_time, item_id, file_name):
    """
    Logs the time to complete a specific activity

    Args:
        start_time (_type_): time when the activity began
        end_time (_type_): time when the activity ended
        item_id (_type_): item id
        file_name (_type_): file name
    """

    time_to_process_file = end_time - start_time

    start_time_str = start_time.strftime(
        "%Y-%m-%d %H:%M:%S")

    end_time_str = end_time.strftime("%Y-%m-%d %H:%M:%S")

    properties = {'custom_dimensions': {
        'process': 'stac_generation',
        'item_id_stac_generation': item_id,
        'start_time': start_time_str,
        'end_time': end_time_str,
        'process_time': time_to_process_file.total_seconds(),
        'file_name': file_name}}

    logger.info('action', extra=properties)


def get_incoming_message():
    """
    Get the incoming message from the service bus.
    """
    renewer = AutoLockRenewer()
    with ServiceBusClient.from_connection_string(conn_str=STACIFY_SERVICE_BUS_CONNECTION_STRING, retry_total=1, retry_backoff_factor=10, retry_mode="fixed") as client:
        receiver = client.get_subscription_receiver(
            topic_name=STACIFY_SERVICE_BUS_TOPIC_NAME, subscription_name=STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME)
        with receiver:
            for msg in receiver:

                start_time = datetime.utcnow()

                # register to receive message from service bus topic and
                # load message as json
                renewer.register(receiver, msg, max_lock_renewal_duration=4000)
                response = json.loads(str(msg))
                cog_url = response['data']['url']

                parsed_url = urlparse(cog_url)

                file_name_without_ext = Path(cog_url).stem
                file_name = Path(cog_url).name
                split_url = os.path.dirname(cog_url).split('/')

                # retrieve attributes from folder path. folder path is expected
                # to be in the format:
                # https://storage-name.blob.core.azure.com/container/v002/wa/2015/wa_100cm_2015/45117/filename.ext
                # all indexes are zero-index based
                version = split_url[4]
                state = split_url[5]
                year = split_url[6]
                state_measurement_year = split_url[7]
                folder_number = split_url[8]

                # retrive "domain" path
                # example - https://storage-name.blob.core.azure.com/container
                domain_path = split_url[0:4]
                domain_path_joined = '/'.join(domain_path)

                split_url_joined = '/'.join(split_url[4:7])
                item_id = ''

                # prepare paths for
                # a. az uri scheme based location
                # b. local path to download tif
                azure_raster_url = f"az://{STACIFY_STORAGE_CONTAINER_NAME}/{version}/{state}/{year}/{state_measurement_year}/{folder_number}/{file_name}"
                download_tif_url = f"{split_url_joined}/{state_measurement_year}/{folder_number}/{file_name}"

                if file_name.endswith(".tif"):
                    jpeg_url = os.path.splitext(
                        cog_url)[0] + f".{JPG_EXTENSION}"
                    jpeg_tail_path = jpeg_url.split('/')[4:-1]
                    joined_jpeg_tail_path = '/'.join(jpeg_tail_path)

                    fdgc_metadata_url = f"{domain_path_joined}/{split_url_joined}/{state}_{STAC_METADATA_TYPE_NAME}_{year}/{folder_number}/{file_name_without_ext}.txt"
                    jpeg_url = f"{domain_path_joined}/{joined_jpeg_tail_path}/{file_name_without_ext}.{JPG_EXTENSION}"

                    # check if metadata file exists
                    does_metadata_file_exist = asyncio.run(
                        check_if_blob_exists(blob_file=f"{split_url_joined}/{state}_{STAC_METADATA_TYPE_NAME}_{year}/{folder_number}/{file_name_without_ext}.txt", container=STACIFY_STORAGE_CONTAINER_NAME))

                    print(
                        f"txt checked for {split_url_joined}/{state}_{STAC_METADATA_TYPE_NAME}_{year}/{folder_number}/{file_name_without_ext}.txt is done and result is {does_metadata_file_exist}")

                    # check if jpg exists
                    does_jpeg_file_exist = asyncio.run(check_if_blob_exists(
                        blob_file=f"{joined_jpeg_tail_path}/{file_name_without_ext}.{JPG_EXTENSION}", container=STACIFY_STORAGE_CONTAINER_NAME))

                    print(
                        f"jpeg checked for {joined_jpeg_tail_path}/{file_name_without_ext}.{JPG_EXTENSION} is done and result is {does_jpeg_file_exist}")

                    if not does_jpeg_file_exist:
                        try:
                            file_path, file_name = asyncio.run(
                                download_blob(download_tif_url))

                            translate_tif_to_jpeg(
                                file_name_without_ext, file_name)

                            # upload jpeg to azure storage
                            asyncio.run(upload_blob(
                                file_path=file_path, file_name=f"{file_name_without_ext}.{JPG_EXTENSION}"))

                            # upload aux.xml to azure storage
                            asyncio.run(upload_blob(
                                file_path=file_path, file_name=f"{file_name_without_ext}.{JPG_EXTENSION}.{XML_EXTENSION}"))

                            # TODO: create a loop in remove_file that takes an array of files to remove
                            # remove tif, jpg, and xml files after uploading to blob
                            remove_file(
                                f"{file_name_without_ext}.{JPG_EXTENSION}")
                            remove_file(
                                f"{file_name_without_ext}.{JPG_EXTENSION}.{XML_EXTENSION}")
                            remove_file(file_name)

                        except Exception as e:
                            print(e)

                    try:
                        if not does_metadata_file_exist:
                            item_id = create_item_in_blob(state=state,
                                                          year=year,
                                                          cog_href=azure_raster_url,
                                                          dst=STACIFIED_JSON_PATH,
                                                          thumbnail=jpeg_url,
                                                          providers=None,
                                                          cog_url=cog_url,
                                                          )

                        else:
                            item_id = create_item_in_blob(state=state,
                                                          year=year,
                                                          cog_href=azure_raster_url,
                                                          dst=STACIFIED_JSON_PATH,
                                                          stac_metadata=fdgc_metadata_url,
                                                          thumbnail=jpeg_url,
                                                          providers=None,
                                                          cog_url=cog_url,
                                                          )

                        # upload stac item to blob
                        asyncio.run(upload_file_from_local_folder_to_storage(
                            file_name=f"{item_id}.json"))

                        # remove stac item from local file system
                        os.remove(f"{item_id}.json")

                        # stop time to calculate performance
                        end_time = datetime.utcnow()

                        # log time to complete to application insights
                        log_time_to_complete(
                            start_time, end_time, item_id, file_name)

                        # complete message from service bus
                        receiver.complete_message(msg)
                    except Exception as e:
                        print(
                            f"There was an error in this process of file {file_name_without_ext}")
                        logger.error(
                            "error", f"Error file: {file_name_without_ext} error message: {e}")
                        receiver.abandon_message(msg)


if __name__ == "__main__":
    get_incoming_message()
