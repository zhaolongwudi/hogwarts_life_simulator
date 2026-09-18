#!/bin/bash
set -e

PUB="pubspec.yaml"
CURRENT=$(grep '^version:' "$PUB" | awk '{print $2}')
BASE=$(echo "$CURRENT" | cut -d+ -f1)
BUILD=$(echo "$CURRENT" | cut -d+ -f2)

IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE"

if [ "$PATCH" -ge 9 ]; then
    PATCH=0
    MINOR=$((MINOR + 1))
else
    PATCH=$((PATCH + 1))
fi

if [ "$MINOR" -ge 10 ]; then
    MINOR=0
    MAJOR=$((MAJOR + 1))
fi

BUILD=$((BUILD + 1))
NEW="${MAJOR}.${MINOR}.${PATCH}+${BUILD}"

sed -i "s/^version: .*/version: $NEW/" "$PUB"

echo "Version bumped: $CURRENT -> $NEW"

if [ -n "$GITHUB_ENV" ]; then
    echo "VERSION_CODE=$BUILD" >> "$GITHUB_ENV"
    echo "VERSION_NAME=$NEW" >> "$GITHUB_ENV"
    echo "VERSION_NAME_DISPLAY=${MAJOR}.${MINOR}.${PATCH}" >> "$GITHUB_ENV"
else
    echo "VERSION_CODE=$BUILD"
    echo "VERSION_NAME=$NEW"
    echo "VERSION_NAME_DISPLAY=${MAJOR}.${MINOR}.${PATCH}"
fi