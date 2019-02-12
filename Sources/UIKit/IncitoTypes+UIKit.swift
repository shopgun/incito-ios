//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension Color {
    public var uiColor: UIColor {
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

extension TextViewProperties.TextAlignment {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }
}

extension CALayer {
    func applyShadow(_ shadow: Shadow) {
        shadowColor = shadow.color.uiColor.cgColor
        shadowRadius = CGFloat(shadow.radius)
        shadowOffset = shadow.offset.cgSize
        shadowOpacity = 1
    }
}

extension BackgroundImage.Position {
    func contentsGravity(isFlipped: Bool) -> CALayerContentsGravity {
        switch self {
        case .leftTop:
            return isFlipped ? .bottomLeft : .topLeft
        case .leftCenter:
            return .left
        case .leftBottom:
            return isFlipped ? .topLeft : .bottomLeft
        case .centerTop:
            return isFlipped ? .bottom : .top
        case .centerCenter:
            return .center
        case .centerBottom:
            return isFlipped ? .top : .bottom
        case .rightTop:
            return isFlipped ? .bottomRight : .topRight
        case .rightCenter:
            return .right
        case .rightBottom:
            return isFlipped ? .topRight : .bottomRight
        }
    }
}

extension Transform where Value == Double {
    var affineTransform: CGAffineTransform {
        return CGAffineTransform.identity
            .translatedBy(x: CGFloat(origin.x), y: CGFloat(origin.y))
            .translatedBy(x: CGFloat(translate.x), y: CGFloat(translate.y))
            .rotated(by: CGFloat(rotate))
            .scaledBy(x: CGFloat(scale), y: CGFloat(scale))
            .translatedBy(x: CGFloat(-origin.x), y: CGFloat(-origin.y))
    }
}
