# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import re
from typing import Any, Optional


def parse_fgdc_metadata(md_text: str) -> Any:
    """Parses FGDC metadata. FGDC is a structure specific to NAIP data source.
    :param md_text: Markdown text
    :type md_text: str
    :returns: metadata
    :rtype: any
    """

    line_pattern = r"([\s]*)([^:]+)*(\:?)[\s]*(.*)"

    def _parse(lines: list[str], group_indent: int = 0) -> Any:
        """Parse FGDC data
        :param lines: lines
        :type lines: str
        :param group_indent: Defaults to 0.
        :type group_indent: int
        :returns: metadata
        :rtype: any
        """
        result = {}
        is_multiline_text = False
        result_text = None  # type: Optional[str]
        while len(lines) > 0:
            # Peek at the next line to see if we're done this group
            line = lines[0]
            # Replace stray carriage returns
            line = line.replace("^M", "")
            # Replace tabs with 4 spaces
            line = line.replace("\t", "    ")

            if not line.strip():
                lines.pop(0)
                continue

            m = re.search(line_pattern, line)
            if not m:
                raise Exception("Could not parses line:\n{}\n".format(line))

            this_indent = len(m.group(1))

            if this_indent < group_indent:
                break

            # Remove this line from the top of the stack and
            # process it.

            lines.pop(0)

            # If we're collecting multi-line text values,
            # just add the line to the result text.
            if is_multiline_text:
                prev_result = " {result_text}" if result_text is not None else ""
                result_text = f"{prev_result}{line.strip()}"
                continue

            this_key = m.group(2)
            key_flag = m.group(3) != "" and " " not in this_key
            this_value = m.group(4)

            if key_flag and this_value != "":
                result[this_key] = this_value.strip()
            else:
                if key_flag:
                    result[this_key] = _parse(lines, group_indent + 2)
                else:
                    is_multiline_text = True
                    result_text = line.strip()

        if is_multiline_text:
            return result_text
        else:
            return result

    return _parse(md_text.split("\n"), group_indent=0)["Metadata"]
