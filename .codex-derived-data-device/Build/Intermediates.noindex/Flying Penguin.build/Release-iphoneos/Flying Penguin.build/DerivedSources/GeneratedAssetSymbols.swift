import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "LaunchBackground" asset catalog color resource.
    static let launchBackground = DeveloperToolsSupport.ColorResource(name: "LaunchBackground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "10_back_arm" asset catalog image resource.
    static let _10BackArm = DeveloperToolsSupport.ImageResource(name: "10_back_arm", bundle: resourceBundle)

    /// The "10_body_only" asset catalog image resource.
    static let _10BodyOnly = DeveloperToolsSupport.ImageResource(name: "10_body_only", bundle: resourceBundle)

    /// The "10_front_arm" asset catalog image resource.
    static let _10FrontArm = DeveloperToolsSupport.ImageResource(name: "10_front_arm", bundle: resourceBundle)

    /// The "10_main_character" asset catalog image resource.
    static let _10MainCharacter = DeveloperToolsSupport.ImageResource(name: "10_main_character", bundle: resourceBundle)

    /// The "10_thumb" asset catalog image resource.
    static let _10Thumb = DeveloperToolsSupport.ImageResource(name: "10_thumb", bundle: resourceBundle)

    /// The "1_back_arm" asset catalog image resource.
    static let _1BackArm = DeveloperToolsSupport.ImageResource(name: "1_back_arm", bundle: resourceBundle)

    /// The "1_body_only" asset catalog image resource.
    static let _1BodyOnly = DeveloperToolsSupport.ImageResource(name: "1_body_only", bundle: resourceBundle)

    /// The "1_front_arm" asset catalog image resource.
    static let _1FrontArm = DeveloperToolsSupport.ImageResource(name: "1_front_arm", bundle: resourceBundle)

    /// The "1_main_character" asset catalog image resource.
    static let _1MainCharacter = DeveloperToolsSupport.ImageResource(name: "1_main_character", bundle: resourceBundle)

    /// The "1_thumb" asset catalog image resource.
    static let _1Thumb = DeveloperToolsSupport.ImageResource(name: "1_thumb", bundle: resourceBundle)

    /// The "2_back_arm" asset catalog image resource.
    static let _2BackArm = DeveloperToolsSupport.ImageResource(name: "2_back_arm", bundle: resourceBundle)

    /// The "2_body_only" asset catalog image resource.
    static let _2BodyOnly = DeveloperToolsSupport.ImageResource(name: "2_body_only", bundle: resourceBundle)

    /// The "2_front_arm" asset catalog image resource.
    static let _2FrontArm = DeveloperToolsSupport.ImageResource(name: "2_front_arm", bundle: resourceBundle)

    /// The "2_main_character" asset catalog image resource.
    static let _2MainCharacter = DeveloperToolsSupport.ImageResource(name: "2_main_character", bundle: resourceBundle)

    /// The "2_thumb" asset catalog image resource.
    static let _2Thumb = DeveloperToolsSupport.ImageResource(name: "2_thumb", bundle: resourceBundle)

    /// The "3_back_arm" asset catalog image resource.
    static let _3BackArm = DeveloperToolsSupport.ImageResource(name: "3_back_arm", bundle: resourceBundle)

    /// The "3_body_only" asset catalog image resource.
    static let _3BodyOnly = DeveloperToolsSupport.ImageResource(name: "3_body_only", bundle: resourceBundle)

    /// The "3_front_arm" asset catalog image resource.
    static let _3FrontArm = DeveloperToolsSupport.ImageResource(name: "3_front_arm", bundle: resourceBundle)

    /// The "3_main_character" asset catalog image resource.
    static let _3MainCharacter = DeveloperToolsSupport.ImageResource(name: "3_main_character", bundle: resourceBundle)

    /// The "3_thumb" asset catalog image resource.
    static let _3Thumb = DeveloperToolsSupport.ImageResource(name: "3_thumb", bundle: resourceBundle)

    /// The "4_back_arm" asset catalog image resource.
    static let _4BackArm = DeveloperToolsSupport.ImageResource(name: "4_back_arm", bundle: resourceBundle)

    /// The "4_body_only" asset catalog image resource.
    static let _4BodyOnly = DeveloperToolsSupport.ImageResource(name: "4_body_only", bundle: resourceBundle)

    /// The "4_front_arm" asset catalog image resource.
    static let _4FrontArm = DeveloperToolsSupport.ImageResource(name: "4_front_arm", bundle: resourceBundle)

    /// The "4_main_character" asset catalog image resource.
    static let _4MainCharacter = DeveloperToolsSupport.ImageResource(name: "4_main_character", bundle: resourceBundle)

    /// The "4_thumb" asset catalog image resource.
    static let _4Thumb = DeveloperToolsSupport.ImageResource(name: "4_thumb", bundle: resourceBundle)

    /// The "5_back_arm" asset catalog image resource.
    static let _5BackArm = DeveloperToolsSupport.ImageResource(name: "5_back_arm", bundle: resourceBundle)

    /// The "5_body_only" asset catalog image resource.
    static let _5BodyOnly = DeveloperToolsSupport.ImageResource(name: "5_body_only", bundle: resourceBundle)

    /// The "5_front_arm" asset catalog image resource.
    static let _5FrontArm = DeveloperToolsSupport.ImageResource(name: "5_front_arm", bundle: resourceBundle)

    /// The "5_main_character" asset catalog image resource.
    static let _5MainCharacter = DeveloperToolsSupport.ImageResource(name: "5_main_character", bundle: resourceBundle)

    /// The "5_thumb" asset catalog image resource.
    static let _5Thumb = DeveloperToolsSupport.ImageResource(name: "5_thumb", bundle: resourceBundle)

    /// The "6_back_arm" asset catalog image resource.
    static let _6BackArm = DeveloperToolsSupport.ImageResource(name: "6_back_arm", bundle: resourceBundle)

    /// The "6_body_only" asset catalog image resource.
    static let _6BodyOnly = DeveloperToolsSupport.ImageResource(name: "6_body_only", bundle: resourceBundle)

    /// The "6_front_arm" asset catalog image resource.
    static let _6FrontArm = DeveloperToolsSupport.ImageResource(name: "6_front_arm", bundle: resourceBundle)

    /// The "6_main_character" asset catalog image resource.
    static let _6MainCharacter = DeveloperToolsSupport.ImageResource(name: "6_main_character", bundle: resourceBundle)

    /// The "6_thumb" asset catalog image resource.
    static let _6Thumb = DeveloperToolsSupport.ImageResource(name: "6_thumb", bundle: resourceBundle)

    /// The "7_back_arm" asset catalog image resource.
    static let _7BackArm = DeveloperToolsSupport.ImageResource(name: "7_back_arm", bundle: resourceBundle)

    /// The "7_body_only" asset catalog image resource.
    static let _7BodyOnly = DeveloperToolsSupport.ImageResource(name: "7_body_only", bundle: resourceBundle)

    /// The "7_front_arm" asset catalog image resource.
    static let _7FrontArm = DeveloperToolsSupport.ImageResource(name: "7_front_arm", bundle: resourceBundle)

    /// The "7_main_character" asset catalog image resource.
    static let _7MainCharacter = DeveloperToolsSupport.ImageResource(name: "7_main_character", bundle: resourceBundle)

    /// The "7_thumb" asset catalog image resource.
    static let _7Thumb = DeveloperToolsSupport.ImageResource(name: "7_thumb", bundle: resourceBundle)

    /// The "8_back_arm" asset catalog image resource.
    static let _8BackArm = DeveloperToolsSupport.ImageResource(name: "8_back_arm", bundle: resourceBundle)

    /// The "8_body_only" asset catalog image resource.
    static let _8BodyOnly = DeveloperToolsSupport.ImageResource(name: "8_body_only", bundle: resourceBundle)

    /// The "8_front_arm" asset catalog image resource.
    static let _8FrontArm = DeveloperToolsSupport.ImageResource(name: "8_front_arm", bundle: resourceBundle)

    /// The "8_main_character" asset catalog image resource.
    static let _8MainCharacter = DeveloperToolsSupport.ImageResource(name: "8_main_character", bundle: resourceBundle)

    /// The "8_thumb" asset catalog image resource.
    static let _8Thumb = DeveloperToolsSupport.ImageResource(name: "8_thumb", bundle: resourceBundle)

    /// The "9_back_arm" asset catalog image resource.
    static let _9BackArm = DeveloperToolsSupport.ImageResource(name: "9_back_arm", bundle: resourceBundle)

    /// The "9_body_only" asset catalog image resource.
    static let _9BodyOnly = DeveloperToolsSupport.ImageResource(name: "9_body_only", bundle: resourceBundle)

    /// The "9_front_arm" asset catalog image resource.
    static let _9FrontArm = DeveloperToolsSupport.ImageResource(name: "9_front_arm", bundle: resourceBundle)

    /// The "9_main_character" asset catalog image resource.
    static let _9MainCharacter = DeveloperToolsSupport.ImageResource(name: "9_main_character", bundle: resourceBundle)

    /// The "9_thumb" asset catalog image resource.
    static let _9Thumb = DeveloperToolsSupport.ImageResource(name: "9_thumb", bundle: resourceBundle)

    /// The "canon" asset catalog image resource.
    static let canon = DeveloperToolsSupport.ImageResource(name: "canon", bundle: resourceBundle)

    /// The "hoop_currency" asset catalog image resource.
    static let hoopCurrency = DeveloperToolsSupport.ImageResource(name: "hoop_currency", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .launchBackground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .launchBackground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: SwiftUI.Color { .init(.launchBackground) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: SwiftUI.Color { .init(.launchBackground) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "10_back_arm" asset catalog image.
    static var _10BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._10BackArm)
#else
        .init()
#endif
    }

    /// The "10_body_only" asset catalog image.
    static var _10BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._10BodyOnly)
#else
        .init()
#endif
    }

    /// The "10_front_arm" asset catalog image.
    static var _10FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._10FrontArm)
#else
        .init()
#endif
    }

    /// The "10_main_character" asset catalog image.
    static var _10MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._10MainCharacter)
#else
        .init()
#endif
    }

    /// The "10_thumb" asset catalog image.
    static var _10Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._10Thumb)
#else
        .init()
#endif
    }

    /// The "1_back_arm" asset catalog image.
    static var _1BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._1BackArm)
#else
        .init()
#endif
    }

    /// The "1_body_only" asset catalog image.
    static var _1BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._1BodyOnly)
#else
        .init()
#endif
    }

    /// The "1_front_arm" asset catalog image.
    static var _1FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._1FrontArm)
#else
        .init()
#endif
    }

    /// The "1_main_character" asset catalog image.
    static var _1MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._1MainCharacter)
#else
        .init()
#endif
    }

    /// The "1_thumb" asset catalog image.
    static var _1Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._1Thumb)
#else
        .init()
#endif
    }

    /// The "2_back_arm" asset catalog image.
    static var _2BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._2BackArm)
#else
        .init()
#endif
    }

    /// The "2_body_only" asset catalog image.
    static var _2BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._2BodyOnly)
#else
        .init()
#endif
    }

    /// The "2_front_arm" asset catalog image.
    static var _2FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._2FrontArm)
#else
        .init()
#endif
    }

    /// The "2_main_character" asset catalog image.
    static var _2MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._2MainCharacter)
#else
        .init()
#endif
    }

    /// The "2_thumb" asset catalog image.
    static var _2Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._2Thumb)
#else
        .init()
#endif
    }

    /// The "3_back_arm" asset catalog image.
    static var _3BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._3BackArm)
#else
        .init()
#endif
    }

    /// The "3_body_only" asset catalog image.
    static var _3BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._3BodyOnly)
#else
        .init()
#endif
    }

    /// The "3_front_arm" asset catalog image.
    static var _3FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._3FrontArm)
#else
        .init()
#endif
    }

    /// The "3_main_character" asset catalog image.
    static var _3MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._3MainCharacter)
#else
        .init()
#endif
    }

    /// The "3_thumb" asset catalog image.
    static var _3Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._3Thumb)
#else
        .init()
#endif
    }

    /// The "4_back_arm" asset catalog image.
    static var _4BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._4BackArm)
#else
        .init()
#endif
    }

    /// The "4_body_only" asset catalog image.
    static var _4BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._4BodyOnly)
#else
        .init()
#endif
    }

    /// The "4_front_arm" asset catalog image.
    static var _4FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._4FrontArm)
#else
        .init()
#endif
    }

    /// The "4_main_character" asset catalog image.
    static var _4MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._4MainCharacter)
#else
        .init()
#endif
    }

    /// The "4_thumb" asset catalog image.
    static var _4Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._4Thumb)
#else
        .init()
#endif
    }

    /// The "5_back_arm" asset catalog image.
    static var _5BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._5BackArm)
#else
        .init()
#endif
    }

    /// The "5_body_only" asset catalog image.
    static var _5BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._5BodyOnly)
#else
        .init()
#endif
    }

    /// The "5_front_arm" asset catalog image.
    static var _5FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._5FrontArm)
#else
        .init()
#endif
    }

    /// The "5_main_character" asset catalog image.
    static var _5MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._5MainCharacter)
#else
        .init()
#endif
    }

    /// The "5_thumb" asset catalog image.
    static var _5Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._5Thumb)
#else
        .init()
#endif
    }

    /// The "6_back_arm" asset catalog image.
    static var _6BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._6BackArm)
#else
        .init()
#endif
    }

    /// The "6_body_only" asset catalog image.
    static var _6BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._6BodyOnly)
#else
        .init()
#endif
    }

    /// The "6_front_arm" asset catalog image.
    static var _6FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._6FrontArm)
#else
        .init()
#endif
    }

    /// The "6_main_character" asset catalog image.
    static var _6MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._6MainCharacter)
#else
        .init()
#endif
    }

    /// The "6_thumb" asset catalog image.
    static var _6Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._6Thumb)
#else
        .init()
#endif
    }

    /// The "7_back_arm" asset catalog image.
    static var _7BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._7BackArm)
#else
        .init()
#endif
    }

    /// The "7_body_only" asset catalog image.
    static var _7BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._7BodyOnly)
#else
        .init()
#endif
    }

    /// The "7_front_arm" asset catalog image.
    static var _7FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._7FrontArm)
#else
        .init()
#endif
    }

    /// The "7_main_character" asset catalog image.
    static var _7MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._7MainCharacter)
#else
        .init()
#endif
    }

    /// The "7_thumb" asset catalog image.
    static var _7Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._7Thumb)
#else
        .init()
#endif
    }

    /// The "8_back_arm" asset catalog image.
    static var _8BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._8BackArm)
#else
        .init()
#endif
    }

    /// The "8_body_only" asset catalog image.
    static var _8BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._8BodyOnly)
#else
        .init()
#endif
    }

    /// The "8_front_arm" asset catalog image.
    static var _8FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._8FrontArm)
#else
        .init()
#endif
    }

    /// The "8_main_character" asset catalog image.
    static var _8MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._8MainCharacter)
#else
        .init()
#endif
    }

    /// The "8_thumb" asset catalog image.
    static var _8Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._8Thumb)
#else
        .init()
#endif
    }

    /// The "9_back_arm" asset catalog image.
    static var _9BackArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._9BackArm)
#else
        .init()
#endif
    }

    /// The "9_body_only" asset catalog image.
    static var _9BodyOnly: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._9BodyOnly)
#else
        .init()
#endif
    }

    /// The "9_front_arm" asset catalog image.
    static var _9FrontArm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._9FrontArm)
#else
        .init()
#endif
    }

    /// The "9_main_character" asset catalog image.
    static var _9MainCharacter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._9MainCharacter)
#else
        .init()
#endif
    }

    /// The "9_thumb" asset catalog image.
    static var _9Thumb: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: ._9Thumb)
#else
        .init()
#endif
    }

    /// The "canon" asset catalog image.
    static var canon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .canon)
#else
        .init()
#endif
    }

    /// The "hoop_currency" asset catalog image.
    static var hoopCurrency: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .hoopCurrency)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "10_back_arm" asset catalog image.
    static var _10BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._10BackArm)
#else
        .init()
#endif
    }

    /// The "10_body_only" asset catalog image.
    static var _10BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._10BodyOnly)
#else
        .init()
#endif
    }

    /// The "10_front_arm" asset catalog image.
    static var _10FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._10FrontArm)
#else
        .init()
#endif
    }

    /// The "10_main_character" asset catalog image.
    static var _10MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._10MainCharacter)
#else
        .init()
#endif
    }

    /// The "10_thumb" asset catalog image.
    static var _10Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._10Thumb)
#else
        .init()
#endif
    }

    /// The "1_back_arm" asset catalog image.
    static var _1BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._1BackArm)
#else
        .init()
#endif
    }

    /// The "1_body_only" asset catalog image.
    static var _1BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._1BodyOnly)
#else
        .init()
#endif
    }

    /// The "1_front_arm" asset catalog image.
    static var _1FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._1FrontArm)
#else
        .init()
#endif
    }

    /// The "1_main_character" asset catalog image.
    static var _1MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._1MainCharacter)
#else
        .init()
#endif
    }

    /// The "1_thumb" asset catalog image.
    static var _1Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._1Thumb)
#else
        .init()
#endif
    }

    /// The "2_back_arm" asset catalog image.
    static var _2BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._2BackArm)
#else
        .init()
#endif
    }

    /// The "2_body_only" asset catalog image.
    static var _2BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._2BodyOnly)
#else
        .init()
#endif
    }

    /// The "2_front_arm" asset catalog image.
    static var _2FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._2FrontArm)
#else
        .init()
#endif
    }

    /// The "2_main_character" asset catalog image.
    static var _2MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._2MainCharacter)
#else
        .init()
#endif
    }

    /// The "2_thumb" asset catalog image.
    static var _2Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._2Thumb)
#else
        .init()
#endif
    }

    /// The "3_back_arm" asset catalog image.
    static var _3BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._3BackArm)
#else
        .init()
#endif
    }

    /// The "3_body_only" asset catalog image.
    static var _3BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._3BodyOnly)
#else
        .init()
#endif
    }

    /// The "3_front_arm" asset catalog image.
    static var _3FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._3FrontArm)
#else
        .init()
#endif
    }

    /// The "3_main_character" asset catalog image.
    static var _3MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._3MainCharacter)
#else
        .init()
#endif
    }

    /// The "3_thumb" asset catalog image.
    static var _3Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._3Thumb)
#else
        .init()
#endif
    }

    /// The "4_back_arm" asset catalog image.
    static var _4BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._4BackArm)
#else
        .init()
#endif
    }

    /// The "4_body_only" asset catalog image.
    static var _4BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._4BodyOnly)
#else
        .init()
#endif
    }

    /// The "4_front_arm" asset catalog image.
    static var _4FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._4FrontArm)
#else
        .init()
#endif
    }

    /// The "4_main_character" asset catalog image.
    static var _4MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._4MainCharacter)
#else
        .init()
#endif
    }

    /// The "4_thumb" asset catalog image.
    static var _4Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._4Thumb)
#else
        .init()
#endif
    }

    /// The "5_back_arm" asset catalog image.
    static var _5BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._5BackArm)
#else
        .init()
#endif
    }

    /// The "5_body_only" asset catalog image.
    static var _5BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._5BodyOnly)
#else
        .init()
#endif
    }

    /// The "5_front_arm" asset catalog image.
    static var _5FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._5FrontArm)
#else
        .init()
#endif
    }

    /// The "5_main_character" asset catalog image.
    static var _5MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._5MainCharacter)
#else
        .init()
#endif
    }

    /// The "5_thumb" asset catalog image.
    static var _5Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._5Thumb)
#else
        .init()
#endif
    }

    /// The "6_back_arm" asset catalog image.
    static var _6BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._6BackArm)
#else
        .init()
#endif
    }

    /// The "6_body_only" asset catalog image.
    static var _6BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._6BodyOnly)
#else
        .init()
#endif
    }

    /// The "6_front_arm" asset catalog image.
    static var _6FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._6FrontArm)
#else
        .init()
#endif
    }

    /// The "6_main_character" asset catalog image.
    static var _6MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._6MainCharacter)
#else
        .init()
#endif
    }

    /// The "6_thumb" asset catalog image.
    static var _6Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._6Thumb)
#else
        .init()
#endif
    }

    /// The "7_back_arm" asset catalog image.
    static var _7BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._7BackArm)
#else
        .init()
#endif
    }

    /// The "7_body_only" asset catalog image.
    static var _7BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._7BodyOnly)
#else
        .init()
#endif
    }

    /// The "7_front_arm" asset catalog image.
    static var _7FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._7FrontArm)
#else
        .init()
#endif
    }

    /// The "7_main_character" asset catalog image.
    static var _7MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._7MainCharacter)
#else
        .init()
#endif
    }

    /// The "7_thumb" asset catalog image.
    static var _7Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._7Thumb)
#else
        .init()
#endif
    }

    /// The "8_back_arm" asset catalog image.
    static var _8BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._8BackArm)
#else
        .init()
#endif
    }

    /// The "8_body_only" asset catalog image.
    static var _8BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._8BodyOnly)
#else
        .init()
#endif
    }

    /// The "8_front_arm" asset catalog image.
    static var _8FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._8FrontArm)
#else
        .init()
#endif
    }

    /// The "8_main_character" asset catalog image.
    static var _8MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._8MainCharacter)
#else
        .init()
#endif
    }

    /// The "8_thumb" asset catalog image.
    static var _8Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._8Thumb)
#else
        .init()
#endif
    }

    /// The "9_back_arm" asset catalog image.
    static var _9BackArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._9BackArm)
#else
        .init()
#endif
    }

    /// The "9_body_only" asset catalog image.
    static var _9BodyOnly: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._9BodyOnly)
#else
        .init()
#endif
    }

    /// The "9_front_arm" asset catalog image.
    static var _9FrontArm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._9FrontArm)
#else
        .init()
#endif
    }

    /// The "9_main_character" asset catalog image.
    static var _9MainCharacter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._9MainCharacter)
#else
        .init()
#endif
    }

    /// The "9_thumb" asset catalog image.
    static var _9Thumb: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: ._9Thumb)
#else
        .init()
#endif
    }

    /// The "canon" asset catalog image.
    static var canon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .canon)
#else
        .init()
#endif
    }

    /// The "hoop_currency" asset catalog image.
    static var hoopCurrency: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .hoopCurrency)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

