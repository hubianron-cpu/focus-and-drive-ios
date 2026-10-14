import SwiftUI

@main
struct FocusDriveApp: App {
    @StateObject private var model = DrivingViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
                .preferredColorScheme(.dark)
        }
    }
}
