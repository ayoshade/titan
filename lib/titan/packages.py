"""Read-only catalog adapter for the remaining Python maintenance menu.

Package CLI execution and argument parsing live in packages.sh. Keep this
helper until menu generation migrates separately.
"""
from __future__ import annotations
from ops import read_json
from paths import ROOT


def catalog():
    return read_json(ROOT / 'default/catalog/packages.json')
