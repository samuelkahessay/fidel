# Fidel - Claude Code Instructions

## Building & Testing

Always use **XcodeBuildMCP** tools for building and testing this project. Do not use raw `xcodebuild` commands via Bash.

### Session Defaults

Set these defaults at the start of each session:

- **Project path:** `Fidel.xcodeproj`
- **Scheme:** `Fidel`
- **Simulator:** `iPhone 17 Pro` (no iPhone 16 simulator available)
- **useLatestOS:** `true`
- **suppressWarnings:** `true`

### Common Operations

- **Build:** `build_sim` for simulator builds
- **Run:** `build_run_sim` to build and launch on simulator
- **Test:** `test_sim` for running tests on simulator
- **Device build:** `build_device` for physical device builds
