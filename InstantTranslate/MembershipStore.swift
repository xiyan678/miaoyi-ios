import Foundation
import StoreKit

@MainActor
final class MembershipStore: ObservableObject {
    static let monthlyProductID = "com.example.InstantTranslate.pro.monthly"
    static let yearlyProductID = "com.example.InstantTranslate.pro.yearly"
    static let lifetimeProductID = "com.example.InstantTranslate.pro.lifetime"
    static let allProductIDs: Set<String> = [monthlyProductID, yearlyProductID, lifetimeProductID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var message: String?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await observeTransactions(); await refreshEntitlements(); await loadProducts() }
    }
    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do { products = try await Product.products(for: Self.allProductIDs).sorted { rank($0.id) < rank($1.id) } }
        catch { message = "暂时无法加载会员方案，请稍后重试。" }
    }
    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { message = "购买凭证验证失败。"; return }
                await transaction.finish(); await refreshEntitlements(); message = isPro ? "Pro 会员已开通。" : nil
            case .userCancelled: break
            case .pending: message = "购买正在等待 App Store 确认。"
            @unknown default: message = "购买暂未完成，请稍后重试。"
            }
        } catch { message = "购买失败：\(error.localizedDescription)" }
    }
    func restore() async {
        isLoading = true; defer { isLoading = false }
        do { try await AppStore.sync(); await refreshEntitlements(); message = isPro ? "已恢复 Pro 会员。" : "没有找到可恢复的会员。" }
        catch { message = "恢复购买失败：\(error.localizedDescription)" }
    }
    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish(); await refreshEntitlements()
        }
    }
    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.allProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  (transaction.expirationDate == nil || transaction.expirationDate! > .now) else { continue }
            entitled = true
        }
        isPro = entitled
    }
    func product(for id: String) -> Product? { products.first { $0.id == id } }
    private func rank(_ id: String) -> Int { [Self.yearlyProductID, Self.monthlyProductID, Self.lifetimeProductID].firstIndex(of: id) ?? 99 }
}
