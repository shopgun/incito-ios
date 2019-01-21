//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

struct IncitoDocument {
    typealias Identifier = GenericIdentifier<IncitoDocument>
    var id: Identifier
    var version: String
    var rootView: ViewNode

    var locale: String?
    var theme: Theme?
    var meta: [String: JSONValue]
    var fontAssets: [FontAssetName: FontAsset]
}

typealias ViewNode = TreeNode<ViewProperties>

struct ViewProperties {
    typealias Identifier = GenericIdentifier<ViewProperties>
    var id: Identifier
    
    var name: String?
    var type: ViewType
    var style: StyleProperties
    
    var layout: LayoutProperties
}

enum ViewType {
    case view
    case absoluteLayout
    case flexLayout(FlexLayoutProperties)
    case text(TextViewProperties)
    case image(ImageViewProperties)
    case videoEmbed(src: String)
    case video(VideoViewProperties)
}

struct StyleProperties {
    
    var role: String?
    var meta: [String: JSONValue]
    
    var cornerRadius: Corners<Unit>
    var shadow: Shadow? = nil
    //    var stroke: Stroke? = nil
    
    var link: String? // URI
    var title: String?
    var clipsChildren: Bool
    //    var accessibility: Accessibility? = nil
    
    var backgroundColor: Color?
    var backgroundImage: BackgroundImage?
    
    static let empty = StyleProperties(
        role: nil,
        meta: [:],
        cornerRadius: .zero,
        shadow: nil,
        link: nil,
        title: nil,
        clipsChildren: true,
        backgroundColor: nil,
        backgroundImage: nil
    )
}

struct LayoutProperties {
    var position: Edges<Unit?>
    var padding: UnitEdges
    var margins: UnitEdges
    
    var height: LayoutSize?
    var width: LayoutSize?
    var minHeight: Unit?
    var minWidth: Unit?
    var maxHeight: Unit?
    var maxWidth: Unit?
    
    var gravity: HorizontalGravity?
    
    var flexShrink: Double?
    var flexGrow: Double?
    
    var transform: Transform<Unit>

    static let empty = LayoutProperties(
        position: .init(nil),
        padding: .zero,
        margins: .zero,
        height: nil,
        width: nil,
        minHeight: nil,
        minWidth: nil,
        maxHeight: nil,
        maxWidth: nil,
        gravity: nil,
        flexShrink: nil,
        flexGrow: nil,
        transform: .identity
    )
}

// MARK: Subtype properties

struct TextViewProperties {
    
    struct Span: Decodable {
        enum SpanType: String, Decodable {
            case superscript
        }
        
        var name: SpanType
        var start: Int
        var end: Int
    }
    
    enum TextAlignment: String, Decodable {
        case left
        case right
        case center
    }
    
    var text: String
    
    var allCaps: Bool
    var fontFamily: FontFamily
    var textColor: Color?
    var textAlignment: TextAlignment?
    var textSize: Double?
    var fontStretch: String? // todo: what?
    var textStyle: TextStyle?
    var preventWidow: Bool
    var lineHeightMultiplier: Double?
    var spans: [Span]
    var maxLines: Int
    var shadow: Shadow? = nil
}

struct FlexLayoutProperties {
    enum ItemAlignment: String, Decodable {
        case stretch
        case center
        case flexStart  = "flex-start"
        case flexEnd   = "flex-end"
        case baseline
    }
    
    enum ContentJustification: String, Decodable {
        case flexStart      = "flex-start"
        case flexEnd        = "flex-end"
        case center         = "center"
        case spaceBetween   = "space-between"
        case spaceAround    = "space-around"
    }
    
    enum Direction: String, Decodable {
        case row
        case column
    }
    
    var direction: Direction = .row
    var itemAlignment: ItemAlignment = .stretch
    var contentJustification: ContentJustification = .flexStart
}

struct ImageViewProperties: Decodable {
    var source: URL // URI
    var caption: String?
    
    enum CodingKeys: String, CodingKey {
        case source = "src"
        case caption = "label"
    }
}
struct VideoViewProperties: Decodable {
    var source: String // URI
    var autoplay: Bool = false
    var loop: Bool = false
    var controls: Bool = true
    var mime: String?
}

/////////////////
// Definitions //
/////////////////

struct Theme {
    var textDefaults: TextViewDefaultProperties
    var bgColor: Color?
}

struct TextViewDefaultProperties {
    var textColor: Color
    var lineHeightMultiplier: Double
    var fontFamily: FontFamily
    
    // Currently not provided by server
    var textSize: Double { return 16 }
}

extension TextViewDefaultProperties {
    static var empty = TextViewDefaultProperties(
        textColor: Color(r: 0, g: 0, b: 0, a: 1),
        lineHeightMultiplier: 1,
        fontFamily: []
    )
}

struct FontAsset {
    typealias FontSource = (SourceType, URL)
    
    enum SourceType: String {
        case woff2
        case woff
        case truetype
        case opentype
        case svg
        case embeddedOpentype = "embedded-opentype"
    }
    
    var sources: [FontSource]
    var weight: String?
    var style: TextStyle
}

enum TextStyle: String {
    case normal
    case bold
    case italic
    case boldItalic
}

struct Shadow {
    var color: Color
    var offset: Size<Double>
    var radius: Double
}

struct Stroke {
    enum Style {
        case solid
        case dotted
        case dashed
    }
    
    struct Properties {
        var width: Unit
        var color: Color
    }
    
    var top, left, bottom, right: Properties
}

/// `TranslateValue` is the value used by the translate point property
struct Transform<TranslateValue> {
    var scale: Double
    var translate: Point<TranslateValue>
    var rotate: Double // radians
    // TODO: how is this represented?
    //    let origin: [String] // seems to more be an tuple of 2 Unit strings? x & y?
}

extension Transform where TranslateValue == Unit {
    static var identity = Transform(
        scale: 1,
        translate: Point(x: .pts(0), y: .pts(0)),
        rotate: 0
    )
}

enum HorizontalGravity: String, Decodable {
    case left   = "left_horizontal"
    case center = "center_horizontal"
    case right  = "right_horizontal"
}

struct Accessibility {
    var label: String
    var hidden: Bool
}

struct BackgroundImage {
    enum ScaleType: String, Decodable {
        case centerCrop = "center_crop"
        case centerInside = "center_inside"
    }
    
    enum TileMode: String, Decodable {
        case none
        case repeatX = "repeat_x"
        case repeatY = "repeat_y"
        case repeatXY = "repeat"
    }
    
    var source: URL
    var scale: ScaleType
    var position: String? // TODO: what? "center_center" /
    var tileMode: TileMode
}