//
//  URUtils.swift
//  URKit
//
//  Created by Wolf McNally on 7/4/20.
//

import Foundation

extension Character {
    var isURType: Bool {
        if "a" <= self && self <= "z" { return true }
        if "0" <= self && self <= "9" { return true }
        if self == "-" { return true }
        return false
    }
}

extension String {
    var isURType: Bool { allSatisfy { $0.isURType } }
}
