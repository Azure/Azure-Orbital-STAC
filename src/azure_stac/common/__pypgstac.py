# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import subprocess


def load_item(file_path: str) -> None:
    """Load stac item to PostgreSQL
    :param file_path: Absolute path to the JSON file that contains the STAC Item
    :type file_path: str
    :returns: None
    :rtype: None
    """

    try:
        cmd = f"pypgstac load items {file_path} --method insert".split()

        subprocess.check_call(cmd)

    except Exception as e:
        raise e
