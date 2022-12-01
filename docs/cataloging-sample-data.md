# Cataloging the sample data

Sample data is hosted in a Storage Account that is available for anyone to download without authentication. The data in this Storage Account can be used to run through the cataloging process and then queries through the STAC API.

The steps below walks you through the creation of STAC Collection and STAC Item. When following the steps below, make sure the order of execution is followed as the sequence of upload is critical to the cataloging process.

## Steps to Catalog Sample data

1. First step in the process is the creation of the [STAC collection](https://github.com/radiantearth/stac-spec/blob/master/collection-spec/collection-spec.md). A STAC Collection is created from a [json document](../deploy/sample-data/collection_naip_test.json) that is uploaded to the appropriate container in the Storage Account.


    ```bash
    wget https://raw.githubusercontent.com/Azure/Azure-Orbital-STAC/main/deploy/sample-data/collection_naip_test.json -P ~/data
    ```

    ```bash
    azcopy copy ~/data/collection_naip_test.json "https://<data-storage-account>.blob.core.windows.net/staccollection/collection_naip_test.json?<SAS-token-for-data-storage-account>" --recursive=true
    ```

2. Generate the SAS token for getting the data from Planetary Computers using the link https://planetarycomputer.microsoft.com/api/sas/v1/token/naip. Clicking on the link will give an output like this:

    ```
    {
        "msft:expiry":"2021-04-08T18:49:29Z",
        "token":"se=2021-04-08T18%3A49%3A29Z&sp=rl&sv=2020-02-10&sr=c&skoid=cccccccc-****-****-aaaa-eee****ee&sktid=***&skt=2021-04-08T17%3A47%3A29Z&ske=2021-04-09T17%3A49%3A29Z&sks=b&skv=2020-02-10&sig=******bbbbbbbb****bbbbbbbbbb***b%3D"
    }
    ```
    The `token` field is the SAS token. The `msft:expiry` field specifies the time (in UTC) this token expires, which is 45 mins from the time it was first generated.

    We will use this token to download the sample data.


3. Once the STAC collection is created, the next steps is to create the [STAC Items](https://github.com/radiantearth/stac-spec/blob/master/item-spec/item-spec.md). Addition of the STAC Item to a STAC Collection is two step process.

    a. Upload metadata
 
    ```bash
    azcopy copy "https://naipeuwest.blob.core.windows.net/naip/v002/wa/2015/wa_fgdc_2015/45117?<token-obtained-in-step-2>" ~/data/fgdc/ --recursive=true
    ```

    ```bash
    azcopy copy ~/data/fgdc/45117 "https://<data-storage-account>.blob.core.windows.net/stacify/v002/wa/2015/wa_fgdc_2015?<SAS-token-for-data-storage-account>" --recursive=true
    ```

    b. Upload raster data

    ```bash
    azcopy copy "https://naipeuwest.blob.core.windows.net/naip/v002/wa/2015/wa_100cm_2015/45117?<token-obtained-in-step-2>" ~/data/100cm/ --recursive=true
    ```

    ```bash
    azcopy copy ~/data/100cm/45117 "https://<data-storage-account>.blob.core.windows.net/stacify/v002/wa/2015/wa_100cm_2015?<SAS-token-for-data-storage-account>" --recursive=true
    ```

## Steps to validate Cataloged data


Run the below curl command for validation:
    
```bash

curl <Gateway URL>/api/collections/naip | json_pp

curl <Gateway URL>/api/collections/naip/items | json_pp

```