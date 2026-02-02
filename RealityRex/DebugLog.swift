//
//  DebugLog.swift
//  RealityRex
//
//  Lightweight debug logger (toggle enabled to silence).
//

import Foundation

enum DebugLog {
    static var enabled = true

    static func log(_ message: String, category: String = "General") {
        guard enabled else { return }
        print("[\(category)] \(message)")
    }
}
