"""Small QEMU monitor client used by the disposable-VM tests."""
import json
import socket
import struct
import time


class Monitor:
    def __init__(self, path):
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.settimeout(10)
        self.socket.connect(str(path))
        self.stream = self.socket.makefile("rwb")
        json.loads(self.stream.readline())  # greeting
        self.command("qmp_capabilities")

    def command(self, name, **arguments):
        self.stream.write(json.dumps({"execute": name, "arguments": arguments}).encode() + b"\n")
        self.stream.flush()
        while True:
            reply = json.loads(self.stream.readline())
            if "error" in reply:
                raise RuntimeError(reply["error"])
            if "return" in reply:
                return reply["return"]

    def key(self, *keys):
        self.command("send-key", keys=[{"type": "qcode", "data": key} for key in keys], **{"hold-time": 80})
        time.sleep(.15)

    def type(self, text):
        for char in text:
            if char not in "abcdefghijklmnopqrstuvwxyz0123456789-":
                raise ValueError("VM typing supports lowercase letters, digits and hyphens only")
            self.key("minus" if char == "-" else char)

    def screenshot(self, path):
        self.command("screendump", filename=str(path), format="png")
        with open(path, "rb") as snapshot:
            snapshot.seek(16)
            return struct.unpack(">II", snapshot.read(8))

    def pixels(self, path):
        """Dump the guest framebuffer as PPM; return (width, height, RGB bytes)."""
        self.command("screendump", filename=str(path), format="ppm")
        data = open(path, "rb").read()
        fields, offset = [], 0
        while len(fields) < 4:  # P6, width, height, maxval
            while data[offset:offset + 1].isspace():
                offset += 1
            end = offset
            while not data[end:end + 1].isspace():
                end += 1
            fields.append(data[offset:end])
            offset = end
        width, height = int(fields[1]), int(fields[2])
        return width, height, data[offset + 1:offset + 1 + width * height * 3]

    def click(self, x, y, width=1024, height=768):
        self.command("input-send-event", events=[
            {"type": "abs", "data": {"axis": "x", "value": int(x * 32767 / width)}},
            {"type": "abs", "data": {"axis": "y", "value": int(y * 32767 / height)}},
            {"type": "btn", "data": {"down": True, "button": "left"}},
        ])
        self.command("input-send-event", events=[{"type": "btn", "data": {"down": False, "button": "left"}}])
        time.sleep(.3)  # let the toolkit apply focus/layout changes before typing
