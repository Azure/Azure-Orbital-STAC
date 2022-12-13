# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from core.processor import BaseProcessor
from stac.core.metrics import sendmetrics

class StacCol2Postgres(BaseProcessor):
    
    TEMPLATE_NAME = 'Ingest STAC Collection'
    VERSION = '1.0'
    
    # todo: this initialization may not be needed, test and remove it
    PGHOST = ''
    PGUSER = ''
    PGDATABASE = ''
    PGPASSWORD = ''
    CONN_STRING = ''
    CONTAINER_NAME = ''
    
    def __init__(self):
        
        super().__init__()
        
    def __get_envvars(self) -> None:
        """Get all the environment variables relevant for this processor
        :returns: None
        :rtype: None
        """
        import os
        
        self.PGHOST = os.getenv('PGHOST')
        self.PGUSER = os.getenv('PGUSER')
        self.PGDATABASE = os.getenv('PGDATABASE')
        self.PGPASSWORD = os.getenv('PGPASSWORD')
        self.CONN_STRING = os.getenv('DATA_STORAGE_ACCOUNT_CONNECTION_STRING')
        self.CONTAINER_NAME = os.getenv('STACCOLLECTION_STORAGE_CONTAINER_NAME')
    
    @sendmetrics
    def run(self, **kwargs):
        """ Ingest STAC collection to PostgreSQL """
        
        import os
        import json
        import asyncio
        import psycopg2
        from stac.common.__blob_service import download_blob_async
        
        # call parent method to bootstrap the required metrics
        # and hooks
        super(type(self), self).run(**kwargs)
        
        self.__get_envvars()
        
        # Database connector
        conn = ''
        
        # Construct connection string
        conn_string = "host={0} user={1} dbname={2} password={3}".format(
            self.PGHOST, self.PGUSER, self.PGDATABASE, self.PGPASSWORD)
        try:
            conn = psycopg2.connect()
            
        except Exception as e:
            
            pass
        
        for msg in self.begin_listening():
            
            # Is connection closed? if so, open a new connection 
            if conn.closed:
                
                try:
                    # todo: make sure to assert that kwargs has conn_string
                    # before you use it
                    conn = psycopg2.connect(conn_string)
                    
                except Exception as e:
                    
                     pass

            cursor = conn.cursor()
            
            file_url = msg['data']['url']
            
            try:
                json_file = os.path.basename(file_url)
                
                # download the json file locally
                asyncio.run(
                    download_blob_async(conn_str=self.CONN_STRING,
                                        container_name=self.CONTAINER_NAME,
                                        file_path=json_file,
                                        destination_path='./'))
                
                # todo: path is different in the new solution
                with open('./' + json_file, 'r') as f:
                    
                    # read json from file content that was
                    # read as string
                    data = json.dumps(json.load(f))
                    
                    # send the json for ingestion to PostgreSQL
                    cursor.callproc('pgstac.create_collection', [data])

                    conn.commit()

                    os.remove(json_file)
                    
            except Exception as e:
                
                raise e
                
        
def execute_processor():
    
    return StacCol2Postgres().run()
        