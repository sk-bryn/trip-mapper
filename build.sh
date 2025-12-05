#!/bin/bash
#
# Build script for TripVisualizer
# Loads environment variables from .env and builds the Swift package
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
PROJECT_DIR="$SCRIPT_DIR/TripVisualizer"

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

# Export environment variables from .env
echo "Loading environment from .env..."
set -a
source "$ENV_FILE"
set +a

# Validate required variables are set
MISSING_VARS=()
[[ -z "$DD_API_KEY" ]] && MISSING_VARS+=("DD_API_KEY")
[[ -z "$DD_APP_KEY" ]] && MISSING_VARS+=("DD_APP_KEY")
[[ -z "$GOOGLE_MAPS_API_KEY" ]] && MISSING_VARS+=("GOOGLE_MAPS_API_KEY")

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    echo "Error: Missing required environment variables in .env:" >&2
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var" >&2
    done
    exit 1
fi

echo "Environment loaded successfully."
echo ""

# Build the project
echo "Building TripVisualizer..."
cd "$PROJECT_DIR"
swift build

echo ""
echo "Build complete!"
echo ""
echo "Run the tool with:"
echo "  $PROJECT_DIR/.build/debug/tripvisualizer <trip-uuid>"
echo ""
echo "Or use the run.sh script:"
echo "  ./run.sh <trip-uuid>"
