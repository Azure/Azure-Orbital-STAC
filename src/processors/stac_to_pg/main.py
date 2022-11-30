import asyncio
import json
import logging
import os
import subprocess
from datetime import datetime
from pathlib import Path

from azure.servicebus import ServiceBusClient
from azure.storage.blob.aio import BlobClient

from opencensus.ext.azure import metrics_exporter
from opencensus.stats import aggregation as aggregation_module
from opencensus.stats import measure as measure_module
from opencensus.stats import stats as stats_module
from opencensus.stats import view as view_module
from opencensus.tags import tag_map as tag_map_module
from opencensus.tags import tag_key as tag_key_module
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

def _setup_open_census():
    """
        Bootstrap opencensus for sending metrics
    """
   
    stats = stats_module.stats
    view_manager = stats.view_manager
   
    exporter = metrics_exporter.new_metrics_exporter(
        connection_string=AZURE_LOG_CONNECTION_STRING)

    view_manager.register_exporter(exporter)
    
    view_manager.register_view(message_processed_view)
    view_manager.register_view(message_count_view)
    view_manager.register_view(data_size_view)
    view_manager.register_view(pod_count_view)
    
    stats_recorder = stats.stats_recorder
    mmap = stats_recorder.new_measurement_map()
    return mmap

def _record_data_info(size: int, status: str):
    """
    Logs the data information
    """
    
    pod_name = os.getenv('POD_NAME')
    
    mmap.measure_int_put(data_size_measure,
                        size)
    
    
    if pod_name is not None:
        
        tagMap = tag_map_module.TagMap()
        
        tagMap.insert("Pod Name", pod_name)
        tagMap.insert("Status", status)
        tagMap.insert("Processor", "STAC to PG")
        
        mmap.record(tagMap)
    else:
        mmap.record()
    
def _record_pod_info():
    """
    Logs the pod information
    """
    pod_name = os.getenv('POD_NAME')
    node_name = os.getenv('NODE_NAME')
    
    if pod_name is not None and node_name is not None:
        mmap.measure_int_put(pod_count_measure, 1)
        
        tagMap = tag_map_module.TagMap()
        
        tagMap.insert("Pod Name", pod_name)
        tagMap.insert("Node Name", node_name)
        tagMap.insert("Processor", "STAC to PG")
        
        mmap.record(tagMap)

def _record_message(start_time, 
                    end_time, 
                    status):
    """
    Logs the time to complete a specific activity

    Args:
        start_time (_type_): time when the activity began
        end_time (_type_): time when the activity ended
        item_id (_type_): item id
        file_name (_type_): file name
    """
    
    time_to_process_file = end_time - start_time
   
    mmap.measure_float_put(message_processed_measure, 
                           time_to_process_file.total_seconds())
    mmap.record(tag_map_module.TagMap()
                .insert("Processor", "STAC to PG"))
    
    mmap.measure_int_put(message_count_measure, 1)
    
    tagMap = tag_map_module.TagMap()
    
    tagMap.insert("Status", status)
    tagMap.insert("Processor", "STAC to PG")
    
    mmap.record(tagMap)

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
    with ServiceBusClient.from_connection_string(conn_str=PGSTAC_SERVICE_BUS_CONNECTION_STRING, 
                                                retry_total=1, 
                                                retry_backoff_factor=10, 
                                                retry_mode="fixed") as client:
        
        receiver = client.get_subscription_receiver(
            topic_name=PGSTAC_SERVICE_BUS_TOPIC_NAME, 
            subscription_name=PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME)

        with receiver:
            for msg in receiver:

                try:
                    
                    # start time for processing
                    start_time = datetime.utcnow()

                    data = json.loads(str(msg))
                    
                    json_file_path = asyncio.run(download_blob_data(data['data']['url']))
                    ndjson_file_path = convert_json_to_ndjson(json_file_path)
                    item_id = pypgstac_load_item(ndjson_file_path)

                    os.remove(json_file_path)
                    os.remove(ndjson_file_path)

                    # end time for processing
                    end_time = datetime.utcnow()

                     # log time to complete to application insights
                    _record_message(
                            start_time, end_time, "Success")
                    
                    _record_data_info(0, "Success")

                    receiver.complete_message(msg)
                    
                except Exception as e:
                    
                    # todo: parameterize the max delivery count for the topic
                    if msg.deliver_count == 2:
                        # log time to complete to application insights
                        _record_message(
                            start_time, datetime.utcnow(), "Failed")
                        _record_data_info(0, "Failed")
                    
                    logger.error(
                        "error", f"item_id: {item_id} error message: {e}")
                    
                    receiver.abandon_message(msg)


if __name__ == "__main__":
    
    try:
        
        message_processed_measure = measure_module.MeasureFloat("message_proc_time",
                            "Time for a single message to get processed",
                            "ms")
    
        message_processed_view = view_module.View("Message Processing Time",
                            "Average runtime for a message to be processed",
                            [tag_key_module.TagKey("Processor")],
                            message_processed_measure,
                            aggregation_module.LastValueAggregation())
        
        message_count_measure = measure_module.MeasureInt("message_count",
                            "Processing of a single message",
                            "message")
        
        message_count_view = view_module.View("Message Count",
                            "Count of messages processed",
                            [tag_key_module.TagKey("Status"),
                             tag_key_module.TagKey("Processor")],
                            message_count_measure,
                            aggregation_module.SumAggregation())
        
        data_size_measure = measure_module.MeasureInt("data_size",
                            "Size of message being processed",
                            "bytes")
        
        data_size_view = view_module.View("Data Size",
                            "Total size of data being processed",
                            [tag_key_module.TagKey("Pod Name"),
                             tag_key_module.TagKey("Status"),
                             tag_key_module.TagKey("Processor")],
                            data_size_measure,
                            aggregation_module.SumAggregation())
        
        pod_count_measure = measure_module.MeasureInt("pod_count",
                            "Number of pod that are currently active",
                            "pods")
        
        pod_count_view = view_module.View("Pods Count",
                            "Total number of pods that are active",
                            [tag_key_module.TagKey("Pod Name"), 
                             tag_key_module.TagKey("Node Name"),
                             tag_key_module.TagKey("Processor")],
                            pod_count_measure,
                            aggregation_module.SumAggregation())
        
        mmap = _setup_open_census()
        
        _record_pod_info()
        
        main()
        
    except Exception as e:
        logger.error(
            "error", f"error message: {e}")
