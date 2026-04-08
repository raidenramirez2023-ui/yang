#!/bin/bash

# Hostinger Deployment Script for Yang Chow Restaurant
# Domain: yc-pagsanjan.site

echo "Starting deployment for yc-pagsanjan.site..."

# Clean previous build
echo "Cleaning previous build..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build for production
echo "Building Flutter web app for production..."
flutter build web --release --web-renderer=canvaskit --base-href=/

# Create deployment package
echo "Creating deployment package..."
cd build/web
tar -czf ../../yang-chow-deploy.tar.gz *
cd ../..

echo "Deployment package created: yang-chow-deploy.tar.gz"
echo "Upload this file to your Hostinger hosting account"
echo "Extract to the public_html directory for yc-pagsanjan.site"

# Display build info
echo "Build completed successfully!"
echo "Build location: build/web/"
echo "Deployment file: yang-chow-deploy.tar.gz"
echo "Domain: yc-pagsanjan.site"
