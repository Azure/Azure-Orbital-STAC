# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import traceback

from stac.core.processor import BaseProcessor
from stac.core.metrics import sendmetrics
from stac.processors.naip.__stac import create_item

from typing import Tuple

from osgeo import gdal

class ExtractStac4mNaip(BaseProcessor):
    
    TEMPLATE_NAME = 'Extract STAC From NAIP'
    VERSION = '1.0'
    
    LOCAL_FILE_PATH = './'
    
    def __init__(self):
        
        super().__init__()
        self.__get_envvars()
        
    
    def __get_envvars(self) -> None:
        """Get all the environment variables relevant for this processor
        :returns: None
        :rtype: None
        """
        
        import os
        
        self.JPG_EXTENSION = os.getenv('JPG_EXTENSION')
        self.XML_EXTENSION = os.getenv('XML_EXTENSION')
        self.DST_CONTAINER_NAME = os.getenv('DATA_STORAGE_PGSTAC_CONTAINER_NAME')
        self.SRC_CONTAINER_NAME = os.getenv('STACIFY_STORAGE_CONTAINER_NAME')
        self.STAC_METADATA_TYPE_NAME = os.getenv('STAC_METADATA_TYPE_NAME')
        self.CONNECTION_STRING = os.getenv('DATA_STORAGE_ACCOUNT_CONNECTION_STRING')
        self.STORAGE_ACCOUNT_NAME = os.getenv('DATA_STORAGE_ACCOUNT_NAME')
        
    
    def __create_item_in_blob(self,
                              state: str, 
                              year: str, 
                              cog_href: str, 
                              dst: str, 
                              thumbnail: str, 
                              providers: str, 
                              cog_url: str, 
                              stac_metadata: str = None) -> str:
        """Creates a STAC Item based on metadata.

            STATE is the state this NAIP tile belongs to.
            COG_HREF is the href to the COG that is the NAIP tile.
            FGDC_HREF is href to the text metadata file in the NAIP fgdc format.
            DST is directory that a STAC Item JSON file will be created
            in.
        """
        import os
        import json
        import pystac
        
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
        item_path = os.path.join(self.LOCAL_FILE_PATH, "{}.json".format(item.id))

        # save blob store self link
        item.set_self_href(f"{dst}/{item.id}.json")

        # save to local file system
        item.save_object(dest_href=item_path)

        return item.id
        
    
    def __translate_tif_to_jpeg(self, 
                                title: str,
                                tif_file: str) -> None:
        
        """ Translates a TIFF file to a JPEG file.
        :param title: Name of the translated output JPEG
        :type title: str
        :param tif_file: Name of the GeoTiff to translate
        :type tif_file: str
        :returns: None
        :rtype: None
        """
        option_list = [
            '-ot byte',
            '-of JPEG',
            '-outsize 100% 100%',
        ]
        
        option_string = ' '.join(option_list)

        try:
            # generate jpeg and aux.xml for COG
            gdal.Translate(
                f"{title}.{self.JPG_EXTENSION}", tif_file, options=option_string)
        except Exception as err:
            
            raise err
            
            
    def __get_url_variations(self, cog_url: str) -> Tuple[str, str, str, str]:
        """ Gets variations of the COG URL to provide the required absolute &
        relative URLs and/or paths required for constructing the various source
        and destination locations for raster data, it's metadata and other supporting
        files.
        :param cog_url: Full URL of the COG file uploaded to the Storage Account
        :type cog_url: str
        :returns: Attributes version, state, year, state measurement year and folder number (in the order)
        :rtype: Tuple[str, str, str, str]
        """
        
        import os
        
        split_url = os.path.dirname(cog_url).split('/')
        
        domain_path = split_url[0:4]
        
        domain_path_joined = '/'.join(domain_path)

        split_url_joined = '/'.join(split_url[4:7])
        
        return split_url, split_url_joined, domain_path, domain_path_joined
         
            
    def __parse_url_based_attributes(self, url: str) -> Tuple[str, str, str, str, str]:
        
        """ Parses key attributes including (but not limited to) version, state, year from 
        url path where the raster data is being downloaded from
        :param url: URL of the raster data to be downloaded
        :type url: str
        :returns: Attributes version, state, year, state measurement year and folder number (in the order)
        :rtype: Tuple[str, str, str, str, str]
        """
        
        # retrieve attributes from folder path. folder path is expected
        # to be in the format:
        # https://storage-name.blob.core.azure.com/container/v002/wa/2015/wa_100cm_2015/45117/filename.ext
        # all indexes are zero-index based
        version = url[4]
        state = url[5]
        year = url[6]
        state_measurement_year = url[7]
        folder_number = url[8]
        
        return version, state, year, state_measurement_year, folder_number
        
        
    @sendmetrics
    def run(self, **kwargs) -> None:
        """ Execute the processor """
        
        import os
        import asyncio
                
        from pathlib import Path
        from urllib.parse import urlparse
        from stac.common.__blob_service import (check_if_blob_exists, 
                                                upload_blob_async,
                                                download_blob_async)
        
        # call parent method to bootstrap the required metrics
        # and hooks
        super(type(self), self).run(**kwargs)
        
        for msg in self.begin_listening():
            
            try:
                cog_url = msg['data']['url']
                
                file_name = Path(cog_url).name
                
                file_name_without_ext = Path(cog_url).stem
                
                # makes sure the file format is supported file format for this processor
                if not file_name.endswith('.tif') and not file_name.endswith('.tiff'):
                    
                    raise TypeError('Invalid file format. Only GeoTiff file formats are supported')

                # set of temporary/intermediate variables that will be used for deriving the 
                # metadata URL, asset URL, preview URL and so on.
                split_url, split_url_joined, _, domain_path_joined = self.__get_url_variations(cog_url)

                version, state, year, state_measurement_year, folder_number = self.__parse_url_based_attributes(split_url)
    
                jpeg_url = os.path.splitext(
                    cog_url)[0] + f".{self.JPG_EXTENSION}"
                
                joined_jpeg_tail_path = '/'.join(
                    jpeg_url.split('/')[4:-1])
                
                # az file schema URL is for use with GDAL libraries to access Storage Account
                azure_raster_url = f'az://{self.SRC_CONTAINER_NAME}/{version}/{state}/{year}/{state_measurement_year}/{folder_number}/{file_name}'
                
                # full download URL for the tif file
                download_tif_url = f'{split_url_joined}/{state_measurement_year}/{folder_number}/{file_name}'

                # full download URL for metadata file that is derived from known attributes like state
                fdgc_metadata_url = f'{domain_path_joined}/{split_url_joined}/{state}_{self.STAC_METADATA_TYPE_NAME}_{year}/{folder_number}/{file_name_without_ext}.txt'
                
                # full download URL for preview file that is derived from known attributes
                jpeg_url = f'{domain_path_joined}/{joined_jpeg_tail_path}/{file_name_without_ext}.{self.JPG_EXTENSION}'

                # check if metadata file exists
                does_metadata_file_exist = asyncio.run(check_if_blob_exists(
                    conn_str=self.CONNECTION_STRING,
                    container_name=self.SRC_CONTAINER_NAME,
                    blob_name=f"{split_url_joined}/{state}_{self.STAC_METADATA_TYPE_NAME}_{year}/{folder_number}/{file_name_without_ext}.txt"
                    ))

                # check if jpeg (preview) exists
                does_jpeg_file_exist = asyncio.run(check_if_blob_exists(
                    conn_str=self.CONNECTION_STRING,
                    container_name=self.SRC_CONTAINER_NAME,
                    blob_name=f"{joined_jpeg_tail_path}/{file_name_without_ext}.{self.JPG_EXTENSION}"
                    ))

                
                # checks if the jpeg file exists (jpeg files are preview files for
                # the bigger raster data) and intended to be served as one of the 
                # assets for the STAC Item
                if not does_jpeg_file_exist:
                    
                    try:
                        # todo: fix this - takes 3 arguments; not one
                        asyncio.run(
                            download_blob_async(conn_str=self.CONNECTION_STRING,
                                                container_name=self.SRC_CONTAINER_NAME,
                                                file_path=download_tif_url,
                                                destination_path='./'))
                        
                        
                        self.__translate_tif_to_jpeg(
                            file_name_without_ext, file_name)

                        # upload jpeg & aux.xml to azure storage
                        for file_to_upload in (f'{file_name_without_ext}.{self.JPG_EXTENSION}', 
                                               f'{file_name_without_ext}.{self.JPG_EXTENSION}.{self.XML_EXTENSION}'):

                            asyncio.run(upload_blob_async(
                                conn_string=self.CONNECTION_STRING,
                                container_name=self.SRC_CONTAINER_NAME,
                                file_path='./', 
                                file_name=file_to_upload))

                    except Exception as e:
                        
                        # bubble up the exception if you want the base class to abandon
                        # the message
                        raise e
                
                
                # if the metada file does not exists, we need to generate the 
                # necessary metadata before generating the STAC Item json file
                # which will be ingested into the PostgreSQL database
                # ------------ or ------------
                # if the metadata file exists, the process to generate the 
                # STAC Item json file is relatively simple. Minimal metadata 
                # is generated from the raster data and then merge with the 
                # metadata provided in the metada file to generate the STAC 
                # item which will be ingested in the PostgreSQL database
                item_id = self.__create_item_in_blob(state=state,
                                                year=year,
                                                cog_href=azure_raster_url,
                                                dst=f"https://{self.STORAGE_ACCOUNT_NAME}.blob.core.windows.net/{self.DST_CONTAINER_NAME}",
                                                stac_metadata=fdgc_metadata_url if does_metadata_file_exist else None,
                                                thumbnail=jpeg_url,
                                                providers=None,
                                                cog_url=cog_url,
                                                )
                    
                # upload stac item to blob
                asyncio.run(upload_blob_async(
                    conn_str=self.CONNECTION_STRING,
                    container_name=self.DST_CONTAINER_NAME,
                    file_name=f"{item_id}.json"))
                    
                # remove stac item from local file system
                os.remove(f"{item_id}.json")
                    
                    
            except Exception as e:
                
                # bubble up the exception if you want the base class to abandon
                # the message
                raise e
            
            finally:
                # printing stack trace
                traceback.print_exc()
                
def execute_processor():
    
    return ExtractStac4mNaip().run()