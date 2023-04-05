# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os

import pystac
from pystac.extensions.eo import Band
from pystac.provider import ProviderRole


def get_env_variable(variable_name, default_value=None):
    value = os.getenv(variable_name)
    if value is None:
        if default_value is None:
            raise ValueError(variable_name + " is not set")
        else:
            value = default_value
    return value

USDA_PROVIDER = get_env_variable('USDA_PROVIDER', pystac.Provider(
    name="USDA Farm Service Agency",
    url=(
        "https://www.fsa.usda.gov/programs-and-services/aerial-photography"
        "/imagery-programs/naip-imagery/"
    ),
    roles=[ProviderRole.PRODUCER, ProviderRole.LICENSOR],
))

STAC_BANDS = get_env_variable('STAC_BANDS', [
    Band.create(name="Red", common_name="red"),
    Band.create(name="Green", common_name="green"),
    Band.create(name="Blue", common_name="blue"),
    Band.create(name="NIR", common_name="nir", description="near-infrared"),
])