//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension UIView {
    func recursiveSubviewCount(where predicate: (UIView) -> Bool = { _ in true }) -> Int {
        return self.subviews.reduce(1) {
            if predicate($1) {
                return $0 + $1.recursiveSubviewCount(where: predicate)
            } else {
                return $0
            }
        }
    }
}