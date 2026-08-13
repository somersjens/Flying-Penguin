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

    /// The "1_back_arm" asset catalog image resource.
    static let _1BackArm = DeveloperToolsSupport.ImageResource(name: "1_back_arm", bundle: resourceBundle)

    /// The "1_body_only" asset catalog image resource.
    static let _1BodyOnly = DeveloperToolsSupport.ImageResource(name: "1_body_only", bundle: resourceBundle)

    /// The "1_front_arm" asset catalog image resource.
    static let _1FrontArm = DeveloperToolsSupport.ImageResource(name: "1_front_arm", bundle: resourceBundle)

    /// The "1_main_character" asset catalog image resource.
    static let _1MainCharacter = DeveloperToolsSupport.ImageResource(name: "1_main_character", bundle: resourceBundle)

    /// The "2_back_arm" asset catalog image resource.
    static let _2BackArm = DeveloperToolsSupport.ImageResource(name: "2_back_arm", bundle: resourceBundle)

    /// The "2_body_only" asset catalog image resource.
    static let _2BodyOnly = DeveloperToolsSupport.ImageResource(name: "2_body_only", bundle: resourceBundle)

    /// The "2_front_arm" asset catalog image resource.
    static let _2FrontArm = DeveloperToolsSupport.ImageResource(name: "2_front_arm", bundle: resourceBundle)

    /// The "2_main_character" asset catalog image resource.
    static let _2MainCharacter = DeveloperToolsSupport.ImageResource(name: "2_main_character", bundle: resourceBundle)

    /// The "canon" asset catalog image resource.
    static let canon = DeveloperToolsSupport.ImageResource(name: "canon", bundle: resourceBundle)

    /// The "front_1" asset catalog image resource.
    static let front1 = DeveloperToolsSupport.ImageResource(name: "front_1", bundle: resourceBundle)

    /// The "front_10" asset catalog image resource.
    static let front10 = DeveloperToolsSupport.ImageResource(name: "front_10", bundle: resourceBundle)

    /// The "front_2" asset catalog image resource.
    static let front2 = DeveloperToolsSupport.ImageResource(name: "front_2", bundle: resourceBundle)

    /// The "front_3" asset catalog image resource.
    static let front3 = DeveloperToolsSupport.ImageResource(name: "front_3", bundle: resourceBundle)

    /// The "front_4" asset catalog image resource.
    static let front4 = DeveloperToolsSupport.ImageResource(name: "front_4", bundle: resourceBundle)

    /// The "front_5" asset catalog image resource.
    static let front5 = DeveloperToolsSupport.ImageResource(name: "front_5", bundle: resourceBundle)

    /// The "front_6" asset catalog image resource.
    static let front6 = DeveloperToolsSupport.ImageResource(name: "front_6", bundle: resourceBundle)

    /// The "front_7" asset catalog image resource.
    static let front7 = DeveloperToolsSupport.ImageResource(name: "front_7", bundle: resourceBundle)

    /// The "front_8" asset catalog image resource.
    static let front8 = DeveloperToolsSupport.ImageResource(name: "front_8", bundle: resourceBundle)

    /// The "front_9" asset catalog image resource.
    static let front9 = DeveloperToolsSupport.ImageResource(name: "front_9", bundle: resourceBundle)

    /// The "hoop_currency" asset catalog image resource.
    static let hoopCurrency = DeveloperToolsSupport.ImageResource(name: "hoop_currency", bundle: resourceBundle)

    /// The "poop" asset catalog image resource.
    static let poop = DeveloperToolsSupport.ImageResource(name: "poop", bundle: resourceBundle)

    /// The "thumb_1" asset catalog image resource.
    static let thumb1 = DeveloperToolsSupport.ImageResource(name: "thumb_1", bundle: resourceBundle)

    /// The "thumb_10" asset catalog image resource.
    static let thumb10 = DeveloperToolsSupport.ImageResource(name: "thumb_10", bundle: resourceBundle)

    /// The "thumb_2" asset catalog image resource.
    static let thumb2 = DeveloperToolsSupport.ImageResource(name: "thumb_2", bundle: resourceBundle)

    /// The "thumb_3" asset catalog image resource.
    static let thumb3 = DeveloperToolsSupport.ImageResource(name: "thumb_3", bundle: resourceBundle)

    /// The "thumb_4" asset catalog image resource.
    static let thumb4 = DeveloperToolsSupport.ImageResource(name: "thumb_4", bundle: resourceBundle)

    /// The "thumb_5" asset catalog image resource.
    static let thumb5 = DeveloperToolsSupport.ImageResource(name: "thumb_5", bundle: resourceBundle)

    /// The "thumb_6" asset catalog image resource.
    static let thumb6 = DeveloperToolsSupport.ImageResource(name: "thumb_6", bundle: resourceBundle)

    /// The "thumb_7" asset catalog image resource.
    static let thumb7 = DeveloperToolsSupport.ImageResource(name: "thumb_7", bundle: resourceBundle)

    /// The "thumb_8" asset catalog image resource.
    static let thumb8 = DeveloperToolsSupport.ImageResource(name: "thumb_8", bundle: resourceBundle)

    /// The "thumb_9" asset catalog image resource.
    static let thumb9 = DeveloperToolsSupport.ImageResource(name: "thumb_9", bundle: resourceBundle)

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

    /// The "canon" asset catalog image.
    static var canon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .canon)
#else
        .init()
#endif
    }

    /// The "front_1" asset catalog image.
    static var front1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front1)
#else
        .init()
#endif
    }

    /// The "front_10" asset catalog image.
    static var front10: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front10)
#else
        .init()
#endif
    }

    /// The "front_2" asset catalog image.
    static var front2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front2)
#else
        .init()
#endif
    }

    /// The "front_3" asset catalog image.
    static var front3: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front3)
#else
        .init()
#endif
    }

    /// The "front_4" asset catalog image.
    static var front4: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front4)
#else
        .init()
#endif
    }

    /// The "front_5" asset catalog image.
    static var front5: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front5)
#else
        .init()
#endif
    }

    /// The "front_6" asset catalog image.
    static var front6: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front6)
#else
        .init()
#endif
    }

    /// The "front_7" asset catalog image.
    static var front7: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front7)
#else
        .init()
#endif
    }

    /// The "front_8" asset catalog image.
    static var front8: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front8)
#else
        .init()
#endif
    }

    /// The "front_9" asset catalog image.
    static var front9: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .front9)
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

    /// The "poop" asset catalog image.
    static var poop: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .poop)
#else
        .init()
#endif
    }

    /// The "thumb_1" asset catalog image.
    static var thumb1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb1)
#else
        .init()
#endif
    }

    /// The "thumb_10" asset catalog image.
    static var thumb10: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb10)
#else
        .init()
#endif
    }

    /// The "thumb_2" asset catalog image.
    static var thumb2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb2)
#else
        .init()
#endif
    }

    /// The "thumb_3" asset catalog image.
    static var thumb3: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb3)
#else
        .init()
#endif
    }

    /// The "thumb_4" asset catalog image.
    static var thumb4: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb4)
#else
        .init()
#endif
    }

    /// The "thumb_5" asset catalog image.
    static var thumb5: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb5)
#else
        .init()
#endif
    }

    /// The "thumb_6" asset catalog image.
    static var thumb6: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb6)
#else
        .init()
#endif
    }

    /// The "thumb_7" asset catalog image.
    static var thumb7: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb7)
#else
        .init()
#endif
    }

    /// The "thumb_8" asset catalog image.
    static var thumb8: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb8)
#else
        .init()
#endif
    }

    /// The "thumb_9" asset catalog image.
    static var thumb9: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .thumb9)
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

    /// The "canon" asset catalog image.
    static var canon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .canon)
#else
        .init()
#endif
    }

    /// The "front_1" asset catalog image.
    static var front1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front1)
#else
        .init()
#endif
    }

    /// The "front_10" asset catalog image.
    static var front10: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front10)
#else
        .init()
#endif
    }

    /// The "front_2" asset catalog image.
    static var front2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front2)
#else
        .init()
#endif
    }

    /// The "front_3" asset catalog image.
    static var front3: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front3)
#else
        .init()
#endif
    }

    /// The "front_4" asset catalog image.
    static var front4: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front4)
#else
        .init()
#endif
    }

    /// The "front_5" asset catalog image.
    static var front5: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front5)
#else
        .init()
#endif
    }

    /// The "front_6" asset catalog image.
    static var front6: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front6)
#else
        .init()
#endif
    }

    /// The "front_7" asset catalog image.
    static var front7: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front7)
#else
        .init()
#endif
    }

    /// The "front_8" asset catalog image.
    static var front8: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front8)
#else
        .init()
#endif
    }

    /// The "front_9" asset catalog image.
    static var front9: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .front9)
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

    /// The "poop" asset catalog image.
    static var poop: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .poop)
#else
        .init()
#endif
    }

    /// The "thumb_1" asset catalog image.
    static var thumb1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb1)
#else
        .init()
#endif
    }

    /// The "thumb_10" asset catalog image.
    static var thumb10: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb10)
#else
        .init()
#endif
    }

    /// The "thumb_2" asset catalog image.
    static var thumb2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb2)
#else
        .init()
#endif
    }

    /// The "thumb_3" asset catalog image.
    static var thumb3: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb3)
#else
        .init()
#endif
    }

    /// The "thumb_4" asset catalog image.
    static var thumb4: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb4)
#else
        .init()
#endif
    }

    /// The "thumb_5" asset catalog image.
    static var thumb5: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb5)
#else
        .init()
#endif
    }

    /// The "thumb_6" asset catalog image.
    static var thumb6: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb6)
#else
        .init()
#endif
    }

    /// The "thumb_7" asset catalog image.
    static var thumb7: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb7)
#else
        .init()
#endif
    }

    /// The "thumb_8" asset catalog image.
    static var thumb8: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb8)
#else
        .init()
#endif
    }

    /// The "thumb_9" asset catalog image.
    static var thumb9: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .thumb9)
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

