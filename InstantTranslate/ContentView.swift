import SwiftUI
import Translation
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: TranslationStore
    @EnvironmentObject private var membership: MembershipStore
    @State private var mode: AppMode = .listen
    @State private var showHistory = false
    @State private var showMembership = false
    @State private var showSourcePicker = false
    @State private var showTargetPicker = false
    @State private var translationConfiguration: TranslationSession.Configuration?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    VStack(alignment: .leading, spacing: 5) { Text("实时同传").font(.system(size: 30, weight: .bold, design: .rounded)); Text("听懂每一句，让交流自然发生。") .font(.subheadline).foregroundStyle(.secondary) }.padding(.top, 12)
                    Picker("模式", selection: $mode) { ForEach(AppMode.allCases) { item in Text(item.title).tag(item) } }.pickerStyle(.segmented)
                    languagePicker
                    card(title: "原文") {
                        TextEditor(text: $store.sourceText).frame(minHeight: 90).scrollContentBackground(.hidden).onChange(of: store.sourceText) { _, value in store.translate(value); prepareTranslation() }
                    } footer: { Text("\(store.sourceText.count) / 2000").font(.caption).foregroundStyle(.secondary); Spacer(); Button("清空", role: .destructive) { store.sourceText = ""; store.translatedText = "" } }
                    card(title: "译文") {
                        Text(store.translatedText.isEmpty ? "译文会显示在这里" : store.translatedText).font(.system(size: 18)).foregroundStyle(store.translatedText.isEmpty ? .secondary : .primary).frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
                    } footer: { Label("\(store.sourceLanguage.rawValue) → \(store.targetLanguage.rawValue)", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.blue); Spacer(); Button { UIPasteboard.general.string = store.translatedText } label: { Image(systemName: "doc.on.doc") }.disabled(store.translatedText.isEmpty); Button { store.speakTranslation() } label: { Image(systemName: "speaker.wave.2") }.disabled(store.translatedText.isEmpty) }
                    deviceCard
                    if mode == .meeting { historyCard }
                }.padding(.horizontal, 20).padding(.bottom, 110)
            }.background(Color(uiColor: .systemBackground))
            .toolbar { ToolbarItem(placement: .principal) { Text("秒译").font(.headline) }; ToolbarItemGroup(placement: .topBarTrailing) { Button { showMembership = true } label: { Image(systemName: membership.isPro ? "crown.fill" : "crown") }.tint(membership.isPro ? .orange : .primary); Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") } } }
            .safeAreaInset(edge: .bottom) { startButton }
            .sheet(isPresented: $showHistory) { historySheet }
            .sheet(isPresented: $showMembership) { MembershipView().environmentObject(membership) }
            .alert("提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("好", role: .cancel) { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
            .translationTask(translationConfiguration) { session in
                let text = store.sourceText.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }
                do { let response = try await session.translate(text); store.acceptTranslation(response.targetText) } catch { store.errorMessage = "翻译失败：\(error.localizedDescription)" }
            }
            .onChange(of: store.sourceLanguage) { _, _ in prepareTranslation() }
            .onChange(of: store.targetLanguage) { _, _ in prepareTranslation() }
        }
    }
    private var languagePicker: some View {
        HStack(spacing: 9) { languageButton("对方说", store.sourceLanguage) { showSourcePicker = true }; Button { store.swapLanguages() } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 38, height: 38).background(.thinMaterial, in: Circle()) }; languageButton("翻译成", store.targetLanguage) { showTargetPicker = true } }
        .confirmationDialog("选择对方语言", isPresented: $showSourcePicker) { ForEach(AppLanguage.allCases) { l in Button(l.rawValue) { store.sourceLanguage = l } } }
        .confirmationDialog("选择目标语言", isPresented: $showTargetPicker) { ForEach(AppLanguage.allCases) { l in Button(l.rawValue) { store.targetLanguage = l } } }
    }
    private func languageButton(_ label: String, _ language: AppLanguage, action: @escaping () -> Void) -> some View { Button(action: action) { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption).foregroundStyle(.secondary); HStack { Text(language.rawValue).font(.subheadline.weight(.semibold)); Image(systemName: "chevron.down").font(.caption) } }.frame(maxWidth: .infinity, alignment: .leading).padding(13).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain) }
    private func card<Content: View, Footer: View>(title: String, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) -> some View { VStack(alignment: .leading, spacing: 10) { Text(title.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary); content(); HStack { footer() } }.padding(16).background(Color(uiColor: .secondarySystemBackground).opacity(title == "译文" ? 0.8 : 0.5), in: RoundedRectangle(cornerRadius: 18)) }
    private var deviceCard: some View { HStack(spacing: 12) { Image(systemName: "airpodspro").font(.title3).foregroundStyle(.blue).frame(width: 42, height: 42).background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 3) { Text("AirPods 音频").font(.subheadline.weight(.semibold)); Text("当前输出：\(store.audioRouteName)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: store.audioRouteName == "iPhone" ? "iphone" : "checkmark.circle.fill").foregroundStyle(store.audioRouteName == "iPhone" ? .secondary : .green) }.padding(13).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16)) }
    private var startButton: some View { VStack(spacing: 7) { HStack(spacing: 6) { Circle().fill(store.isListening ? .red : .gray).frame(width: 7, height: 7); Text(store.isListening ? "正在聆听 · \(store.sourceLanguage.rawValue)" : "准备就绪").font(.caption).foregroundStyle(.secondary) }; Button { if store.isListening { store.stopListening() } else if membership.isPro { Task { await store.requestPermissionsAndStart() } } else { showMembership = true } } label: { Label(store.isListening ? "结束同传" : (membership.isPro ? "开始实时同传" : "开通 Pro 开始同传"), systemImage: store.isListening ? "stop.fill" : (membership.isPro ? "waveform" : "crown.fill")).font(.headline).frame(maxWidth: .infinity).frame(height: 52).foregroundStyle(.white).background(store.isListening ? Color.red : Color.blue, in: RoundedRectangle(cornerRadius: 16)) } }.padding(.horizontal, 20).padding(.top, 9).padding(.bottom, 5).background(.regularMaterial) }
    private var historyCard: some View { VStack(alignment: .leading) { Text("最近记录").font(.headline); ForEach(store.history.prefix(3)) { r in VStack(alignment: .leading) { Text(r.source).lineLimit(1); Text(r.translation).font(.caption).foregroundStyle(.secondary).lineLimit(1) }.padding(.vertical, 4) } }.frame(maxWidth: .infinity, alignment: .leading) }
    private var historySheet: some View { NavigationStack { List(store.history) { r in VStack(alignment: .leading, spacing: 6) { Text(r.source).font(.subheadline); Text(r.translation).font(.subheadline).foregroundStyle(.secondary); Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.tertiary) }.padding(.vertical, 4) }.navigationTitle("同传记录").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { showHistory = false } } } } }
    private func prepareTranslation() { guard store.sourceLanguage != store.targetLanguage else { store.acceptTranslation(store.sourceText); return }; translationConfiguration = TranslationSession.Configuration(source: store.sourceLanguage.language, target: store.targetLanguage.language) }
}
enum AppMode: String, CaseIterable, Identifiable { case listen, conversation, meeting; var id: String { rawValue }; var title: String { switch self { case .listen: "听译"; case .conversation: "对话"; case .meeting: "记录" } } }


