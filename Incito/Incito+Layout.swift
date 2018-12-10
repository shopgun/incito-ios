//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

// MARK: -

struct AbsoluteLayoutProperties {
    var position: Edges<Double?>
    var margins: Edges<Double>
    var padding: Edges<Double>

    var maxWidth: Double
    var minWidth: Double
    var maxHeight: Double
    var minHeight: Double

    var height: Double? // nil if fitting to child
    var width: Double? // nil if fitting to child
}

extension AbsoluteLayoutProperties {
    init(_ properties: LayoutProperties, in parentSize: Size) {
        self.maxWidth = properties.maxWidth?.absolute(in: parentSize.width) ?? .infinity
        self.minWidth = properties.minWidth?.absolute(in: parentSize.width) ?? 0
        self.maxHeight = properties.maxHeight?.absolute(in: parentSize.height) ?? .infinity
        self.minHeight = properties.minHeight?.absolute(in: parentSize.height) ?? 0
        
        self.height = properties.height?.absolute(in: parentSize.height)
        self.width = properties.width?.absolute(in: parentSize.width)
        
        self.position = properties.position.absolute(in: parentSize)
        self.margins = properties.margins.absolute(in: parentSize)
        self.padding = properties.padding.absolute(in: parentSize)
    }
}

extension Double {
    func clamped(min: Double, max: Double) -> Double {
        return Swift.min(Swift.max(self, min), max)
    }
}

struct LayoutNode {
    var view: (id: String?, type: ViewType, style: StyleProperties)
    var rect: Rect
    var children: [LayoutNode]
}

enum LayoutType {
    case block      // Will fill the parent, and it's intrinsic size is not used. Views are stacked vertically.
    case absolute   // Uses the intrinsic size of the view, and positioned relative to the origin.
}

typealias ViewSizer = (View, Size) -> Size?

extension LayoutNode {
    static func build(for view: View, intrinsicSize: ViewSizer, parentLayout: LayoutType, in parentSize: Size) -> LayoutNode {
        
        let node: LayoutNode
        
        switch view.type {
        case .view:
            node = staticLayout(view: view, intrinsicSize: intrinsicSize, parentLayout: parentLayout, in: parentSize)
        case .absoluteLayout:
            node = absoluteLayout(view: view, intrinsicSize: intrinsicSize, parentLayout: parentLayout, in: parentSize)
        // TODO: flex layout type
        default:
            node = staticLayout(view: view, intrinsicSize: intrinsicSize, parentLayout: parentLayout, in: parentSize)
        }
        
        return node
    }
    
    static func build(rootView: View, intrinsicSize: ViewSizer, in parentSize: Size) -> LayoutNode {
        return .build(for: rootView, intrinsicSize: intrinsicSize, parentLayout: .block, in: parentSize)
    }
}

// MARK: - Absolute Layout

func absoluteLayout(view: View, intrinsicSize: ViewSizer, parentLayout: LayoutType, in parentSize: Size) -> LayoutNode {
    
    // make absolute versions of the layout properties based on the parentSize
    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: parentSize)

    let width: Double = {
        guard let w = absoluteLayout.width else {
            return parentSize.width
        }
        return w + absoluteLayout.padding.left + absoluteLayout.padding.right
    }()
    let height: Double = {
        return (absoluteLayout.height ?? 0) + absoluteLayout.padding.top + absoluteLayout.padding.bottom
    }()
    
    let size = Size(
        width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
        height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
    )
    
    var childNodes: [LayoutNode] = []
    for childView in view.children {
        
        var childNode = LayoutNode.build(
            for: childView,
            intrinsicSize: intrinsicSize,
            parentLayout: .absolute,
            in: size
        )
        
        let childLayout = AbsoluteLayoutProperties(childView.layout, in: size)

        if let left = childLayout.position.left {
            childNode.rect.origin.x += left
        } else if let right = childLayout.position.right {
            childNode.rect.origin.x = size.width - right - childNode.rect.size.width
        } else {
            childNode.rect.origin.x = absoluteLayout.padding.left
        }
        
        if let top = childLayout.position.top {
            childNode.rect.origin.y += top
        } else if let bottom = childLayout.position.bottom {
            childNode.rect.origin.y = size.height - bottom - childNode.rect.size.height
        } else {
            childNode.rect.origin.y = absoluteLayout.padding.top
        }
        
        // TODO: apply margins & padding
        childNodes.append(childNode)
    }
    
    let rect = Rect(
        origin: .zero,
        size: size
    )
    
    return LayoutNode(
        view: (view.id, view.type, view.style),
        rect: rect,
        children: childNodes
    )
}

// MARK: - Static Layout

/// Get the size of a leaf view. If the parent was positioned Absolutely then the
func leafViewSize(view: View, sizer: ViewSizer, containerSize: Size, parentLayoutType: LayoutType) -> Size {
    
    // make absolute versions of the layout properties based on the parentSize.
    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: containerSize)

    // how much room we have to fit the view into.
    let constraintSize = Size(
        width: (absoluteLayout.width ?? containerSize.width) - absoluteLayout.padding.left - absoluteLayout.padding.right,
        height: (absoluteLayout.height ?? containerSize.height) - absoluteLayout.padding.top - absoluteLayout.padding.bottom
    )
    
    // use the sizer to find the preferred contentSize of the View
    let contentSize = sizer(view, constraintSize)
    
    switch parentLayoutType {
    case .absolute:
        // if the parent is absolute, then dont make 100% wide by default. Instead use the left/right etc properties if available
        
        // TODO: padding?
        let width: Double = {
            if let w = absoluteLayout.width {
                // if a specific width is provided, just use that.
                return w
            } else if let left = absoluteLayout.position.left,
                let right = absoluteLayout.position.right {
                // if there are specific left & right then subtract them from parent width
                return containerSize.width - left - right
            } else {
                // otherwise just use the content's size
                return contentSize?.width ?? 0
            }
        }()
        
        let height: Double = {
            if let h = absoluteLayout.height {
                // if a specific height is provided, just use that.
                return h
            } else if let top = absoluteLayout.position.top,
                let bottom = absoluteLayout.position.bottom {
                // if there are specific top & bottom then subtract them from parent height
                return containerSize.height - top - bottom
            } else {
                // otherwise just use the content's size
                return contentSize?.height ?? 0
            }
        }()
        
        let size = Size(
            width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
        print("Abs:", view.id ?? "--", size)
        return size
    case .block:
        
        // parent is static. Try to use the specified width. Otherwise use the containerWidth
        let size = Size(
            width: (absoluteLayout.width ?? containerSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: (absoluteLayout.height ?? contentSize?.height ?? 0).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
        
        print("Block:", view.id ?? "--", size)
        
        return size
    }
}

/// Generate a LayoutNode for a View and it's children, fitting inside parentSize.
/// The LayoutNode's rect is sized, and it's children positioned, but it's origin is not modified eg. it's margin is not taken into account (that is the job of the parent node's layout method)
func staticLayout(view: View, intrinsicSize: ViewSizer, parentLayout: LayoutType, in parentSize: Size) -> LayoutNode {
    
    // make absolute versions of the layout properties based on the parentSize
    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: parentSize)
    
    var childNodes: [LayoutNode] = []
    let size: Size
    
    if view.children.isEmpty {
        size = leafViewSize(
            view: view,
            sizer: intrinsicSize,
            containerSize: parentSize,
            parentLayoutType: parentLayout
        )
    } else {
        // the size into which the children will try to fit.
        // subtracts the padding so they fit into a smaller space
        let fittingSize = Size(
            width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth) - absoluteLayout.padding.left - absoluteLayout.padding.right,
            height: (absoluteLayout.height ?? parentSize.height).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight) - absoluteLayout.padding.left - absoluteLayout.padding.right
        )
        
        // stack all children vertically
        var originY = absoluteLayout.padding.top
        var maxChildWidth: Double = 0
        for childView in view.children {
            
            var childNode = LayoutNode.build(
                for: childView,
                intrinsicSize: intrinsicSize,
                parentLayout: parentLayout,
                in: fittingSize
            )

            childNode.rect.origin.y += originY
            
            let childMargins = childView.layout.margins.absolute(in: fittingSize)
            
            childNodes.append(childNode)
            
            originY = childNode.rect.origin.y + childNode.rect.size.height + childMargins.bottom
            maxChildWidth = max(maxChildWidth, childNode.rect.size.width + childMargins.left + childMargins.right + absoluteLayout.padding.left + absoluteLayout.padding.right)
        }
        
        let totalChildHeight = originY + absoluteLayout.padding.bottom
        
        // use absolute size or fit to children
        size = Size(
            width: (absoluteLayout.width ?? maxChildWidth).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: (absoluteLayout.height ?? Double(totalChildHeight)).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
        
        // position the children horizontally now we know the size of the parent
        childNodes = childNodes.map {
            var childNode = $0
            
            switch view.layout.gravity {
            case .right?:
                // TODO: padding/margins?
                childNode.rect.origin.x = size.width - absoluteLayout.padding.right - childNode.rect.size.width
                
            case .left?:
                // TODO: different depending on gravity. Defaults to no gravity (system LtR or RtL)
                childNode.rect.origin.x += absoluteLayout.padding.left
                
            case .center?,
                 nil:
                childNode.rect.origin.x = (size.width / 2) - (childNode.rect.size.width / 2)
            }
            
            return childNode
        }
    }
    
    let rect = Rect(
        origin: Point( // TODO: move this to the parent
            x: absoluteLayout.margins.left,
            y: absoluteLayout.margins.top
        ),
        size: Size(
            width: size.width,
            height: size.height
        )
    )
    
    return LayoutNode(
        view: (view.id, view.type, view.style),
        rect: rect,
        children: childNodes
    )
}
