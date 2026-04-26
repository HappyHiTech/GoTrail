# GoTrail iOS

GoTrail is a SwiftUI iOS hiking companion app for tracking hikes, logging trail photos, and identifying plants with on-device ML.

## Features

- User authentication and account flow
- Start and end hikes with live location tracking
- Capture hike photos and classify plants from images
- Hike history dashboard with trail summaries
- Hike detail screens with route and photo context
- Local persistence with background sync to Supabase

## Tech Stack

- `SwiftUI` for UI and navigation
- `MapKit` and Core Location for hike route/location features
- Local SQLite-backed persistence for offline durability
- `Supabase` for auth, database, and storage sync
- `MLange` integration for plant classification

## Project Structure

- `GoTrailIOS/GoTrailIOS/App` - app entry, root navigation, core services
- `GoTrailIOS/GoTrailIOS/Features` - feature modules (`Auth`, `NewHike`, `ActiveHike`, `HikeHistory`, `HikeDetail`, `HikeCard`, `Splash`)
- `GoTrailIOS/GoTrailIOS/Hike` - hike session tracking and distance logic
- `GoTrailIOS/GoTrailIOS/Local` - local database and pending sync models
- `GoTrailIOS/GoTrailIOS/Sync` - Supabase sync orchestration
- `GoTrailIOS/GoTrailIOS/Tests` - unit tests

## Requirements

- macOS with Xcode installed
- Xcode supporting Swift 5+
- iOS Simulator or physical iPhone
- Supabase project credentials
- MLange personal key

## Configuration

Runtime secrets are injected through xcconfig files and `Info.plist`:

- `GoTrailIOS/Config/Debug.xcconfig`
- `GoTrailIOS/Config/Release.xcconfig`
- `GoTrailIOS/GoTrailIOS/Info.plist`

Set the following values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `ZETIC_MLANGE_PERSONAL_KEY`

Use placeholder values in source control for release builds, and keep real keys in local/private configuration.

## Getting Started

1. Clone the repository.
2. Open `GoTrailIOS/GoTrailIOS.xcodeproj` in Xcode.
3. Select a simulator (or connected device).
4. Make sure `Debug.xcconfig` has valid local credentials.
5. Build and run (`Cmd + R`).

## Testing

Run tests in Xcode from the `GoTrailIOS` test target, or run:

```bash
xcodebuild test \
  -project "GoTrailIOS/GoTrailIOS.xcodeproj" \
  -scheme "GoTrailIOS" \
  -destination "platform=iOS Simulator,name=iPhone 16"
```