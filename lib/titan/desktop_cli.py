#!/usr/bin/env python3
"""Argparse entrypoint; each operation family owns its implementation."""
import argparse
import subprocess
import sys
import tarfile


def main(argv=None):
    import apps
    import configuration
    import development
    import packages
    import utilities
    import media_tools
    import system_status
    import plugins
    import services
    from ops import register_hooks
    parser = argparse.ArgumentParser(prog='titan')
    sub = parser.add_subparsers(required=True)
    for module in (apps, configuration, development, packages, utilities, media_tools, system_status, plugins, services):
        module.register(sub)
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
