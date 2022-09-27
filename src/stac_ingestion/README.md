<div align='center'>
    <img width="300" height="200" src="./giphy.gif">
    <h1>STAC INGESTION</h1>
</div>

### What do these services do?

This service consists of 4 separate applications for processing a STAC items:

1. stac_collection will add your collection to postgres.
2. generate_stac_item, will process your assets and generate a stac item.
3. stac_to_pg, will add your stac items to postgres.


## [stac_collection](/src/stac_ingestion/stac_collection/README.md)
The stac_collection service adds your [stac collection](https://github.com/radiantearth/stac-spec/blob/master/collection-spec/collection-spec.md) to postgres. To get started, please checkout the [README](/src/stac_ingestion/stac_collection/README.md) for more information on how to get started.

## [generate_stac_item](/src/stac_ingestion/generate_stac_item/README.md)
The generate_stac_item service generates a [stac item](https://github.com/radiantearth/stac-spec/blob/master/item-spec/item-spec.md) by processing the assets you provide such as a COG, JPEG, metadata file(optional), and additional data such as the state, and date.

### the process
1. Before a stac item can be processed, a [collection](https://github.com/radiantearth/stac-spec/tree/master/collection-spec) must be added to postgres. Please go to the stac_collection [README](/src/stac_ingestion/stac_collection/README.md) for directions on how to add your collection.

## [stac to postgres (stac_to_pg)](/src/stac_ingestion/stac_to_pg/)
- Adds stac item to postgres via [pypgstac](https://github.com/stac-utils/pgstac).

## [Architecture](#architecture)
![architecture](/docs/architecture.png)

## Deployment
For details on deployment, please go to the deployment folder [here](/deploy/README.md)

## Mock Collection Data

Within the folder [mock_data](/sample/data/) you will find a test collection_naip_test.json that will add NAIP to the collection.

## Tutorials (WIP)

- [Here](https://msit.microsoftstream.com/video/658b0840-98dc-ae81-e0a9-f1ed1a8827b2?list=studio) is a short video about how to get generate_stac_item up and running.
- This [short tutorial](https://msit.microsoftstream.com/video/9cd70840-98dc-ae81-ed6b-f1ed1a8d1ed2) shows you how to query for naip data w/ Azure data explorer and fast-stacAPI via Azure API management Service