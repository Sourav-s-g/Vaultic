# 🔒 Secure Credential Management Setup

This document explains how to set up secure credential management for the Vaultic app.

## 📋 Overview

The app now uses a multi-layered approach to credential management:

1. **Build-time Configuration** (Most Secure)
2. **Environment Variables** (.env file)
3. **Secure Storage** (Runtime updates)

## 🚀 Quick Setup

### Step 1: Create .env File

Copy the example file and add your credentials:

```bash
cp env.example .env
```

Edit `.env` with your actual values:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# PDFShift API Key (optional)
PDFSHIFT_API_KEY=your-pdfshift-api-key-here

# App Configuration
APP_ENV=development
DEBUG_MODE=true
```

### Step 2: Get Your Supabase Credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** (looks like: `https://abcdefghijklmnop.supabase.co`)
   - **Anon/Public Key** (starts with `eyJ...`)

### Step 3: Run the App

```bash
flutter run
```

## 🔧 Advanced Configuration

### Build-Time Configuration (Production)

For production builds, use build-time environment variables:

```bash
flutter build apk --dart-define=ENVIRONMENT=production \
                  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
                  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
                  --dart-define=PDFSHIFT_API_KEY=your-pdfshift-key
```

### Different Environments

Create separate .env files for different environments:

- `.env.development` - Development
- `.env.staging` - Staging
- `.env.production` - Production

### CI/CD Integration

For automated builds, set environment variables in your CI/CD system:

```yaml
# GitHub Actions example
env:
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
  PDFSHIFT_API_KEY: ${{ secrets.PDFSHIFT_API_KEY }}
```

## 🛡️ Security Features

### ✅ What's Protected

- ✅ Credentials never committed to version control
- ✅ Multiple fallback mechanisms
- ✅ Secure storage for runtime updates
- ✅ Build-time configuration support
- ✅ Environment-specific configurations
- ✅ Graceful error handling

### 🔒 Security Layers

1. **Build-time**: Credentials compiled into binary (most secure)
2. **Environment**: Loaded from .env file (secure, not in repo)
3. **Secure Storage**: Encrypted device storage (for updates)

## 🚨 Troubleshooting

### "Supabase credentials not configured"

**Solution**: Create `.env` file with your credentials:

```bash
# Create .env file
echo "SUPABASE_URL=https://your-project.supabase.co" > .env
echo "SUPABASE_ANON_KEY=your-anon-key" >> .env
```

### "PDFShift API key not configured"

**Solution**: Add PDFShift key to `.env`:

```bash
echo "PDFSHIFT_API_KEY=your-pdfshift-key" >> .env
```

### App crashes on startup

**Solution**: Check credential format:

- Supabase URL should start with `https://`
- Anon key should start with `eyJ`
- No extra spaces or quotes in .env file

## 📱 Runtime Credential Updates

The app supports updating credentials at runtime:

```dart
// Update credentials securely
await CredentialService.storeCredentials(
  supabaseUrl: 'new-url',
  supabaseAnonKey: 'new-key',
);

// Clear all credentials
await CredentialService.clearCredentials();
```

## 🔍 Debug Information

Get environment info for debugging:

```dart
final info = await CredentialService.getEnvironmentInfo();
print('Environment: ${info['appName']}');
print('Has Supabase URL: ${info['hasSupabaseUrl']}');
print('Has Supabase Key: ${info['hasSupabaseKey']}');
```

## 📚 Best Practices

1. **Never commit .env files** to version control
2. **Use build-time config** for production
3. **Rotate credentials** regularly
4. **Use different credentials** for different environments
5. **Monitor credential usage** in your Supabase dashboard

## 🆘 Support

If you encounter issues:

1. Check the error message in the app
2. Verify your .env file format
3. Ensure credentials are valid in Supabase dashboard
4. Check network connectivity
5. Review the troubleshooting section above
