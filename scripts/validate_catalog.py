#!/usr/bin/env python3
"""Validate catalog/services.yaml before Terraform ever sees it.

Terraform would catch some of these mistakes, but only at plan time and with
an error that points into a module. This gives the person editing the catalog
a direct message about their own entry.

    python scripts/validate_catalog.py [path/to/services.yaml]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

DEFAULT_PATH = Path(__file__).resolve().parent.parent / "catalog" / "services.yaml"
NAME = re.compile(r"^[a-z][a-z0-9-]{1,48}[a-z0-9]$")
HANDLE = re.compile(r"^@[A-Za-z0-9_.@-]+$")
KNOWN_KEYS = {
    "team", "tier", "envs", "slo_target", "notify", "runbook_url",
    "error_rate", "latency_p95_seconds", "operation",
}


def _check_thresholds(name: str, key: str, value, errors: list[str]) -> None:
    if value is None:
        return
    if not isinstance(value, dict) or set(value) - {"warning", "critical"}:
        errors.append(f"{name}: {key} must be a mapping with warning and/or critical")
        return
    for level, number in value.items():
        if not isinstance(number, (int, float)) or isinstance(number, bool) or number <= 0:
            errors.append(f"{name}: {key}.{level} must be a positive number")
            return
    if "warning" in value and "critical" in value and value["warning"] >= value["critical"]:
        errors.append(f"{name}: {key}.warning must be lower than {key}.critical")


def validate(catalog) -> list[str]:
    """Return a list of human-readable problems; empty means the catalog is valid."""
    errors: list[str] = []
    if not isinstance(catalog, dict):
        return ["catalog must be a mapping with 'defaults' and 'services'"]

    default_envs = (catalog.get("defaults") or {}).get("envs")
    if not isinstance(default_envs, list) or not default_envs:
        errors.append("defaults.envs must be a non-empty list")
        default_envs = []

    services = catalog.get("services")
    if not isinstance(services, dict) or not services:
        return errors + ["services must be a non-empty mapping"]

    for name, svc in services.items():
        if not NAME.match(str(name)):
            errors.append(f"{name}: service names are lowercase letters, digits and dashes")
        if not isinstance(svc, dict):
            errors.append(f"{name}: must be a mapping")
            continue

        unknown = set(svc) - KNOWN_KEYS
        if unknown:
            errors.append(f"{name}: unknown key(s) {', '.join(sorted(unknown))}")

        if not svc.get("team"):
            errors.append(f"{name}: team is required")

        tier = svc.get("tier")
        if tier not in (1, 2, 3):
            errors.append(f"{name}: tier must be 1, 2 or 3")

        envs = svc.get("envs", default_envs)
        if not isinstance(envs, list) or not envs:
            errors.append(f"{name}: envs must be a non-empty list")
            envs = []

        notify = svc.get("notify") or {}
        channel = notify.get("channel")
        page = notify.get("page")
        if not channel:
            errors.append(f"{name}: notify.channel is required")
        for label, handle in (("channel", channel), ("page", page)):
            if handle and not HANDLE.match(str(handle)):
                errors.append(f"{name}: notify.{label} must be a Datadog handle starting with @")

        slo_target = svc.get("slo_target")
        if slo_target is not None:
            if not isinstance(slo_target, (int, float)) or not 90 <= slo_target < 100:
                errors.append(f"{name}: slo_target must be at least 90 and below 100")
            if "prod" not in envs:
                errors.append(f"{name}: slo_target is set but the service has no prod environment")

        if tier == 1:
            if not page:
                errors.append(f"{name}: tier 1 services need notify.page so alerts reach on-call")
            if slo_target is None:
                errors.append(f"{name}: tier 1 services need an slo_target")
            if not svc.get("runbook_url"):
                errors.append(f"{name}: tier 1 services need a runbook_url")

        runbook = svc.get("runbook_url")
        if runbook and not str(runbook).startswith("https://"):
            errors.append(f"{name}: runbook_url must be an https link")

        _check_thresholds(name, "error_rate", svc.get("error_rate"), errors)
        _check_thresholds(name, "latency_p95_seconds", svc.get("latency_p95_seconds"), errors)
        error_rate = svc.get("error_rate")
        if isinstance(error_rate, dict):
            for level, number in error_rate.items():
                if isinstance(number, (int, float)) and number > 100:
                    errors.append(f"{name}: error_rate.{level} is a percentage and cannot exceed 100")

    return errors


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    path = Path(argv[0]) if argv else DEFAULT_PATH
    try:
        catalog = yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as exc:
        print(f"error: cannot read {path}: {exc}", file=sys.stderr)
        return 2
    errors = validate(catalog)
    if errors:
        print(f"{path}: {len(errors)} problem(s)", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(f"{path}: {len(catalog['services'])} services, all valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
