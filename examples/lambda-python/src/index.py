"""
Lambda handler for the example-python-api.

Returns the request path, HTTP method, and a UTC timestamp so that you can
quickly verify end-to-end connectivity after deploying the example.
"""

import json
import datetime


def handler(event: dict, context) -> dict:
    """
    AWS Lambda entry point.

    The API Gateway HTTP API v2 payload format version 2.0 populates:
      - event["requestContext"]["http"]["method"]
      - event["requestContext"]["http"]["path"]

    This handler is intentionally minimal — extend it for your own use case.
    """
    http = event.get("requestContext", {}).get("http", {})
    path = http.get("path", "/")
    method = http.get("method", "UNKNOWN")
    timestamp = datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z"

    body = {
        "message": "Hello from devops-platform example-python-api",
        "path": path,
        "method": method,
        "timestamp": timestamp,
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }
