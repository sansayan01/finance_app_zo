#!/bin/bash
# Bump app version in pubspec.yaml
# Usage: ./scripts/bump-version.sh [major|minor|patch]

BUMP_TYPE=${1:-patch}

# Read current version
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
VERSION_PART=$(echo "$CURRENT_VERSION" | cut -d+ -f1)
BUILD_PART=$(echo "$CURRENT_VERSION" | cut -d+ -f2)

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_PART"

case $BUMP_TYPE in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
  *)
    echo "Usage: ./scripts/bump-version.sh [major|minor|patch]"
    exit 1
    ;;
esac

NEW_BUILD=$((BUILD_PART + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$NEW_BUILD"

sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
echo "Bumped version: $CURRENT_VERSION -> $NEW_VERSION"
