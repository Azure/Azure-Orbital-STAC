# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from setuptools import setup, find_packages

DEPENDENCIES= [
    'knack',
    'azure-servicebus==7.8.1',
    'azure-storage-blob==12.14.1',
    'pystac==1.6.1',
    'python_dateutil==2.8.2',
    'python_dotenv==0.21.0',
    'rasterio==1.3.4',
    'stactools==0.4.2',
    'psycopg[binary]==3.1.7',
    'pypgstac[psycopg]==0.6.11'
],

setup(
    name='stac-cli',
    version='0.1.0',
    packages=find_packages(include=['stac', 'stac.*']),
    scripts=[
        'stac'
    ],
    python_requires='>=3.7.0',
    install_requires=DEPENDENCIES
)