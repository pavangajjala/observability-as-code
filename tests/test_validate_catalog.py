import copy
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import validate_catalog  # noqa: E402

VALID = {
    "defaults": {"envs": ["prod", "staging"]},
    "services": {
        "checkout-api": {
            "team": "payments",
            "tier": 1,
            "slo_target": 99.9,
            "notify": {"page": "@pagerduty-payments", "channel": "@slack-payments"},
            "runbook_url": "https://runbooks.example.com/checkout",
            "error_rate": {"warning": 1, "critical": 3},
        },
        "report-worker": {"team": "data", "tier": 3, "notify": {"channel": "@slack-data"}},
    },
}


def errors_after(mutate):
    catalog = copy.deepcopy(VALID)
    mutate(catalog)
    return validate_catalog.validate(catalog)


def test_valid_catalog_has_no_errors():
    assert validate_catalog.validate(VALID) == []


def test_repository_catalog_is_valid():
    catalog = yaml.safe_load(validate_catalog.DEFAULT_PATH.read_text())
    assert validate_catalog.validate(catalog) == []


@pytest.mark.parametrize("mutate, expected", [
    (lambda c: c["services"]["checkout-api"]["notify"].pop("page"), "need notify.page"),
    (lambda c: c["services"]["checkout-api"].pop("slo_target"), "need an slo_target"),
    (lambda c: c["services"]["checkout-api"].pop("runbook_url"), "need a runbook_url"),
    (lambda c: c["services"]["checkout-api"].update(tier=4), "tier must be 1, 2 or 3"),
    (lambda c: c["services"]["checkout-api"].update(slo_target=100), "below 100"),
    (lambda c: c["services"]["checkout-api"].update(slo_target=50), "at least 90"),
    (lambda c: c["services"]["checkout-api"].update(error_rate={"warning": 5, "critical": 3}), "must be lower than"),
    (lambda c: c["services"]["checkout-api"].update(error_rate={"critical": 250}), "cannot exceed 100"),
    (lambda c: c["services"]["checkout-api"].update(latency_p95_seconds={"critical": -1}), "positive number"),
    (lambda c: c["services"]["checkout-api"].update(runbook_url="http://wiki/checkout"), "https link"),
    (lambda c: c["services"]["checkout-api"]["notify"].update(channel="payments"), "starting with @"),
    (lambda c: c["services"]["report-worker"].pop("team"), "team is required"),
    (lambda c: c["services"]["report-worker"].pop("notify"), "notify.channel is required"),
    (lambda c: c["services"]["report-worker"].update(slo=99), "unknown key(s) slo"),
    (lambda c: c["services"]["report-worker"].update(envs=["staging"], slo_target=99), "no prod environment"),
    (lambda c: c["services"].update({"Bad_Name": {"team": "x", "tier": 3, "notify": {"channel": "@a"}}}), "lowercase"),
    (lambda c: c.pop("defaults"), "defaults.envs"),
    (lambda c: c.update(services={}), "non-empty mapping"),
])
def test_problems_are_reported(mutate, expected):
    errors = errors_after(mutate)
    assert any(expected in error for error in errors), errors


def test_every_problem_is_reported_not_just_the_first():
    def break_two_things(catalog):
        catalog["services"]["checkout-api"]["tier"] = 9
        catalog["services"]["report-worker"].pop("team")

    assert len(errors_after(break_two_things)) == 2


def test_cli_exit_codes(tmp_path, capsys):
    good = tmp_path / "good.yaml"
    good.write_text(yaml.safe_dump(VALID))
    assert validate_catalog.main([str(good)]) == 0

    bad = tmp_path / "bad.yaml"
    bad.write_text("services: {a-b: {tier: 2}}")
    assert validate_catalog.main([str(bad)]) == 1
    assert "team is required" in capsys.readouterr().err

    assert validate_catalog.main([str(tmp_path / "missing.yaml")]) == 2
