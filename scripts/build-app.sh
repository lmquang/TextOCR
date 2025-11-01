#!/bin/bash

# TextOCR - Build Standalone Application Script
# This script builds the app in Release mode and copies it to /Applications

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building TextOCR for standalone use...${NC}"

# Configuration
PROJECT_NAME="TextOCR"
SCHEME_NAME="TextOCR"
CONFIGURATION="Release"
BUILD_DIR="$(pwd)/build"
APP_NAME="${PROJECT_NAME}.app"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"

# Build the app
echo -e "${YELLOW}Building ${PROJECT_NAME} in ${CONFIGURATION} mode...${NC}"
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO

# Find the built app
BUILT_APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME" -type d | head -n 1)

if [ ! -d "$BUILT_APP_PATH" ]; then
    echo -e "${RED}Error: Built app not found at expected location${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful!${NC}"
echo -e "Built app location: ${BUILT_APP_PATH}"

# Ask user if they want to copy to /Applications
read -p "Do you want to copy ${APP_NAME} to /Applications? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if app already exists in /Applications
    if [ -d "/Applications/$APP_NAME" ]; then
        echo -e "${YELLOW}Removing existing app from /Applications...${NC}"
        rm -rf "/Applications/$APP_NAME"
    fi

    echo -e "${YELLOW}Copying ${APP_NAME} to /Applications...${NC}"
    cp -R "$BUILT_APP_PATH" /Applications/

    echo -e "${GREEN}✓ ${APP_NAME} has been installed to /Applications${NC}"
    echo -e "${GREEN}You can now launch it from Spotlight or Launchpad${NC}"
else
    echo -e "${YELLOW}App not copied to /Applications${NC}"
    echo -e "You can manually copy it from: ${BUILT_APP_PATH}"
fi

# Optional: Clean up build artifacts
read -p "Do you want to clean up build artifacts? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleaning build directory...${NC}"
    rm -rf "$BUILD_DIR"
    echo -e "${GREEN}✓ Build directory cleaned${NC}"
fi

echo -e "${GREEN}Done!${NC}"
