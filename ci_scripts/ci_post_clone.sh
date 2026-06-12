#!/bin/sh
set -e

RESOLVED_DIR="${CI_PRIMARY_REPOSITORY_PATH}/LiftOff.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
RESOLVED_FILE="${RESOLVED_DIR}/Package.resolved"

echo "=== Xcode Cloud SPM Setup ==="
echo "Repository path: ${CI_PRIMARY_REPOSITORY_PATH}"
echo "Resolved file path: ${RESOLVED_FILE}"

# Ensure directory exists
mkdir -p "${RESOLVED_DIR}"

# Write Package.resolved explicitly so Xcode Cloud always finds it
cat > "${RESOLVED_FILE}" << 'EOF'
{
  "pins" : [
    {
      "identity" : "lottie-ios",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/airbnb/lottie-ios.git",
      "state" : {
        "revision" : "0cb03fd7564d27345bcd96144b811e56212949c6",
        "version" : "4.6.0"
      }
    }
  ],
  "version" : 2
}
EOF

echo "Package.resolved written successfully:"
cat "${RESOLVED_FILE}"
echo "=== Done ==="
