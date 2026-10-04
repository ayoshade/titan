"""Read-only catalog adapter for the existing Python maintenance menu.

All developer CLI parsing, provisioning and database operations live in
development.sh. Keep this helper until menu generation migrates separately.
"""
from ops import read_json
from paths import ROOT


def recipes():
    return read_json(ROOT / 'default/catalog/development.json')
