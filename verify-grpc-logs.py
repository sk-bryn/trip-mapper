#!/usr/bin/env python3
"""
Temporary script to verify that DataDog contains logs for the gRPC API calls
identified in grpc-enhancements-plan.md.

This searches for "handled request for <function_name>" logs in env:prod
and checks if the response bodies contain the expected location/address data.

Uses only standard library - no external dependencies required.
"""

import os
import json
import urllib.request
import urllib.error
import ssl
from datetime import datetime, timedelta
from pathlib import Path


def load_env():
    """Load environment variables from .env file."""
    env_path = Path(__file__).parent / ".env"
    env_vars = {}

    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()

    return env_vars


# Load environment variables
env_vars = load_env()
DD_API_KEY = env_vars.get('DD_API_KEY') or os.getenv('DD_API_KEY')
DD_APP_KEY = env_vars.get('DD_APP_KEY') or os.getenv('DD_APP_KEY')

if not DD_API_KEY or not DD_APP_KEY:
    print("ERROR: DD_API_KEY and DD_APP_KEY must be set in .env file")
    exit(1)

DD_API_URL = "https://api.datadoghq.com/api/v2/logs/events/search"

# API functions to verify from grpc-enhancements-plan.md
API_FUNCTIONS = [
    {
        "name": "GetDeliveryOrder",
        "expected_fields": ["coordinates", "address", "latitude", "longitude"],
        "description": "Single order lookup with address/coordinates"
    },
    {
        "name": "GetTripDetails",
        "expected_fields": ["orders", "coordinates", "address", "tripID"],
        "description": "All orders in a trip with addresses"
    },
    {
        "name": "GetRouteDetailsForTrip",
        "expected_fields": ["routeSegments", "planned", "actual"],
        "description": "Route waypoints (planned vs actual)"
    },
    {
        "name": "GetLocationsDetails",
        "expected_fields": ["locations", "locationNumber", "coordinates", "address"],
        "description": "Restaurant address/coordinates by location_number"
    },
    {
        "name": "GetDeliveryDriverByID",
        "expected_fields": ["driver", "coordinates", "driverStatus"],
        "description": "Driver current GPS location"
    }
]


def search_logs(function_name: str, limit: int = 5) -> dict:
    """
    Search DataDog for logs matching "handled request for <function_name>"
    in env:prod.
    """
    # Search last 7 days
    now = datetime.utcnow()
    from_time = now - timedelta(days=7)

    query = f'env:prod "handled request for {function_name}"'

    body = {
        "filter": {
            "query": query,
            "from": from_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "to": now.strftime("%Y-%m-%dT%H:%M:%SZ")
        },
        "sort": "-timestamp",
        "page": {
            "limit": limit
        }
    }

    headers = {
        "DD-API-KEY": DD_API_KEY,
        "DD-APPLICATION-KEY": DD_APP_KEY,
        "Content-Type": "application/json"
    }

    data = json.dumps(body).encode('utf-8')
    req = urllib.request.Request(DD_API_URL, data=data, headers=headers, method='POST')

    # Create SSL context
    ctx = ssl.create_default_context()

    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"  ERROR: HTTP {e.code}")
        error_body = e.read().decode('utf-8')[:500] if e.fp else ""
        print(f"  Response: {error_body}")
        return {"data": []}
    except urllib.error.URLError as e:
        print(f"  ERROR: {e.reason}")
        return {"data": []}


def check_fields_in_response(log_entry: dict, expected_fields: list) -> dict:
    """
    Check if expected fields exist anywhere in the log entry.
    Returns a dict with field -> found status.
    """
    # Convert log entry to string for simple field search
    log_str = json.dumps(log_entry).lower()

    results = {}
    for field in expected_fields:
        # Check if field name appears in the log (case-insensitive)
        results[field] = field.lower() in log_str

    return results


def extract_response_body(log_entry: dict) -> str:
    """
    Try to extract the response body or relevant content from log entry.
    """
    attrs = log_entry.get("attributes", {})

    # Try common paths where response data might be stored
    possible_paths = [
        attrs.get("attributes", {}).get("response_body"),
        attrs.get("attributes", {}).get("response"),
        attrs.get("attributes", {}).get("body"),
        attrs.get("message"),
        attrs.get("attributes", {})
    ]

    for path in possible_paths:
        if path and isinstance(path, (dict, str)):
            if isinstance(path, dict):
                return json.dumps(path, indent=2)[:2000]
            return str(path)[:2000]

    return json.dumps(attrs, indent=2)[:2000]


def main():
    print("=" * 70)
    print("DataDog Log Verification for gRPC API Functions")
    print("Searching env:prod for 'handled request for <function_name>'")
    print("=" * 70)
    print()

    results_summary = []

    for api in API_FUNCTIONS:
        func_name = api["name"]
        expected_fields = api["expected_fields"]
        description = api["description"]

        print(f"\n{'─' * 70}")
        print(f"FUNCTION: {func_name}")
        print(f"Purpose: {description}")
        print(f"Expected fields: {', '.join(expected_fields)}")
        print(f"{'─' * 70}")

        # Search for logs
        print(f"\nSearching DataDog...")
        response = search_logs(func_name, limit=3)

        logs = response.get("data", [])
        log_count = len(logs)

        if log_count == 0:
            print(f"  ❌ NO LOGS FOUND for '{func_name}'")
            results_summary.append({
                "function": func_name,
                "logs_found": 0,
                "fields_found": [],
                "status": "NO_LOGS"
            })
            continue

        print(f"  ✅ Found {log_count} log(s)")

        # Analyze the first log entry
        first_log = logs[0]
        field_results = check_fields_in_response(first_log, expected_fields)

        found_fields = [f for f, found in field_results.items() if found]
        missing_fields = [f for f, found in field_results.items() if not found]

        print(f"\n  Field Analysis (first log entry):")
        for field, found in field_results.items():
            status = "✅" if found else "❌"
            print(f"    {status} {field}")

        # Show sample response content
        print(f"\n  Sample log content (truncated):")
        sample = extract_response_body(first_log)
        # Indent the sample
        for line in sample.split('\n')[:30]:
            print(f"    {line}")
        if len(sample.split('\n')) > 30:
            print(f"    ... (truncated)")

        results_summary.append({
            "function": func_name,
            "logs_found": log_count,
            "fields_found": found_fields,
            "fields_missing": missing_fields,
            "status": "FOUND" if found_fields else "NO_EXPECTED_FIELDS"
        })

    # Print summary
    print("\n")
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print()
    print(f"{'Function':<30} {'Logs':<8} {'Fields Found':<30} {'Status'}")
    print("-" * 70)

    for result in results_summary:
        func = result["function"]
        logs = result["logs_found"]
        fields = ", ".join(result.get("fields_found", []))[:28] or "none"
        status = result["status"]

        status_icon = "✅" if status == "FOUND" else "❌"
        print(f"{func:<30} {logs:<8} {fields:<30} {status_icon} {status}")

    print()
    print("=" * 70)
    print("CONCLUSION")
    print("=" * 70)

    found_count = sum(1 for r in results_summary if r["status"] == "FOUND")
    total = len(results_summary)

    if found_count == total:
        print(f"✅ All {total} API functions have logs with expected data")
    elif found_count > 0:
        print(f"⚠️  {found_count}/{total} API functions have logs with expected data")
        print(f"   Missing: {', '.join(r['function'] for r in results_summary if r['status'] != 'FOUND')}")
    else:
        print(f"❌ No API functions found with expected data in logs")

    print()


if __name__ == "__main__":
    main()
