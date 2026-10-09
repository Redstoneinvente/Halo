#!/usr/bin/env python3
"""Validate Halo's source-linked feature inventory (static evidence, not runtime QA).

Run from any directory: python3 Scripts/check_feature_inventory.py
No dependencies, network calls, or macOS SDK required.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "Docs" / "FeatureInventory.json"
STATUSES = {"source_present", "conditional", "partial", "contract_only", "not_found"}


def validate():
    data = json.loads(INVENTORY.read_text(encoding="utf-8"))
    errors = []
    if data.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    features = data.get("features")
    if not isinstance(features, list) or not features:
        return ["features must be a non-empty list"]
    seen = set()
    for item in features:
        key = item.get("id", "")
        status = item.get("status")
        evidence = item.get("evidence", [])
        if not isinstance(key, str) or not key or key in seen:
            errors.append(f"Invalid/duplicate feature ID: {key!r}")
        seen.add(key)
        if status not in STATUSES:
            errors.append(f"{key}: invalid status {status!r}")
        if not isinstance(evidence, list):
            errors.append(f"{key}: evidence must be a list")
            continue
        if status != "not_found" and not evidence:
            errors.append(f"{key}: status requires source evidence")
        if status == "not_found" and evidence:
            errors.append(f"{key}: no-code-found item should not claim source evidence")
        for source in evidence:
            rel, marker = source.get("path"), source.get("contains")
            if not isinstance(rel, str) or not isinstance(marker, str) or not marker:
                errors.append(f"{key}: invalid source descriptor")
                continue
            candidate = (ROOT / rel).resolve()
            if not candidate.is_relative_to(ROOT):
                errors.append(f"{key}: path escapes repository: {rel}")
            elif not candidate.is_file():
                errors.append(f"{key}: source file missing: {rel}")
            elif marker not in candidate.read_text(encoding="utf-8"):
                errors.append(f"{key}: source marker missing in {rel}: {marker!r}")
    return errors


if __name__ == "__main__":
    try:
        failures = validate()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        failures = [f"Inventory cannot be validated: {exc}"]
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        sys.exit(1)
    print("HALO feature inventory OK: all source evidence markers still exist.")
