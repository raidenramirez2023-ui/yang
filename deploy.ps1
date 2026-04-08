# Hostinger Deployment Script for Yang Chow Restaurant
# Domain: yc-pagsanjan.site

Write-Host "Starting deployment for yc-pagsanjan.site..." -ForegroundColor Green

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build for production
Write-Host "Building Flutter web app for production..." -ForegroundColor Yellow
flutter build web --release --web-renderer canvaskit --base-href=/

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow
Set-Location build\web
Compress-Archive -Path * -DestinationPath ..\..\yang-chow-deploy.zip -Force
Set-Location ..\..

Write-Host "Deployment package created: yang-chow-deploy.zip" -ForegroundColor Green
Write-Host "Upload this file to your Hostinger hosting account" -ForegroundColor Cyan
Write-Host "Extract to the public_html directory for yc-pagsanjan.site" -ForegroundColor Cyan

# Display build info
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Build location: build\web\" -ForegroundColor Cyan
Write-Host "Deployment file: yang-chow-deploy.zip" -ForegroundColor Cyan
Write-Host "Domain: yc-pagsanjan.site" -ForegroundColor Cyan

Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
