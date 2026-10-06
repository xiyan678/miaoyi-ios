import SwiftUI

@main
struct InstantTranslateApp: App {
    @StateObject private var translator = TranslationStore()
    @StateObject private var membership = MembershipStore()
    var body: some Scene { WindowGroup { ContentView().environmentObject(translator).environmentObject(membership) } }
}
