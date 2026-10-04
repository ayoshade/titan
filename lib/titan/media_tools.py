"""File-safe media conversion, QR decoding and clipboard file transfer."""
from __future__ import annotations
import os
from pathlib import Path
import tempfile

from ops import command_parser, emit, require, run
from paths import RUNTIME

SIZES = {'4k': 2160, '1080p': 1080, '720p': 720, 'high': 3160, 'medium': 2160, 'low': 1080}


def transcode(source, format='mp4', size='1080p', destination=None):
    require('ffmpeg')
    source = Path(source).expanduser().resolve(strict=True)
    if not source.is_file(): raise ValueError('Select a local media file')
    target = Path(destination).expanduser().absolute() if destination else source.with_name(source.stem + '-' + size + '.' + format)
    if target.exists() or target.is_symlink(): raise ValueError('Output already exists; preserving it')
    if target == source: raise ValueError('Output must differ from input')
    height = SIZES[size]
    argv = ['ffmpeg', '-nostdin', '-n', '-i', str(source)]
    if format == 'mp4':
        argv += ['-vf', f'scale=-2:trunc(min({height}\\,ih)/2)*2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '23', '-c:a', 'aac', '-movflags', '+faststart']
    elif format == 'gif':
        argv += ['-filter_complex', f'fps=10,scale=-2:min({height}\\,ih):flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse']
    else:
        argv += ['-vf', f'scale=min({height}\\,iw):-2', '-frames:v', '1']
        if format == 'jpg': argv += ['-q:v', '3']
    run(*argv, str(target))
    return target


def handle_transcode(args):
    file = transcode(args.source, args.format, args.size, args.output)
    if args.copy:
        require('wl-copy'); run('wl-copy', '--type', 'text/uri-list', input=(file.as_uri() + '\r\n').encode())
    print(file)


def handle_qr(args):
    if args.action == 'encode':
        require('qrencode')
        content = args.text if args.text is not None else __import__('sys').stdin.read(65537)
        if len(content.encode()) > 65536: raise ValueError('QR input exceeds 64 KiB')
        if args.output:
            file = Path(args.output).expanduser().absolute()
            if file.exists() or file.is_symlink(): raise ValueError('Output already exists')
            result = run('qrencode', '-o', '-', input=content.encode(), capture_output=True).stdout
            with file.open('xb') as stream: stream.write(result)
        else: run('qrencode', '-t', 'ANSIUTF8', input=content.encode())
        return
    require('zbarimg')
    if args.action == 'decode':
        file = Path(args.file).expanduser().resolve(strict=True)
        if not file.is_file(): raise ValueError('Select a local image')
        run('zbarimg', '--quiet', '--raw', file); return
    # Capture uses the existing live picker, preserving its keyboard behavior.
    from workflow import pick
    selected = pick()
    if not selected: return 1
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, path = tempfile.mkstemp(suffix='.png', dir=RUNTIME)
    os.close(fd)
    try:
        run('grim', '-g', selected, path)
        decoded = run('zbarimg', '--quiet', '--raw', path, capture_output=True).stdout
        run('wl-copy', input=decoded)
        # Contents can be credentials. Only place them on the clipboard.
        print('QR content copied to clipboard')
    finally: Path(path).unlink(missing_ok=True)


def handle_clipboard(args):
    file = Path(args.file).expanduser().resolve(strict=True)
    if not file.is_file(): raise ValueError('Select a local file')
    require('wl-copy')
    if args.action == 'file':
        run('wl-copy', '--type', 'text/uri-list', input=(file.as_uri() + '\r\n').encode())
    else:
        if file.stat().st_size > 1048576: raise ValueError('Clipboard text is limited to 1 MiB')
        run('wl-copy', '--type', 'text/plain', input=file.read_bytes())


def register(sub):
    parser = command_parser(sub, 'transcode', 'Convert images and video while preserving source and existing outputs')
    parser.add_argument('source'); parser.add_argument('--format', choices=('mp4', 'gif', 'jpg', 'png'), default='mp4')
    parser.add_argument('--size', choices=SIZES, default='1080p'); parser.add_argument('--output'); parser.add_argument('--copy', action='store_true')
    parser.set_defaults(handler=handle_transcode)
    parser = command_parser(sub, 'qr', 'Encode QR codes or decode a file or screen selection')
    actions = parser.add_subparsers(dest='action', required=True)
    item = actions.add_parser('encode'); item.add_argument('text', nargs='?'); item.add_argument('--output')
    item = actions.add_parser('decode'); item.add_argument('file')
    actions.add_parser('capture')
    parser.set_defaults(handler=handle_qr)
    parser = command_parser(sub, 'clipboard', 'Copy a local file URI or its text contents')
    parser.add_argument('action', choices=('file', 'text-file')); parser.add_argument('file')
    parser.set_defaults(handler=handle_clipboard)
