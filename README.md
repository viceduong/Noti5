# NotifyFilter

iOS notification filtering app for TrollStore. Filter notifications from other apps and receive Critical Alerts for important messages even when Do Not Disturb is enabled.

## Features

- Monitor notifications from all apps
- Filter by sender name, keywords, or app
- Create rules with AND/OR logic
- Critical Alerts bypass Do Not Disturb
- Background monitoring with minimal battery impact
- Simple SwiftUI interface

## Requirements

- iOS 14.0 - 15.x
- TrollStore installed
- No jailbreak required

## Building

### Option 1: GitHub Actions (Recommended - No Mac Required!)

1. **Create a GitHub repository:**
   ```bash
   cd NotifyFilter
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. **Push to GitHub:**
   - Go to [github.com/new](https://github.com/new) and create a new repository
   - Follow GitHub's instructions to push your code:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/NotifyFilter.git
   git branch -M main
   git push -u origin main
   ```

3. **Wait for build:**
   - Go to your repository's "Actions" tab
   - The build will start automatically
   - Download `NotifyFilter.tipa` from the artifacts when complete

4. **Install via TrollStore:**
   - Transfer `.tipa` to your iPhone
   - Open in TrollStore to install

### Option 2: Using Theos

1. Install [Theos](https://theos.dev/docs/installation)
2. Clone this repository
3. Run:
   ```bash
   make package-trollstore
   ```
4. Install `packages/NotifyFilter.tipa` via TrollStore

### Option 2: Using Xcode

1. Open `NotifyFilter.xcodeproj` in Xcode
2. Build for "Generic iOS Device"
3. Sign the IPA with entitlements using `ldid`:
   ```bash
   ldid -SNotifyFilter/NotifyFilter.entitlements NotifyFilter.app/NotifyFilter
   ldid -SRootHelper/roothelper.entitlements NotifyFilter.app/roothelper
   ```
4. Create `.tipa` file:
   ```bash
   zip -r NotifyFilter.tipa Payload/
   ```
5. Install via TrollStore

## How It Works

1. **Root Helper**: Monitors iOS notification database at `/var/mobile/Library/DuetExpertCenter/streams/userNotificationEvents/local/`
2. **SEGB Parser**: Parses iOS binary notification format
3. **Rule Matching**: Evaluates notifications against user-defined rules
4. **Critical Alerts**: Re-notifies user using iOS Critical Alerts (bypass DND)

## Architecture

```
┌─────────────────────────────────┐
│     NotifyFilter App (SwiftUI)  │
│  - Rule configuration           │
│  - Critical Alert sender        │
│  - Status monitoring            │
└───────────────┬─────────────────┘
                │ Darwin Notifications
┌───────────────▼─────────────────┐
│     Root Helper (Objective-C)   │
│  - kqueue file monitoring       │
│  - SEGB database parser         │
│  - Rule matching engine         │
└───────────────┬─────────────────┘
                │
┌───────────────▼─────────────────┐
│   iOS Notification Database     │
│   /var/mobile/Library/          │
│   DuetExpertCenter/...          │
└─────────────────────────────────┘
```

## Entitlements

### Main App
- `com.apple.developer.usernotifications.critical-alerts` - Critical Alerts
- `com.apple.private.security.no-sandbox` - Sandbox escape
- `platform-application` - System app status
- `com.apple.private.persona-mgmt` - Spawn root helper

### Root Helper
- `com.apple.private.security.no-sandbox` - Full filesystem access
- `platform-application` - System status
- `com.apple.private.security.storage.AppDataContainers` - Data access

## Rule Examples

### Allow messages from specific contacts
```
Name: "Priority Contacts"
Action: Notify
Conditions:
  - Sender contains "Mom" OR
  - Sender contains "Dad" OR
  - Sender contains "Boss"
```

### Allow specific app + sender
```
Name: "Work Slack"
Action: Notify
Conditions:
  - App equals "com.tinyspeck.chatlyio" AND
  - Sender contains "Team Lead"
```

### Block promotional emails
```
Name: "Block Promotions"
Action: Block
Conditions:
  - App equals "com.google.Gmail" AND
  - Keyword contains "sale"
```

## Known Issues

- Notification database format may change between iOS versions
- Some apps may not write to the standard notification database
- Root helper must be restarted after device reboot

## License

MIT License

## Credits

- [TrollStore](https://github.com/opa334/TrollStore) by opa334
- [NotiBlock](https://github.com/eclair4151/NotiBlock) for inspiration
- [SEGB format research](https://gforce4n6.blogspot.com/2022/05/peeking-at-user-notification-events-in.html)
