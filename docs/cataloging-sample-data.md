# Cataloging the sample data

Sample data is hosted in a Storage Account that is available for anyone to download without authentication. The data in this Storage Account can be used to run through the cataloging process and then queries through the STAC API.

The steps below walks you through the creation of STAC Collection and STAC Item. When following the steps below, make sure the order of execution is followed as the sequence of upload is critical to the cataloging process.

## Steps to Catalog Sample data

1. First step in the process is the creation of the [STAC collection](https://github.com/radiantearth/stac-spec/blob/master/collection-spec/collection-spec.md). A STAC Collection is created by from a [json document](https://aoigeospatial.blob.core.windows.net/stac/collection_naip_test.json) that is uploaded to the appropriate container in the Storage Account.


    ```bash
    azcopy copy https://aoigeospatial.blob.core.windows.net/stac/collection_naip_test.json ~/data/collection_naip_test.json
    ```

    ```bash
    azcopy copy ~/data/collection_naip_test.json "https://<storage account>.blob.core.windows.net/staccollection/collection_naip_test.json?<SAS-token>" --recursive=true
    ```

2. Once the STAC collection is created, the next steps is to create the [STAC Items](https://github.com/radiantearth/stac-spec/blob/master/item-spec/item-spec.md). Addition of the STAC Item to a STAC Collection is two step process.

    a. Upload metadata
 
    ```bash
    azcopy copy https://aoigeospatial.blob.core.windows.net/stac/v002/wa/2015/wa_fgdc_2015/45117 ~/data/fgdc/ --recursive=true
    ```

    ```bash
    azcopy copy ~/data/fgdc/45117 "https://<storage account>.blob.core.windows.net/stacify/v002/wa/2015/wa_fgdc_2015?<SAS-token>" --recursive=true
    ```

    b. Upload raster data

    ```bash
    azcopy copy https://aoigeospatial.blob.core.windows.net/stac/v002/wa/2015/wa_100cm_2015/45117 ~/data/100cm/ --recursive=true
    ```

    ```bash
    azcopy copy ~/data/100cm/45117 "https://<storage account>.blob.core.windows.net/stacify/v002/wa/2015/wa_100cm_2015?<SAS-token>" --recursive=true
    ```

## Steps to validate Cataloged data


Run the below curl command for validation:
    
```bash

curl <Gateway URL>/api/collections/naip | json_pp

curl <Gateway URL>/api/collections/naip/items | json_pp

```