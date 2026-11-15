import SwiftUI

@main
struct QianJiApp: App {
    @StateObject private var settings = AppSettings.shared
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(settings)
                .onAppear {
                    AppBootstrap.ensureSeeded()
                    BudgetReminder.requestAuthorization()
                    Haptics.prepareAll()      // 预热触感引擎，降低首次触发延迟
                }
        }
    }
}
