import itertools
import os
import re
from datetime import timedelta
from typing import Final, Optional, Pattern

import dateutil.parser
import pystac
import rasterio as rio
from pystac.extensions.eo import EOExtension
from pystac.extensions.item_assets import ItemAssetsExtension
from pystac.extensions.projection import ProjectionExtension
from pystac.extensions.raster import DataType, RasterBand, RasterExtension
from pystac.utils import str_to_datetime
from shapely.geometry import box, mapping, shape
from stactools.core.io import read_text
from stactools.core.projection import reproject_geom

from _env_variables import (DATA_STORAGE_ACCOUNT_CONNECTION_STRING,
                            DATA_STORAGE_ACCOUNT_KEY,
                            DATA_STORAGE_ACCOUNT_NAME, STAC_BANDS,
                            USDA_PROVIDER, COLLECTION_ID)
from _generate_sas import get_sas_token
from _grid import GridExtension
from _naip_utils import parse_fgdc_metadata

# Generate sas token for metadata url
# TODO: This is a temporary solution until we can pass headers
sas_token = get_sas_token()

log = rio.logging.getLogger()
log.setLevel(rio.logging.DEBUG)

# pattern for creating a Digital Orthophoto Quarter Quadrangle title from item title
# https://github.com/stac-extensions/grid/
DOQQ_PATTERN: Final[Pattern[str]] = re.compile(
    r"[A-Za-z]{2}_m_(\d{7})_(ne|se|nw|sw)_")


def generate_stac_item_id(state, resource_name):
    """Generates a STAC Item ID based on the state and the "Resource Description"
    contained in the FGDC metadata.

    Args:
        state (str): The two-letter state code for the state this belongs to.
        resource_name (str): The resource name, e.g. m_3008501_ne_16_1_20110815_20111017.tif

    Returns:
        str: The STAC ID to use for this scene.
    """

    return "{}_{}".format(state, os.path.splitext(resource_name)[0])


def get_metadata_sas_url(href: str) -> str:
    return str(f"{href}?{sas_token}")


def create_item(
    state,
    year,
    cog_href,
    metadata_href: Optional[str],
    thumbnail_href=None,
    additional_providers=None,
    cog_url=None,
):
    """Creates a STAC Item.

    Args:
        state (str): The 2-letter state code for the state this item belongs to.
        year (str): year.
        metadata_href (str): The href to the metadata
        cog_href (str): The href to the image as a COG. This needs
            to be an HREF that rasterio is able to open.
        thumbnail_href (str): Optional href for a thumbnail for this scene.
        additional_providers(List[pystac.Provider]): Optional list of additional
            providers to the USDA that will be included on this Item.

    This function will read the metadata file for information to place in
    the STAC item.

    Returns:
        pystac.Item: A STAC Item representing a scene.
    """

    # Reasoning for setting readdiri_on_open to "EMPTY_DIR": https://trac.osgeo.org/gdal/wiki/ConfigOptions#GDAL_DISABLE_READDIR_ON_OPEN
    # Uncomment CPL_CURL_VERBOSE=1 to see the curl output
    gdal_env = {
        "AZURE_NO_SIGN_REQUEST": "NO",
        "AZURE_STORAGE_ACCOUNT_NAME": DATA_STORAGE_ACCOUNT_NAME,
        "AZURE_STORAGE_ACCESS_KEY": DATA_STORAGE_ACCOUNT_KEY,
        "AZURE_STORAGE_CONNECTION_STRING": DATA_STORAGE_ACCOUNT_CONNECTION_STRING,
        "GDAL_DISABLE_READDIR_ON_OPEN": "EMPTY_DIR",
    }

    try:
        try:
            with rio.Env(**gdal_env):
                with rio.open(cog_href) as ds:
                    # gsd = ground sample distance
                    gsd = round(ds.res[0], 1)
                    epsg = int(ds.crs.to_authority()[1])
                    image_shape = list(ds.shape)
                    original_bbox = list(ds.bounds)
                    transform = list(ds.transform)
                    geom = reproject_geom(
                        ds.crs, "epsg:4326", mapping(box(*ds.bounds)), precision=6
                    )

        except rio.errors.RasterioIOError as err:
            print(f"{cog_href} rasterio read failed: here is the error: {err}")
            raise

        if metadata_href is not None:
            stac_metadata_text = read_text(
                metadata_href, get_metadata_sas_url)
            stac_metadata = parse_fgdc_metadata(stac_metadata_text)
        else:
            stac_metadata = {}

        if "Distribution_Information" in stac_metadata:
            resource_desc = stac_metadata["Distribution_Information"]["Resource_Description"]
        else:
            resource_desc = os.path.basename(cog_href)
        item_id = generate_stac_item_id(state, resource_desc)

        bounds = list(shape(geom).bounds)

        if any(stac_metadata):
            dt = str_to_datetime(
                stac_metadata["Identification_Information"]["Time_Period_of_Content"][
                    "Time_Period_Information"
                ]["Single_Date/Time"]["Calendar_Date"]
            )
        else:
            fname = os.path.splitext(os.path.basename(cog_href))[0]
            fname_date = fname.split("_")[5]
            dt = dateutil.parser.isoparse(fname_date)

        # UTC is +4 ET, so is around 9-12 AM in CONUS
        dt = dt + timedelta(hours=16)
        properties = {f"{COLLECTION_ID}:state": state,
                      f"{COLLECTION_ID}:year": year}

        item = pystac.Item(
            id=item_id, geometry=geom, bbox=bounds, datetime=dt, properties=properties, collection=COLLECTION_ID
        )

        # Common metadata
        item.common_metadata.providers = [USDA_PROVIDER]
        if additional_providers is not None:
            item.common_metadata.providers.extend(additional_providers)
        item.common_metadata.gsd = gsd

        # EO Extension, for asset bands
        EOExtension.add_to(item)

        # Projection Extension
        projection = ProjectionExtension.ext(item, add_if_missing=True)
        projection.epsg = epsg
        projection.shape = image_shape
        projection.bbox = original_bbox
        projection.transform = transform

        # Grid Extension
        grid = GridExtension.ext(item, add_if_missing=True)
        if match := DOQQ_PATTERN.search(item_id):
            grid.code = f"DOQQ-{match.group(1)}{match.group(2).upper()}"

        # COG
        item.add_asset(
            "image",
            pystac.Asset(
                href=cog_url,
                media_type=pystac.MediaType.COG,
                roles=["data"],
                title="RGBIR COG tile",
            ),
        )

        # Metadata
        if any(stac_metadata) and metadata_href is not None:
            item.add_asset(
                "metadata",
                pystac.Asset(
                    href=metadata_href,
                    media_type=pystac.MediaType.TEXT,
                    roles=["metadata"],
                    title="FGDC Metadata",
                ),
            )

        if thumbnail_href is not None:
            media_type = pystac.MediaType.JPEG
            if thumbnail_href.lower().endswith("png"):
                media_type = pystac.MediaType.PNG
            item.add_asset(
                "thumbnail",
                pystac.Asset(
                    href=thumbnail_href,
                    media_type=media_type,
                    roles=["thumbnail"],
                    title="Thumbnail",
                ),
            )

        image_asset = item.assets["image"]

        # EO Extension
        asset_eo = EOExtension.ext(image_asset)
        asset_eo.bands = STAC_BANDS

        # Raster Extension
        RasterExtension.ext(image_asset, add_if_missing=True).bands = list(
            itertools.repeat(
                RasterBand.create(
                    nodata=0,
                    spatial_resolution=gsd,
                    data_type=DataType.UINT8,
                    unit="none",
                ),
                4,
            )
        )

        return item
    except Exception as e:
        print(f"Error creating item for {cog_href}: {e}")
