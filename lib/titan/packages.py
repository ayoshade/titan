"""Read-only recipe helpers for the remaining Python development/menu consumers.

Package CLI execution and argument parsing live in packages.sh. Keep these
helpers until developer provisioning and menu generation migrate separately.
"""
from __future__ import annotations
import re
from ops import read_json
from paths import ROOT


def catalog():
    return read_json(ROOT / 'default/catalog/packages.json')


def package_names(values):
    if not values or any(not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9@._+-]*', name) for name in values):
        raise ValueError('Supply valid package names, without options or paths')
    return values


def plan_install(names):
    return ['sudo', 'pacman', '-Syu', '--needed', '--', *package_names(names)]
