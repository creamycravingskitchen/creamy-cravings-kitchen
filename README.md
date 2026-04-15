# Creamy Cravings Kitchen

This workspace contains a native SwiftUI starter app for:

- iPhone
- Mac

It uses a single shared codebase with a small starter feature so we can build from something real instead of an empty shell.

## What's Included

- `project.yml` for generating an Xcode project with XcodeGen
- Shared SwiftUI app entry point
- A small task dashboard UI
- In-memory app state with sample data
- Basic design tokens for colors and spacing

## Project Structure

- `CreamyCravingsKitchen/`
- `CreamyCravingsKitchen/App/`
- `CreamyCravingsKitchen/Models/`
- `CreamyCravingsKitchen/ViewModels/`
- `CreamyCravingsKitchen/Views/`
- `CreamyCravingsKitchen/DesignSystem/`

## Open The Project

Because Apple developer tools are not installed in this environment, I could not generate or build the app here.

To open it on your Mac:

1. Install Xcode from the App Store.
2. Install Xcode command line tools.
3. Install XcodeGen with Homebrew:

```bash
brew install xcodegen
```

4. From this folder, generate the Xcode project:

```bash
xcodegen generate
```

5. Open `CreamyCravingsKitchen.xcodeproj` in Xcode.
6. Choose an iPhone simulator or `My Mac` and run.

## Next Good Steps

- Add persistence with SwiftData
- Create onboarding
- Add authentication if the app will have accounts
- Introduce tabs or a sidebar once we decide the product direction

## Product Direction

Right now the starter is shaped like a lightweight personal organizer. If you want, I can turn it next into a:

- notes app
- finance tracker
- habit app
- wellness app
- social app
- AI assistant app
