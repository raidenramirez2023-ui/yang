# Automated Deployment Setup for Hostinger

This guide will help you set up automated deployment from GitHub to Hostinger.

## Prerequisites

- GitHub repository for your project
- Hostinger hosting account with FTP access
- FTP credentials from Hostinger

## Step 1: Get Your FTP Credentials from Hostinger

1. Login to your Hostinger control panel (hpanel.hostinger.com)
2. Go to **Hosting** > **Manage**
3. Under **File Manager**, click **FTP Accounts**
4. Note down:
   - **FTP Host** (usually your domain or IP address)
   - **FTP Username** 
   - **FTP Password**

## Step 2: Set Up GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add these three secrets:

### Secret 1: FTP_HOST
- **Name**: `FTP_HOST`
- **Value**: Your FTP host (e.g., `yc-pagsanjan.site` or IP address)

### Secret 2: FTP_USERNAME  
- **Name**: `FTP_USERNAME`
- **Value**: Your FTP username

### Secret 3: FTP_PASSWORD
- **Name**: `FTP_PASSWORD`
- **Value**: Your FTP password

## Step 3: Enable GitHub Actions

1. In your repository, go to **Settings** > **Actions**
2. Under **Actions permissions**, select **Allow all actions and reusable workflows**
3. Save the settings

## Step 4: Test the Deployment

1. Commit and push any changes to your main branch:
   ```bash
   git add .
   git commit -m "Setup automated deployment"
   git push origin main
   ```

2. Go to **Actions** tab in your GitHub repository
3. You should see the workflow running
4. Wait for it to complete

## How It Works

- **Automatic Trigger**: Every push to `main` branch triggers deployment
- **Build Process**: Flutter web app is built automatically
- **FTP Upload**: Built files are uploaded to Hostinger via FTP
- **Live Update**: Your website updates automatically within minutes

## Troubleshooting

### FTP Connection Issues
- Verify FTP credentials are correct
- Check if FTP is enabled in Hostinger
- Try using the IP address instead of domain

### Build Failures
- Check Flutter version compatibility
- Ensure all dependencies are in `pubspec.yaml`
- Review error logs in Actions tab

### Deployment Issues
- Verify remote directory path (usually `public_html`)
- Check file permissions on Hostinger
- Ensure sufficient hosting space

## Manual Override

If automated deployment fails, you can always:
1. Use the manual `deploy.ps1` script
2. Upload files manually via Hostinger File Manager

## Security Notes

- Never commit FTP credentials to your repository
- GitHub Secrets are encrypted and secure
- Regularly rotate your FTP passwords
- Use strong, unique passwords

## Monitoring

- Check GitHub Actions tab for deployment status
- Monitor your website after deployment
- Set up email notifications for failed deployments

---

**Your automated deployment is now ready!** 
Every code push will automatically update your live website.
