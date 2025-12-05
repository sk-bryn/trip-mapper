#!/bin/bash
#
# Run script for TripVisualizer
# Loads environment variables from .env and runs the tool
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
PROJECT_DIR="$SCRIPT_DIR/TripVisualizer"
EXECUTABLE="$PROJECT_DIR/.build/debug/tripvisualizer"

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE" >&2
    echo "" >&2
    echo "Please create a .env file with the following variables:" >&2
    echo "  DD_API_KEY=your-datadog-api-key" >&2
    echo "  DD_APP_KEY=your-datadog-app-key" >&2
    echo "  GOOGLE_MAPS_API_KEY=your-google-maps-api-key" >&2
    exit 1
fi

# Check if executable exists
if [[ ! -f "$EXECUTABLE" ]]; then
    echo "Error: Executable not found at $EXECUTABLE" >&2
    echo "Please run ./build.sh first" >&2
    exit 1
fi

# Export environment variables from .env
set -a
source "$ENV_FILE"
set +a

# Run the tool with all passed arguments
exec "$EXECUTABLE" "$@"
