//
//  DiscoverUtil.swift
//  AppDiscover
//
//  Created by Archer on 2018/11/20.
//

import Foundation

class AppDiscoverBunbleLoader: NSObject {}

extension Bundle {
    static var resourcesBundle: Bundle? {
        var path = Bundle(for: AppDiscoverBunbleLoader.self).resourcePath ?? ""
        path.append("/AppDiscover.bundle")
        return Bundle(path: path)
    }
}

extension UIImage {
    convenience init?(nameInBundle name: String) {
        self.init(named: name, in: .resourcesBundle, compatibleWith: nil)
    }
}