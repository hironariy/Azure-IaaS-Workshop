# =============================================================================
# Self-Signed SSL Certificate Generator for Azure Application Gateway (PowerShell)
# =============================================================================
# Purpose: Generate a self-signed certificate in PFX format for workshop use
# Reference: /design/AzureArchitectureDesign.md - Application Gateway Configuration
#
# Output Files:
#   - cert.pfx        : PKCS#12 format for Application Gateway
#   - cert-base64.txt : Base64-encoded PFX for Bicep sslCertificateData parameter
#
# Usage:
#   .\scripts\generate-ssl-cert.ps1
#   # Then copy contents of cert-base64.txt to main.bicepparam sslCertificateData
#
# Note: Browser will show certificate warning (expected for self-signed certs)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Common Name (CN) for the certificate")]
    [string]$CertCN = "blogapp.cloudapp.azure.com",

    [Parameter(HelpMessage = "Organization name")]
    [string]$CertOrg = "Workshop",

    [Parameter(HelpMessage = "Country code")]
    [string]$CertCountry = "JP",

    [Parameter(HelpMessage = "Certificate validity in days")]
    [int]$CertDays = 365,

    [Parameter(HelpMessage = "Password for the PFX certificate")]
    [string]$CertPassword = "Workshop2024!",

    [Parameter(HelpMessage = "Output directory for certificate files")]
    [string]$OutputDir = "."
)

# =============================================================================
# Functions
# =============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-OpenSSL {
    try {
        $null = & openssl version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# =============================================================================
# Main Script
# =============================================================================

Write-ColorOutput "==============================================================================" "Green"
Write-ColorOutput "Self-Signed SSL Certificate Generator for Azure Application Gateway" "Green"
Write-ColorOutput "==============================================================================" "Green"
Write-Host ""

# Check for OpenSSL or use PowerShell native method
$useOpenSSL = Test-OpenSSL

Write-ColorOutput "Certificate Configuration:" "Yellow"
Write-Host "  Common Name (CN): $CertCN"
Write-Host "  Organization:     $CertOrg"
Write-Host "  Country:          $CertCountry"
Write-Host "  Validity:         $CertDays days"
Write-Host "  Password:         $CertPassword"
Write-Host "  Output Directory: $OutputDir"
Write-Host "  Method:           $(if ($useOpenSSL) { 'OpenSSL' } else { 'PowerShell (New-SelfSignedCertificate)' })"
Write-Host ""

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$pfxPath = Join-Path $OutputDir "cert.pfx"
$base64Path = Join-Path $OutputDir "cert-base64.txt"

try {
    if ($useOpenSSL) {
        # =============================================================================
        # Method 1: OpenSSL (if available)
        # =============================================================================
        Write-ColorOutput "Step 1: Generating certificate using OpenSSL..." "Green"
        
        $keyPath = Join-Path $OutputDir "cert.key"
        $crtPath = Join-Path $OutputDir "cert.crt"
        
        # Generate private key and certificate
        $opensslArgs = @(
            "req", "-x509", "-nodes",
            "-days", $CertDays,
            "-newkey", "rsa:2048",
            "-keyout", $keyPath,
            "-out", $crtPath,
            "-subj", "/CN=$CertCN/O=$CertOrg/C=$CertCountry"
        )
        
        $process = Start-Process -FilePath "openssl" -ArgumentList $opensslArgs -Wait -PassThru -NoNewWindow -RedirectStandardError "NUL"
        if ($process.ExitCode -ne 0) {
            throw "Failed to generate certificate with OpenSSL"
        }
        Write-Host "  ✅ Generated cert.key and cert.crt"
        
        # Convert to PFX format
        Write-ColorOutput "Step 2: Converting to PFX format..." "Green"
        $opensslPfxArgs = @(
            "pkcs12", "-export",
            "-out", $pfxPath,
            "-inkey", $keyPath,
            "-in", $crtPath,
            "-password", "pass:$CertPassword"
        )
        
        $process = Start-Process -FilePath "openssl" -ArgumentList $opensslPfxArgs -Wait -PassThru -NoNewWindow -RedirectStandardError "NUL"
        if ($process.ExitCode -ne 0) {
            throw "Failed to convert to PFX format"
        }
        Write-Host "  ✅ Generated cert.pfx"
    }
    else {
        # =============================================================================
        # Method 2: PowerShell Native (Windows only, no OpenSSL required)
        # =============================================================================
        Write-ColorOutput "Step 1: Generating certificate using PowerShell..." "Green"
        
        # Create self-signed certificate
        $cert = New-SelfSignedCertificate `
            -Subject "CN=$CertCN, O=$CertOrg, C=$CertCountry" `
            -DnsName $CertCN `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -NotBefore (Get-Date) `
            -NotAfter (Get-Date).AddDays($CertDays) `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -KeyExportPolicy Exportable `
            -KeyUsage DigitalSignature, KeyEncipherment `
            -Type SSLServerAuthentication
        
        Write-Host "  ✅ Generated certificate in Windows certificate store"
        Write-Host "  Thumbprint: $($cert.Thumbprint)"
        
        # Export to PFX
        Write-ColorOutput "Step 2: Exporting to PFX format..." "Green"
        $securePassword = ConvertTo-SecureString -String $CertPassword -Force -AsPlainText
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
        Write-Host "  ✅ Generated cert.pfx"
        
        # Clean up certificate from store (optional - keeps store clean)
        Write-ColorOutput "Step 2b: Cleaning up certificate store..." "Green"
        Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
        Write-Host "  ✅ Removed certificate from store (exported to file)"
    }
    
    # Base64 encode for Bicep parameter
    Write-ColorOutput "Step 3: Creating base64-encoded PFX for Bicep..." "Green"
    $pfxBytes = [System.IO.File]::ReadAllBytes($pfxPath)
    $base64String = [System.Convert]::ToBase64String($pfxBytes)
    [System.IO.File]::WriteAllText($base64Path, $base64String)
    Write-Host "  ✅ Generated cert-base64.txt"
    
    # Show file sizes for verification
    Write-Host ""
    Write-ColorOutput "Generated files:" "Green"
    
    if ($useOpenSSL) {
        $keyFile = Get-Item (Join-Path $OutputDir "cert.key")
        $crtFile = Get-Item (Join-Path $OutputDir "cert.crt")
        Write-Host "  $($keyFile.Length.ToString('N0').PadLeft(8)) bytes  cert.key"
        Write-Host "  $($crtFile.Length.ToString('N0').PadLeft(8)) bytes  cert.crt"
    }
    
    $pfxFile = Get-Item $pfxPath
    $base64File = Get-Item $base64Path
    Write-Host "  $($pfxFile.Length.ToString('N0').PadLeft(8)) bytes  cert.pfx"
    Write-Host "  $($base64File.Length.ToString('N0').PadLeft(8)) bytes  cert-base64.txt"
    
    Write-Host ""
    Write-ColorOutput "==============================================================================" "Green"
    Write-ColorOutput "Certificate generation complete!" "Green"
    Write-ColorOutput "==============================================================================" "Green"
    Write-Host ""
    Write-ColorOutput "Next steps:" "Yellow"
    Write-Host "1. Copy the contents of cert-base64.txt to main.bicepparam:"
    Write-Host "   param sslCertificateData = '<paste contents here>'"
    Write-Host ""
    Write-Host "2. Ensure the password matches:"
    Write-Host "   param sslCertificatePassword = '$CertPassword'"
    Write-Host ""
    Write-Host "3. Set a unique DNS label:"
    Write-Host "   param appGatewayDnsLabel = 'blogapp-<unique-suffix>'"
    Write-Host ""
    Write-ColorOutput "Note:" "Yellow"
    Write-Host "Self-signed certificates will cause browser warnings."
    Write-Host "This is expected for workshop purposes. Students should click 'Proceed' or"
    Write-Host "'Continue to site' when prompted by the browser."
    Write-Host ""
    
    # Security warning
    Write-ColorOutput "SECURITY WARNING:" "Red"
    Write-Host "Do NOT commit these certificate files to git!"
    Write-Host "The following patterns should be in .gitignore:"
    Write-Host "  cert.key"
    Write-Host "  cert.crt"
    Write-Host "  cert.pfx"
    Write-Host "  cert-base64.txt"
    Write-Host ""
    
    # Quick copy helper
    Write-ColorOutput "Quick copy (PowerShell):" "Cyan"
    Write-Host "  Get-Content cert-base64.txt | Set-Clipboard"
    Write-Host ""
}
catch {
    Write-ColorOutput "Error: $_" "Red"
    exit 1
}
