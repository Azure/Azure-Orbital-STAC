# GENERATE_STAC_ITEM

## Requirements

- It's assumed that you have the infrastructure deployed using the scripts in the [deployment](/deploy/) folder. README to the deployment will be linked here when available. You can view the system diagram [here](/docs/architecture.png) as a checklist of all the required services.
- If running locally, create a `.env` file and copy all of `dev.env` variables into the `.env` and set them.

## Quickstart

1. If running locally, run `pip install -r requirements.txt`
2. run `python main.py`
3. Assuming the collection is in postgres, copy metadata over to the `stacify` folder with the structure as so: `v002/<state>/<year>/<state>_fgdc_<year>/45116/<file name>.txt`
4. Copy over COGs and JPEG to the folder structure as so `v002/<state>/<year>/<state>_100cm_<year>/45116/<file name>.tif`

## What happens when the assets are copied to an azure blob container?

Copying over these assets will trigger an event via EventGrid. This service will capture the message from EventGrid via [Azure Service Bus](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview) topic. When the message is received, generate_stac_item will download the necessary files to process the stac item and send the json to the `pgstac` blob container.
