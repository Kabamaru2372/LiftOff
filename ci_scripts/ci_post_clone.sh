#!/bin/sh
set -e

echo "Resolving Swift Package Manager dependencies..."
xcodebuild -resolvePackageDependencies \
  -project "${CI_PRIMARY_REPOSITORY_PATH}/LiftOff.xcodeproj" \
  -scheme UnPluq \
  -clonedSourcePackagesDirPath "${CI_PRIMARY_REPOSITORY_PATH}/.spm-packages"

echo "Package resolution complete."
