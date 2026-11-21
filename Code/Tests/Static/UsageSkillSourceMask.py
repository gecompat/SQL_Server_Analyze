"""Mask only paired generated Usage Skill projections in legacy SQL oracles.

Executable SQL remains visible. Validator 1054 checks the projection contents.
"""
from __future__ import annotations

import re


_MARKER = re.compile(
    r"(?m)^[ \t]*-- (?P<kind>USAGE_SKILL(?:_HELP)?)_(?P<action>BEGIN|END) "
    r"(?P<name>[^\s\r\n]+)[^\r\n]*(?:\r?\n|$)"
)


def strip_usage_skill_projections(source: str) -> str:
    opened = None
    spans = []
    for marker in _MARKER.finditer(source):
        if marker.group("action") == "BEGIN":
            if opened is not None:
                raise ValueError("Nested Usage Skill projection markers")
            opened = marker
            continue
        if (opened is None or opened.group("kind") != marker.group("kind")
                or opened.group("name") != marker.group("name")):
            raise ValueError("Unpaired Usage Skill projection marker")
        spans.append((opened.start(), marker.end()))
        opened = None
    if opened is not None:
        raise ValueError("Incomplete Usage Skill projection")
    text = source
    for start, end in reversed(spans):
        text = text[:start] + ("".join(re.findall(r"\r?\n", text[start:end])) or "\n") + text[end:]
    return text
