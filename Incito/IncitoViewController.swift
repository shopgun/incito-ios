//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

/**
 possible delegate methods:
 - configure scrollView
 */

class IncitoViewController: UIViewController {
    
    let scrollView = UIScrollView()
    
    let incitoDocument: Incito
    
    var rootView: UIView?
    var renderableSections: [RenderableSection] = []
    var rootLayoutNode: LayoutNode?
    var renderer: IncitoRenderer
    
    init(incito: Incito) {
        self.incitoDocument = incito
        self.renderer = IncitoRenderer(
            fontProvider: UIFont.systemFont(forFamily:size:),
            imageLoader: loadImage(url:completion:),
            theme: incitoDocument.theme
        )
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // configure the scrollView
        view.addSubview(scrollView)
        
        scrollView.delegate = self
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .always
        }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        
        scrollView.backgroundColor = incitoDocument.theme?.bgColor?.uiColor ?? .white
        
        let fontAssets = self.incitoDocument.fontAssets

        queue.async { [weak self] in
            self?.loadFonts(fontAssets: fontAssets)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        renderVisibleSections()
    }
    
    
    let queue = DispatchQueue(label: "IncitoViewControllerQueue")
    
    func loadFonts(fontAssets: [FontAssetName: FontAsset]) {
        
        let fontLoader = FontAssetLoader.uiKitFontAssetLoader()
        
        let startFontLoad = Date.timeIntervalSinceReferenceDate
        fontLoader.loadAndRegisterFontAssets(fontAssets) { [weak self] (loadedAssets) in
            
            let endFontLoad = Date.timeIntervalSinceReferenceDate
            print(" ⇢ 🔠 Downloaded font assets: \(loadedAssets.count) in \(round((endFontLoad - startFontLoad) * 1_000))ms")
            loadedAssets.forEach { asset in
                print("    ‣ '\(asset.assetName)': \(asset.fontName)")
            }
            
            DispatchQueue.main.async { [weak self] in
                
                // update the renderer's fontProvider
                self?.renderer.fontProvider = loadedAssets.font(forFamily:size:)
                
                // build complete layout
                self?.buildLayout()
            }
        }
    }
    
    // must call from main
    func buildLayout() {
        
        let rootIncitoView: View = incitoDocument.rootView
        let fontProvider = self.renderer.fontProvider
        let defaultTextProperties = incitoDocument.theme?.textDefaults ?? .empty
        let parentSize = Size(cgSize: self.view.frame.size)

        let start = Date.timeIntervalSinceReferenceDate
        // build the layout
        let rootLayoutNode = LayoutNode.build(
            rootView: rootIncitoView,
            intrinsicSize: uiKitViewSizer(fontProvider, defaultTextProperties),
            in: parentSize
        )
        
        let end = Date.timeIntervalSinceReferenceDate
        print(" ⇢ 🚧 Built layout graph: \(round((end - start) * 1_000))ms")
        
        DispatchQueue.main.async { [weak self] in
            self?.initializeRootView(rootLayoutNode: rootLayoutNode)
        }
    }
    
    func initializeRootView(rootLayoutNode: LayoutNode) {
        
        
        self.rootLayoutNode = rootLayoutNode
        
        // TODO: Load the imageReqs
        // build (just) the rootView
        let (rootView, imageReqs) = UIView.build(rootLayoutNode,
                                    renderer: self.renderer,
                                    maxDepth: 0)
        
        self.rootView = rootView

        let viewBuilder = viewHierarchyBuilder(self.renderer)
        
        self.renderableSections = rootLayoutNode.children.map {
            RenderableSection(
                layoutNode: $0,
                viewBuilder: viewBuilder,
                imageLoader: renderer.imageLoader
            )
        }
        
        let wrapper = UIView()
        wrapper.addSubview(rootView)
        scrollView.addSubview(wrapper)
        
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: scrollView.topAnchor),
            wrapper.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            wrapper.leftAnchor.constraint(greaterThanOrEqualTo: scrollView.leftAnchor),
            wrapper.rightAnchor.constraint(lessThanOrEqualTo: scrollView.rightAnchor),
            wrapper.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            
            wrapper.heightAnchor.constraint(equalToConstant: rootView.frame.size.height),
            wrapper.widthAnchor.constraint(equalToConstant: rootView.frame.size.width)
            ])
        
        renderVisibleSections()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // `unrender` all the rendered RenderableSections (prioritizing those above)
        
        
    }
    
    var lastRenderedWindow: CGRect?
    
    func renderVisibleSections() {
        
        guard let rootView = self.rootView else {
            return
        }
        
        // TODO: this is DEBUG to make lazy loading obvious
        let scrollVisibleWindow = scrollView.bounds
//            .inset(by: UIEdgeInsets(top: 200, left: 0, bottom: 200, right: 0))
            .inset(by: UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0))
        
        let renderWindow = scrollView.convert(scrollVisibleWindow, to: rootView)
        
        // dont do rendercheck until we've scrolled a certain amount
        if let lastRendered = self.lastRenderedWindow,
            abs(lastRendered.origin.y - renderWindow.origin.y) < 50 {
            return
        }
        
        self.lastRenderedWindow = renderWindow
        
        for renderableSection in renderableSections {
            // just render all of them
            //            renderableSection.render(into: rootView)
            
            if renderWindow.intersects(renderableSection.layoutNode.rect.cgRect) {
                renderableSection.render(into: rootView)
            } else {
                // TODO: only unrender on memory pressure or if rendered section count gets large
                renderableSection.unrender()
            }
        }
    }
}
extension IncitoViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        renderVisibleSections()
    }
}

/// Given a renderer it will return a ViewBuilder that builds the entire view hierarchy.
let viewHierarchyBuilder: (IncitoRenderer) -> (LayoutNode) -> (UIView, [ImageLoadRequest]) = { renderer in
    return { layoutNode in
        return UIView.build(layoutNode, renderer: renderer, depth: 0, maxDepth: nil)
    }
}

class RenderableSection {
    let layoutNode: LayoutNode
    let viewBuilder: (LayoutNode) -> (UIView, [ImageLoadRequest])
    let imageLoader: ImageLoader
    
    var renderedView: UIView? = nil
//    var pendingImageLoadRequests: [ImageLoadRequest] = []
    
    init(layoutNode: LayoutNode, viewBuilder: @escaping (LayoutNode) -> (UIView, [ImageLoadRequest]), imageLoader: @escaping ImageLoader) {
        self.layoutNode = layoutNode
        self.viewBuilder = viewBuilder
        self.imageLoader = imageLoader
    }
    
    func unrender() {
        self.renderedView?.removeFromSuperview()
        self.renderedView = nil
    }
    
    func render(into parentView: UIView) {
        // TODO: a 'force' option to refresh the view?
        guard renderedView == nil else {
            return
        }
        
        let (view, imgReqs) = self.viewBuilder(self.layoutNode)
        self.renderedView = view
        
        parentView.addSubview(view)
        
        print(" ⇢ 🎨 Lazily Rendering Section (\(imgReqs.count) images)", self.layoutNode.rect.origin)
        
        // TODO: some kind of cancellation strategy
//        self.pendingImageLoadRequests = imgReqs
        
        let start = Date.timeIntervalSinceReferenceDate
        
        let pendingReqCount = imgReqs.count
        var completedReqs: (success: Int, err: Int) = (0, 0)
        for req in imgReqs {
            self.imageLoader(req.url) {
                req.completion($0)
                
                if $0 == nil {
                    completedReqs.err += 1
                } else {
                    completedReqs.success += 1
                }
                
                if (completedReqs.err + completedReqs.success) == pendingReqCount {
                    
                    
                    let end = Date.timeIntervalSinceReferenceDate
                    
                    print("    ‣ Images loaded: \(pendingReqCount) images in \(round((end - start) * 1_000))ms (\(completedReqs.success)x ✅,  \(completedReqs.err)x ❌)")
                }
            }
        }
    }
}
