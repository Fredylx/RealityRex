#!/usr/bin/env python3
"""Check an archived app's resolved AdMob IDs without printing their values."""
import argparse
import plistlib
import re
from pathlib import Path

GOOGLE_TEST_PUBLISHER = "3940256099942544"


def validate(info):
    errors = []
    publishers = []
    for key, separator in [("GADApplicationIdentifier", "~"), ("ADMOB_BANNER_UNIT_ID", "/")]:
        value = info.get(key)
        match = re.fullmatch(r"ca-app-pub-(\d{16})" + re.escape(separator) + r"\d{10}", value) if isinstance(value, str) else None
        if not match:
            errors.append(f"{key}: missing, unresolved or invalid production ID")
        elif match.group(1) == GOOGLE_TEST_PUBLISHER:
            errors.append(f"{key}: Google's public test publisher cannot be used for this production check")
        else:
            publishers.append(match.group(1))
    if len(set(publishers)) > 1:
        errors.append("App and banner IDs must belong to the same publisher")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("info_plist", type=Path, help="Resolved Info.plist inside the Release .app/.xcarchive")
    args = parser.parse_args()
    try:
        with args.info_plist.open("rb") as source:
            info = plistlib.load(source)
        if not isinstance(info, dict):
            raise ValueError("Expected a plist dictionary")
        errors = validate(info)
    except (OSError, ValueError, plistlib.InvalidFileException):
        print("FAIL: could not read a valid compiled Info.plist")
        return 2
    if errors:
        print("FAIL: production ad configuration is incomplete")
        for error in errors:
            print("- " + error)
        return 1
    print("PASS: production-format AdMob IDs resolved; this does not verify ownership, serving, consent, store metadata or device behavior")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
