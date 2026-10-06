# 秒译 iOS 源码

SwiftUI + Translation + Speech + AVAudioSession + StoreKit 2。可使用 Xcode Cloud、Codemagic、Bitrise 等 macOS 云构建环境打开 `InstantTranslate.xcodeproj`。

## 会员商品

商品 ID 位于 `InstantTranslate/MembershipStore.swift`，当前为示例值：
- `com.example.InstantTranslate.pro.monthly`：自动续期月订阅
- `com.example.InstantTranslate.pro.yearly`：自动续期年订阅
- `com.example.InstantTranslate.pro.lifetime`：永久解锁（非消耗型）

`StoreKitConfiguration.storekit` 是 Xcode 本地 StoreKit 测试配置，示例价格仅用于本地测试。发布前须在 App Store Connect 建立同 ID 的商品、配置订阅群组/本地化/审核信息，并将 Bundle ID 改为开发者账户下的唯一标识。

## 发布前必须配置

1. 用自己的域名替换会员页隐私政策链接；补齐服务条款、隐私政策、客服和订阅说明。
2. 配置 Apple Developer Team、签名、Bundle ID 与 App Store Connect IAP 商品。
3. 使用真机检查系统 Translation 语言可用性、Speech 语音识别、AirPods 输入/输出路由与后台音频行为。
4. 云构建并处理编译器诊断；本交付环境是 Windows，无 Xcode，无法声称已编译或真机验证。

会员状态通过 StoreKit 2 已验证交易和当前权益流读取，购买、待处理、恢复购买和交易更新已接入。当前 Pro 门槛用于同传入口演示。源码仍需云编译和设备 QA 后才能发布。
