# STAC_COLLECTION

This service enables a user to add a collection to postgres.

### Requirements
- A postgres instance must be deployed with [pgstac](https://github.com/stac-utils/pgstac) installed.
- Azure storage w/eventgrid subscription.
- Azure Service bus w/ topic.

### Quickstart
1. Have this service deployed to Azure or running locally.
2. If running local, make sure you have all your environment variables are set in an `.env` file.
3. Once you setup your storage account w/ EventGrid and ServiceBus w/ a topic, subscription to topic, and policy, you can now start your app.
4. Run `pip install -r requirements.txt	`
5. Run `python main.py`
6. Copy your collection json file into the blob container that you setup earlier.
7. After processing the json, you should be able to query your postgres DB or use [stac-fastAPI](https://github.com/stac-utils/stac-fastapi).