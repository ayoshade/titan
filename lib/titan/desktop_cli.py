#!/usr/bin/env python3
"""Argparse entrypoint; each operation family owns its implementation."""
import argparse
import subprocess
import sys
import tarfile
from pathlib import Path


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    # Preserve direct internal callers while this family moves to Shell.
    system_families = ('service', 'battery', 'network', 'bluetooth', 'power', 'audio')
    if argv and (argv[0] in system_families or
                 argv[0] in ('pkg', 'dev')):
        script = 'titan-system' if argv[0] in system_families else {'pkg': 'titan-packages', 'dev': 'titan-dev'}[argv[0]]
        return subprocess.call([str(Path(__file__).resolve().parents[2] / 'scripts' / script), *argv])
    import apps
    import configuration
    import utilities
    import media_tools
    import plugins
    from ops import register_hooks
    parser = argparse.ArgumentParser(prog='titan')
    sub = parser.add_subparsers(required=True)
    for module in (apps, configuration, utilities, media_tools, plugins):
        module.register(sub)
    # Keep the family discoverable in the shared parser's top-level help.
    sub.add_parser('pkg', help='Package search, full upgrades and reviewed optional bundles (Bash)')
    sub.add_parser('dev', help='Mise environments and local Docker databases (Bash)')
    for name in system_families[1:]:
        sub.add_parser(name, help='System status and explicit controls (Bash)')
    register_hooks(sub)
    args = parser.parse_args(argv)
    try:
        result = args.handler(args)
        return result if isinstance(result, int) else 0
    except (ValueError, OSError, UnicodeError, tarfile.TarError, subprocess.SubprocessError) as error:
        print(f'titan: {error}', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == '__main__':
    raise SystemExit(main())
