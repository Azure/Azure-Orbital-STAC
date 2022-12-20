# STAC TO PGSTAC

## TL;DR

This service adds a stac item to postgres via [pypgstac](https://github.com/stac-utils/pgstac)

## Requirements

- Assumption is that all infrastructure is deployed with [deploy scripts](/deploy/)
- If running locally
  - Python 3 must be installed
  - create a `.env` with the same variable names as `dev.env` and assign them.

## Quickstart

1. run `pip installed -r requirements.txt`
2. run `python main.py`

### What happens when your files get processed?

Once the json files are processed with pgstac, that data is stored in postgres. You can now query your data directly or with fast-stacAPI.
