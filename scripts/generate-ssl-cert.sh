#!/bin/bash
# =============================================================================
# Self-Signed SSL Certificate Generator for Azure Application Gateway
# =============================================================================
# Purpose: Generate a self-signed certificate in PFX format for workshop use
# Reference: /design/AzureArchitectureDesign.md - Application Gateway Configuration
#
# Output Files:
#   - cert.key        : Private key (RSA 2048-bit)
#   - cert.crt        : Self-signed certificate (valid 365 days)
#   - cert.pfx        : PKCS#12 format for Application Gateway
#   - cert-base64.txt : Base64-encoded PFX for Bicep sslCertificateData parameter
#
# Usage:
#   ./scripts/generate-ssl-cert.sh
#   # Then copy contents of cert-base64.txt to main.bicepparam sslCertificateData
#
# Note: Browser will show certificate warning (expected for self-signed certs)
# =============================================================================

set -e

# Certificate configuration
CERT_CN="${1:-blogapp.cloudapp.azure.com}"
CERT_ORG="${2:-Workshop}"
CERT_COUNTRY="${3:-JP}"
CERT_DAYS=365
CERT_PASSWORD="Workshop2024!"

# Output directory (same as script location or current directory)
OUTPUT_DIR="${4:-.}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}Self-Signed SSL Certificate Generator for Azure Application Gateway${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Check for OpenSSL
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: OpenSSL is not installed. Please install OpenSSL first.${NC}"
    echo "  macOS:   brew install openssl"
    echo "  Ubuntu:  sudo apt-get install openssl"
    exit 1
fi

echo -e "${YELLOW}Certificate Configuration:${NC}"
echo "  Common Name (CN): $CERT_CN"
echo "  Organization:     $CERT_ORG"
echo "  Country:          $CERT_COUNTRY"
echo "  Validity:         $CERT_DAYS days"
echo "  Password:         $CERT_PASSWORD"
echo "  Output Directory: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Generate private key and self-signed certificate
echo -e "${GREEN}Step 1: Generating private key and certificate...${NC}"
openssl req -x509 -nodes -days "$CERT_DAYS" -newkey rsa:2048 \
    -keyout "$OUTPUT_DIR/cert.key" \
    -out "$OUTPUT_DIR/cert.crt" \
    -subj "/CN=$CERT_CN/O=$CERT_ORG/C=$CERT_COUNTRY" \
    2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate certificate${NC}"
    exit 1
fi
echo "  ✅ Generated cert.key and cert.crt"

# Convert to PFX format (required for Application Gateway)
echo -e "${GREEN}Step 2: Converting to PFX format...${NC}"
openssl pkcs12 -export \
    -out "$OUTPUT_DIR/cert.pfx" \
    -inkey "$OUTPUT_DIR/cert.key" \
    -in "$OUTPUT_DIR/cert.crt" \
    -password "pass:$CERT_PASSWORD" \
    2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to convert to PFX format${NC}"
    exit 1
fi
echo "  ✅ Generated cert.pfx"

# Base64 encode for Bicep parameter
echo -e "${GREEN}Step 3: Creating base64-encoded PFX for Bicep...${NC}"

# macOS and Linux have different base64 syntax
if [[ "$OSTYPE" == "darwin"* ]]; then
    base64 -i "$OUTPUT_DIR/cert.pfx" | tr -d '\n' > "$OUTPUT_DIR/cert-base64.txt"
else
    base64 -w 0 "$OUTPUT_DIR/cert.pfx" > "$OUTPUT_DIR/cert-base64.txt"
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to base64 encode${NC}"
    exit 1
fi
echo "  ✅ Generated cert-base64.txt"

# Show file sizes for verification
echo ""
echo -e "${GREEN}Generated files:${NC}"
echo "  $(ls -lh "$OUTPUT_DIR/cert.key" | awk '{print $5, $9}')"
echo "  $(ls -lh "$OUTPUT_DIR/cert.crt" | awk '{print $5, $9}')"
echo "  $(ls -lh "$OUTPUT_DIR/cert.pfx" | awk '{print $5, $9}')"
echo "  $(ls -lh "$OUTPUT_DIR/cert-base64.txt" | awk '{print $5, $9}')"

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}Certificate generation complete!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy the contents of cert-base64.txt to main.bicepparam:"
echo "   param sslCertificateData = '<paste contents here>'"
echo ""
echo "2. Ensure the password matches:"
echo "   param sslCertificatePassword = '$CERT_PASSWORD'"
echo ""
echo "3. Set a unique DNS label:"
echo "   param appGatewayDnsLabel = 'blogapp-\$(openssl rand -hex 4)'"
echo ""
echo -e "${YELLOW}Note:${NC} Self-signed certificates will cause browser warnings."
echo "This is expected for workshop purposes. Students should click 'Proceed' or"
echo "'Continue to site' when prompted by the browser."
echo ""

# Security warning
echo -e "${RED}SECURITY WARNING:${NC}"
echo "Do NOT commit these certificate files to git!"
echo "The following patterns are recommended for .gitignore:"
echo "  cert.key"
echo "  cert.crt"
echo "  cert.pfx"
echo "  cert-base64.txt"
echo ""
