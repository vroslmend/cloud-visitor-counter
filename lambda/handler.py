"""
Visitor-counter Lambda for ammarhassan.dev.

One function behind an API Gateway HTTP API, backed by a single DynamoDB
table. Two counters live in the table as separate items keyed by `id`:

    { "id": "visits", "count": N }
    { "id": "prius",  "count": N }

Routes (HTTP API, payload format 2.0):
    GET  /counts            -> { "prius": N, "visits": N }
    POST /counts/{id}/hit   -> { "<id>": N }   (atomic +1, returns new value)

Increments use DynamoDB's atomic ADD so concurrent hits never race.
CORS is handled by API Gateway, not here.
"""

import json
import os

import boto3

TABLE_NAME = os.environ.get("TABLE_NAME", "portfolio-counter")
# Only these counters may be created/incremented — stops anyone from
# spraying arbitrary keys into the table via the public endpoint.
ALLOWED = ("prius", "visits")

_table = boto3.resource("dynamodb").Table(TABLE_NAME)


def _response(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _read(counter_id: str) -> int:
    # Strongly consistent so a read right after an increment can't return a
    # stale value from a replica that hasn't caught up yet. Without this, a
    # GET that races a just-committed hit can return the pre-increment count.
    item = _table.get_item(
        Key={"id": counter_id}, ConsistentRead=True
    ).get("Item")
    return int(item["count"]) if item and "count" in item else 0


def _increment(counter_id: str) -> int:
    result = _table.update_item(
        Key={"id": counter_id},
        UpdateExpression="ADD #c :one",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":one": 1},
        ReturnValues="UPDATED_NEW",
    )
    return int(result["Attributes"]["count"])


def handler(event, _context):
    http = event.get("requestContext", {}).get("http", {})
    method = http.get("method", "")
    path = event.get("rawPath", "")

    try:
        if method == "GET" and path == "/counts":
            return _response(200, {c: _read(c) for c in ALLOWED})

        if method == "POST" and path.startswith("/counts/") and path.endswith("/hit"):
            counter_id = path[len("/counts/") : -len("/hit")]
            if counter_id not in ALLOWED:
                return _response(400, {"error": "unknown counter"})
            return _response(200, {counter_id: _increment(counter_id)})

        return _response(404, {"error": "not found"})
    except Exception:  # noqa: BLE001 — never leak internals to the public endpoint
        return _response(500, {"error": "internal error"})
