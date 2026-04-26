# GoTrail Swift Starter Demos

This repo now has two beginner demos:

- Terminal Swift script: `SwiftHelloDemo/main.swift`
- SwiftUI iOS UI files: `TrailGuardiOSDemo/`

## 1) Terminal Demo (already runnable)

From the project root:

```bash
swift "SwiftHelloDemo/main.swift"
```

Expected output:

```text
Hello, TrailGuard!
Your first Swift program is running.
```

## 2) iOS SwiftUI Demo (Xcode Simulator)

I created these SwiftUI files for you:

- `TrailGuardiOSDemo/TrailGuardDemoApp.swift`
- `TrailGuardiOSDemo/ContentView.swift`

### Run in Xcode (step-by-step)

1. Open `Xcode`.
2. Create a new project:
   - `File` -> `New` -> `Project...`
   - Choose `iOS` -> `App`.
3. Project options:
   - Product Name: `TrailGuardDemo`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Use Core Data: unchecked
   - Testing System: default is fine
4. Save the project anywhere (Desktop is fine).
5. In Finder, open this repo folder and copy both files from `TrailGuardiOSDemo/`.
6. In Xcode navigator, replace the auto-generated `ContentView.swift` and `YourAppNameApp.swift` contents with the copied files.
   - If needed, rename `TrailGuardDemoApp` to match your project app file name.
7. At the top of Xcode, choose a simulator (for example `iPhone 16`).
8. Press the Run button (`▶`) or use `Cmd + R`.

You should see:

- "Hello, TrailGuard!"
- A button labeled "Tap Me"
- A tap counter that increases each press

## What this teaches

- `@State` in SwiftUI is like local React component state (`useState`).
- `ContentView` is like a React functional component.
- `TrailGuardDemoApp` is the app entry point (similar to your root render setup in web apps).