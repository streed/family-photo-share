#!/bin/bash
set -e

echo "Building Family Photo Share for TrueNAS deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Create build directory
BUILD_DIR="build"
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

echo -e "${YELLOW}Step 1: Building Docker image...${NC}"
docker build -t family_photo_share:latest .

echo -e "${YELLOW}Step 2: Saving Docker image...${NC}"
docker save family_photo_share:latest | gzip > $BUILD_DIR/family_photo_share_image.tar.gz

echo -e "${YELLOW}Step 3: Copying deployment files...${NC}"
cp docker-compose.production.yml $BUILD_DIR/
cp .env.production.example $BUILD_DIR/.env.example
cp TRUENAS_DEPLOYMENT.md $BUILD_DIR/
cp -r truenas-app $BUILD_DIR/

echo -e "${YELLOW}Step 4: Creating deployment package...${NC}"
cd $BUILD_DIR
tar -czf family_photo_share_truenas_deployment.tar.gz *
cd ..

echo -e "${GREEN}Build complete!${NC}"
echo -e "Deployment package: ${GREEN}$BUILD_DIR/family_photo_share_truenas_deployment.tar.gz${NC}"
echo ""
echo "To deploy on TrueNAS:"
echo "1. Extract the deployment package on your TrueNAS system"
echo "2. Load the Docker image: docker load < family_photo_share_image.tar.gz"
echo "3. Copy .env.example to .env.production and configure"
echo "4. Run: docker-compose -f docker-compose.production.yml --env-file .env.production up -d"
echo ""
echo "See TRUENAS_DEPLOYMENT.md for detailed instructions."