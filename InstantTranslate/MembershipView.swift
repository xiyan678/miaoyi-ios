import SwiftUI
import StoreKit
import UIKit

struct MembershipView: View {
    @EnvironmentObject private var membership: MembershipStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = MembershipStore.yearlyProductID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 19) {
                    Image(systemName: "crown.fill").font(.system(size: 34)).foregroundStyle(.orange).frame(width: 76, height: 76).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 24)).padding(.top, 20)
                    VStack(spacing: 7) { Text("秒译 Pro").font(.system(size: 28, weight: .bold, design: .rounded)); Text("让跨语言交流更顺畅") .font(.subheadline).foregroundStyle(.secondary) }
                    VStack(alignment: .leading, spacing: 13) {
                        benefit("实时同传时长不限", icon: "waveform")
                        benefit("双语字幕与本地记录", icon: "captions.bubble")
                        benefit("AirPods 译文语音播放", icon: "airpodspro")
                        benefit("全部支持语言与翻译模式", icon: "globe")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(17).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    if membership.products.isEmpty {
                        VStack(spacing: 10) { ProgressView(); Text("正在从 App Store 加载方案…").font(.caption).foregroundStyle(.secondary) }.frame(height: 120)
                    } else {
                        VStack(spacing: 10) {
                            productRow(id: MembershipStore.yearlyProductID, title: "年费会员", detail: "更划算，适合长期使用", badge: "推荐")
                            productRow(id: MembershipStore.monthlyProductID, title: "月费会员", detail: "按月订阅，随时管理", badge: nil)
                            productRow(id: MembershipStore.lifetimeProductID, title: "永久会员", detail: "一次购买，长期使用", badge: nil)
                        }
                    }
                    Button { guard let product = membership.product(for: selectedID) else { return }; Task { await membership.purchase(product) } }
                    label: { HStack { if membership.isLoading { ProgressView().tint(.white) }; Text(membership.isPro ? "已开通 Pro" : "继续") }.font(.headline).frame(maxWidth: .infinity).frame(height: 52).foregroundStyle(.white).background(Color.blue, in: RoundedRectangle(cornerRadius: 16)) }
                    .disabled(membership.isLoading || membership.isPro || membership.product(for: selectedID) == nil)
                    if let message = membership.message { Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    Button("恢复购买") { Task { await membership.restore() } }.font(.subheadline)
                    Text("订阅将通过 Apple ID 扣款，可在系统设置中管理或取消。价格和续订条款以 App Store 确认页面为准。")
                        .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center).padding(.horizontal, 5)
                    HStack(spacing: 18) { Link("使用条款", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!); Text("隐私政策链接需在发布前配置").foregroundStyle(.tertiary) }.font(.caption)
                }.padding(.horizontal, 22).padding(.bottom, 30)
            }
            .navigationTitle("会员方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task { if membership.products.isEmpty { await membership.loadProducts() } }
        }
    }
    private func benefit(_ title: String, icon: String) -> some View { Label(title, systemImage: icon).font(.subheadline).foregroundStyle(.primary) }
    private func productRow(id: String, title: String, detail: String, badge: String?) -> some View {
        let product = membership.product(for: id)
        let selected = selectedID == id
        return Button { selectedID = id } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").foregroundStyle(selected ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 3) { HStack { Text(title).font(.subheadline.weight(.semibold)); if let badge { Text(badge).font(.system(size: 9, weight: .bold)).padding(.horizontal, 7).padding(.vertical, 3).background(.orange.opacity(0.16), in: Capsule()).foregroundStyle(.orange) } }; Text(detail).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(product?.displayPrice ?? "—").font(.subheadline.weight(.bold))
            }.padding(14).background(selected ? Color.blue.opacity(0.07) : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? Color.blue : .clear, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}


