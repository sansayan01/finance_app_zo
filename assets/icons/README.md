# Preset Icon Assets

This directory contains preview images for the icon preset picker UI.
The actual launcher icons are stored in the platform-specific directories.

## Required Files

| File | Description |
|------|-------------|
| `preset_default.png` | Default MicroFlow Pro icon (indigo) |
| `preset_bank_blue.png` | Bank Blue theme icon |
| `preset_savings_green.png` | Savings Green theme icon |
| `preset_micro_orange.png` | Micro Orange theme icon |
| `preset_trust_purple.png` | Trust Purple theme icon |
| `preset_field_teal.png` | Field Teal theme icon |

## Android Launcher Icons

Place the actual launcher icons in:
- `android/app/src/main/res/mipmap-mdpi/` (48x48)
- `android/app/src/main/res/mipmap-hdpi/` (72x72)
- `android/app/src/main/res/mipmap-xhdpi/` (96x96)
- `android/app/src/main/res/mipmap-xxhdpi/` (144x144)
- `android/app/src/main/res/mipmap-xxxhdpi/` (192x192)

Required files per density:
- `ic_launcher.png` (default)
- `ic_launcher_bank_blue.png`
- `ic_launcher_savings_green.png`
- `ic_launcher_micro_orange.png`
- `ic_launcher_trust_purple.png`
- `ic_launcher_field_teal.png`

## iOS Alternate Icons

Place in `ios/Runner/Assets.xcassets/`:
- `AppIcon.appiconset/` (default, already exists)
- `AppIcon-BankBlue.appiconset/`
- `AppIcon-SavingsGreen.appiconset/`
- `AppIcon-MicroOrange.appiconset/`
- `AppIcon-TrustPurple.appiconset/`
- `AppIcon-FieldTeal.appiconset/`

Each iOS icon set needs sizes: 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024.

## Design Guidelines

All icons should:
- Use a rounded square shape (iOS will mask automatically)
- Feature a simple financial symbol (wallet, shield, chart, etc.)
- Use the theme's primary color as the background gradient
- Be clean and professional — no text on the icon itself
