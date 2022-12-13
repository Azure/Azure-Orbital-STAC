# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from core.processor import BaseProcessor
from stac.core.metrics import sendmetrics


class StacItem2Postgres(BaseProcessor):
    
    TEMPLATE_NAME = 'Ingest STAC Item'
    VERSION = '1.0'
    
    def __init__(self):
        
        super().__init__()
        
    def __get_envvars(self):
        import os
        
        self.CONNECTION_STRING = os.getenv('DATA_STORAGE_ACCOUNT_CONNECTION_STRING')
        self.CONTAINER_NAME = os.getenv('DATA_STORAGE_PGSTAC_CONTAINER_NAME')
        
      
    @sendmetrics
    def run(self, **kwargs):
        """ Ingest STAC item to PostgreSQL """
        
        import asyncio
        from stac.common.__blob_service import download_blob_async
        from stac.common.__pypgstac import load_item
        from stac.common.__utilities import convert_json_to_ndjson
        
        # call parent method to bootstrap the required metrics
        # and hooks
        super(type(self), self).run(**kwargs)
        
        self.__get_envvars()
        
        for msg in self.begin_listening():
            
            try:
                
                file_name = msg['data']['url']
                
                json_file_path = asyncio.run(download_blob_async(conn_str=self.CONNECTION_STRING,
                                                                 container_name=self.CONTAINER_NAME,
                                                                 file_path=file_name,
                                                                 destination_path='./'))
                
                ndjson_file_path = convert_json_to_ndjson(json_file_path)
                
                load_item(ndjson_file_path)
 
            except Exception as e:
                
                raise e
        
def execute_processor():
        
    return StacItem2Postgres().run()      