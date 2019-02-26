//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

/**
 If you wish to use your own image data cache/loader, implement this protocol and assign it to the IncitoEnvironment.
 */
public protocol ImageLoaderProtocol {
    func imageData(forURL url: URL, containerSize: Size<Double>, completion: @escaping (Result<(data: Data, mimeType: String?)>) -> Void)
}

/**
 If you wish to use your own font data cache/loader, implement this protocol and assign it to the IncitoEnvironment.
 */
public protocol FontLoaderProtocol {
    func fontData(forURL url: URL, completion: @escaping (Result<Data>) -> Void)
}

public struct IncitoEnvironment {
    /// A list of all the incito schema versions supported by this library.
    public static let supportedVersions: [String] = ["1.0.0"]

    /**
     This is used by the Incito renderer to download url-based image data. The mimeType is needed to decide how to render the image.
     
     The default implementation uses `IncitoDataStore.shared`. This has a disk & memory cache.
     */
    public var imageLoader: ImageLoaderProtocol = IncitoDataStore.shared
    
    /**
     This is used by the Incito renderer to download url-based font data.
     
     The default implementation uses `IncitoDataStore.shared`. This has a disk & memory cache.
     */
    public var fontLoader: FontLoaderProtocol = IncitoDataStore.shared
}

extension IncitoEnvironment {
    public static var current = IncitoEnvironment()
}
