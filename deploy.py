#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from deployment import SAMBA_VERSION
from deployment.config import GIB, SambaConfig, recommended_time_machine_gib
from deployment.package import create_bundle


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Prepare Time Capsule Samba deployment assets")
    subparsers = parser.add_subparsers(dest="command", required=True)

    quota = subparsers.add_parser("quota", help="calculate the recommended Time Machine cap")
    quota.add_argument("--capacity-gib", type=int, required=True)
    quota.add_argument("--free-gib", type=int, required=True)

    render = subparsers.add_parser("render-config", help="render smb.conf")
    render.add_argument("--share-name", default="alex")
    render.add_argument("--share-path", default="/Volumes/dk2/ShareRoot/alex")
    render.add_argument("--smb-user", default="root")
    render.add_argument("--output", type=Path)

    package = subparsers.add_parser("package", help="package a validated cross-build")
    package.add_argument("--stage", type=Path, required=True)
    package.add_argument("--share-name", default="alex")
    package.add_argument("--share-path", default="/Volumes/dk2/ShareRoot/alex")
    package.add_argument("--smb-user", default="root")
    package.add_argument(
        "--output",
        type=Path,
        default=Path("dist") / f"timecapsule-samba-{SAMBA_VERSION}.tar.gz",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "quota":
        size = recommended_time_machine_gib(args.capacity_gib * GIB, args.free_gib * GIB)
        print(f"{size}G")
        return 0

    config = SambaConfig(args.share_name, args.share_path, args.smb_user)
    if args.command == "render-config":
        rendered = config.render()
        if args.output:
            args.output.write_text(rendered, encoding="utf-8")
        else:
            print(rendered, end="")
        return 0

    templates = Path(__file__).resolve().parent / "deployment" / "templates"
    bundle, checksum = create_bundle(args.stage, args.output, config, templates)
    print(bundle)
    print(checksum)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
