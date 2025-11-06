#!/bin/bash

# Vaultic App Setup Script
# This script helps you set up your Supabase credentials

echo "🔧 Vaultic App Setup"
echo "==================="
echo ""

# Check if .env file exists
if [ -f ".env" ]; then
    echo "✅ .env file already exists"
    echo ""
    echo "Current configuration:"
    grep -E "SUPABASE_URL|SUPABASE_ANON_KEY" .env | sed 's/=.*/=***hidden***/'
    echo ""
    read -p "Do you want to update your credentials? (y/n): " update
    if [ "$update" != "y" ]; then
        echo "Setup complete! Run 'flutter run' to start the app."
        exit 0
    fi
fi

echo "📋 Setting up Supabase credentials..."
echo ""
echo "You need to get your Supabase credentials from:"
echo "https://supabase.com/dashboard → Settings → API"
echo ""

# Get Supabase URL
read -p "Enter your Supabase URL (https://your-project-id.supabase.co): " supabase_url

# Validate URL format
if [[ ! $supabase_url =~ ^https://.*\.supabase\.co$ ]]; then
    echo "❌ Invalid URL format. Please use: https://your-project-id.supabase.co"
    exit 1
fi

# Get Supabase Anon Key
read -p "Enter your Supabase Anon Key (starts with eyJ...): " supabase_key

# Validate key format
if [[ ! $supabase_key =~ ^eyJ ]]; then
    echo "❌ Invalid key format. Supabase keys usually start with 'eyJ'"
    read -p "Continue anyway? (y/n): " continue_anyway
    if [ "$continue_anyway" != "y" ]; then
        exit 1
    fi
fi

# Optional PDFShift key
read -p "Enter PDFShift API Key (optional, press Enter to skip): " pdfshift_key

# Create .env file
echo "📝 Creating .env file..."

cat > .env << EOF
# Supabase Configuration
SUPABASE_URL=$supabase_url
SUPABASE_ANON_KEY=$supabase_key

# PDFShift API Key (optional)
PDFSHIFT_API_KEY=$pdfshift_key

# App Configuration
APP_ENV=development
DEBUG_MODE=true
EOF

echo ""
echo "✅ .env file created successfully!"
echo ""
echo "🔒 Security Note:"
echo "- The .env file is already in .gitignore"
echo "- Your credentials will never be committed to version control"
echo ""
echo "🚀 Next steps:"
echo "1. Run 'flutter run' to start the app"
echo "2. Your credentials are now securely configured"
echo ""
echo "📚 For more information, see CREDENTIAL_SETUP.md"
