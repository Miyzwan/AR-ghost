//
//  Ghost.swift
//  AR2
//

import Foundation

/// Satu wujud hantu beserta model 3D-nya.
struct Ghost: Identifiable, Equatable {
    struct Credit {
        let title: String
        let author: String
        let license: String
        let url: URL
    }

    /// Nama file .usdz di bundle.
    let id: String
    let name: LocalizedStringResource
    let lore: LocalizedStringResource
    /// Tinggi hantu (meter) di atas kepala pada mode wajah.
    let faceHeight: Float
    /// Tinggi hantu (meter) di atas permukaan pada mode dunia.
    let worldHeight: Float
    let credit: Credit

    static func == (lhs: Ghost, rhs: Ghost) -> Bool {
        lhs.id == rhs.id
    }
}

enum GhostCatalog {
    /// Urutan wujud saat bertransformasi (berputar kembali ke awal).
    static let all: [Ghost] = [
        Ghost(
            id: "Cute_ghost",
            name: "Mister Q (The Cute Ghost)",
            lore: "Don't be fooled by his cute looks! He loves to settle on top of people's heads and slowly drain the sadness from their aura. If your head suddenly feels heavy, he might be the culprit...",
            faceHeight: 0.15,
            worldHeight: 0.35,
            credit: Ghost.Credit(
                title: "Cute ghost",
                author: "P3D",
                license: "CC BY 4.0",
                url: URL(string: "https://sketchfab.com/3d-models/cute-ghost-2c8c03bb0e5049529e653f9011a8fc90")!
            )
        ),
        Ghost(
            id: "Scary_ghost",
            name: "Mister Q (True Form)",
            lore: "This is what Mister Q really looks like when he's angry. Clap again quickly, maybe he'll turn cute again...",
            faceHeight: 0.27,
            worldHeight: 0.6,
            credit: Ghost.Credit(
                title: "Ghost Boy",
                author: "20174720",
                license: "CC BY 4.0",
                url: URL(string: "https://sketchfab.com/3d-models/ghost-boy-b74bfc1894b743c793ad9fb37085395f")!
            )
        ),
    ]
}
