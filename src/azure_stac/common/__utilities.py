# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import json
import os
from pathlib import Path


def getenv(variable_name: str) -> str:
    """Gets an environment variable or raises an exception if it is not set
    :param variable_name: Name of the environment variable
    :type variable_name: str
    :returns: Environment variable value
    :rtype: str
    """

    value = os.getenv(variable_name)
    if value is None:
        raise ValueError(f"{variable_name} is not set")

    return value


def convert_json_to_ndjson(file_path: str) -> str:
    """Converts json to ndjson
    :param file_path: Absolute path to the JSON file to be converted to NDJSON
    :type file_path: str
    :returns: None
    :rtype: str
    """

    ndjson_name = Path(file_path).stem + ".ndjson"

    try:
        with open(file_path, "r") as file:
            data = json.load(file)

            with open(ndjson_name, "w") as outfile:
                json.dump(data, outfile, separators=(",", ":"))

    except Exception as e:
        raise e

    return ndjson_name
