//
//  Log.swift
//  AR2
//

import os

// Logger terpusat. `nonisolated` supaya bisa dipakai dari antrean Vision di background.
extension Logger {
    nonisolated private static let subsystem = "AR2"

    nonisolated static let audio = Logger(subsystem: subsystem, category: "audio")
    nonisolated static let ar = Logger(subsystem: subsystem, category: "ar")
    nonisolated static let vision = Logger(subsystem: subsystem, category: "vision")
}
