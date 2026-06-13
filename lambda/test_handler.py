"""Unit tests for the visitor-counter Lambda, with DynamoDB mocked by moto."""

import importlib
import json

import boto3
import pytest
from moto import mock_aws

TABLE = "portfolio-counter-test"


@pytest.fixture
def handler(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("TABLE_NAME", TABLE)
    with mock_aws():
        boto3.resource("dynamodb").create_table(
            TableName=TABLE,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        # import (or reload) the module while the mock + env are active so its
        # module-level boto3 resource binds to the mocked table
        import handler as module

        importlib.reload(module)
        yield module


def event(method: str, path: str) -> dict:
    return {"requestContext": {"http": {"method": method}}, "rawPath": path}


def body(resp: dict) -> dict:
    return json.loads(resp["body"])


def test_counts_start_at_zero(handler):
    resp = handler.handler(event("GET", "/counts"), None)
    assert resp["statusCode"] == 200
    assert body(resp) == {"prius": 0, "visits": 0}


def test_increment_is_atomic_and_persists(handler):
    assert body(handler.handler(event("POST", "/counts/visits/hit"), None))["visits"] == 1
    assert body(handler.handler(event("POST", "/counts/visits/hit"), None))["visits"] == 2
    # prius counter is independent
    assert body(handler.handler(event("POST", "/counts/prius/hit"), None))["prius"] == 1
    counts = body(handler.handler(event("GET", "/counts"), None))
    assert counts == {"prius": 1, "visits": 2}


def test_unknown_counter_rejected(handler):
    resp = handler.handler(event("POST", "/counts/hacker/hit"), None)
    assert resp["statusCode"] == 400


def test_unknown_route_is_404(handler):
    assert handler.handler(event("GET", "/"), None)["statusCode"] == 404
