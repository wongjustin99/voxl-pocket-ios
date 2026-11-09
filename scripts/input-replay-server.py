#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["websockets>=15,<17"]
# ///
"""Loopback WebSocket fixture for native input replay; no desktop capture or injection."""

import argparse
import asyncio
import json
import os
import time
from pathlib import Path

from websockets.asyncio.server import serve


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=6922)
    parser.add_argument("--output", type=Path, required=True, help="Private JSONL input-event log")
    args = parser.parse_args()
    os.umask(0o077)

    async def handle(socket):
        await socket.send(json.dumps({"t": "hello", "w": 1920, "h": 1080, "stripes": [[0, 1080]]}))
        async for message in socket:
            if not isinstance(message, str):
                continue
            command = message.split(",", 1)[0]
            if command not in {"m", "b", "sp", "s", "k", "c", "r", "sz", "dp"}:
                continue
            event = command + ",[redacted]" if command in {"k", "c"} else message
            with args.output.open("a") as output:
                output.write(json.dumps({"time": time.monotonic(), "event": event}) + "\n")

    async def run():
        async with serve(handle, "127.0.0.1", args.port):
            print(f"Input fixture: ws://localhost:{args.port}/ws", flush=True)
            await asyncio.Future()

    asyncio.run(run())


if __name__ == "__main__":
    main()
