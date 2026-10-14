// swift-tools-version: 5.9
import PackageDescription

// Tests compile the same state coordinator used by the iOS app, without Apple service access.
let package = Package(
    name: "FocusDriveCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "FocusDriveCore", targets: ["FocusDriveCore"])],
    targets: [
        .target(name: "FocusDriveCore", path: "FocusDrive", exclude: [
            "DrivingViewModel.swift", "ScreenTimeServices.swift", "HomeView.swift",
            "FocusDriveApp.swift", "FocusDrive.entitlements", "PrivacyInfo.xcprivacy"
        ], sources: ["DrivingSession.swift"]),
        .testTarget(name: "FocusDriveCoreTests", dependencies: ["FocusDriveCore"])
    ]
)
