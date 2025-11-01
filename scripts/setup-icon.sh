#!/bin/bash

# TextOCR - App Icon Setup Script
# Generates all required icon sizes from a single 1024x1024 source image

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Setting up app icon for TextOCR...${NC}"

# Paths
SOURCE_ICON="public/asset/icon.png"
APPICONSET="TextOCR/Assets.xcassets/AppIcon.appiconset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo -e "${RED}Error: Source icon not found at $SOURCE_ICON${NC}"
    exit 1
fi

# Check if sips is available (built-in macOS tool)
if ! command -v sips &> /dev/null; then
    echo -e "${RED}Error: sips command not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Source icon: $SOURCE_ICON${NC}"
echo -e "${YELLOW}Target: $APPICONSET${NC}"

# Create icon sizes
# macOS App Icon sizes: 16, 32, 128, 256, 512, 1024 (with 1x and 2x variants)

declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

echo -e "${YELLOW}Generating icon sizes...${NC}"

for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    output_path="$APPICONSET/$filename"

    echo "  Generating ${size}x${size} → $filename"
    sips -z "$size" "$size" "$SOURCE_ICON" --out "$output_path" > /dev/null 2>&1
done

# Update Contents.json with proper filenames
echo -e "${YELLOW}Updating Contents.json...${NC}"

cat > "$APPICONSET/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo -e "${GREEN}✓ Icon setup complete!${NC}"
echo -e "${GREEN}All icon sizes generated in $APPICONSET${NC}"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Build the app: ${GREEN}./scripts/build-app.sh${NC}"
echo -e "  2. Or open in Xcode: ${GREEN}open TextOCR.xcodeproj${NC}"
echo -e ""
echo -e "${GREEN}Your app will now use the new icon!${NC}"
