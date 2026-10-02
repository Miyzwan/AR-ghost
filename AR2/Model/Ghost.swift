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

    /// Menentukan warna aksen UI saat wujud ini aktif.
    enum Mood {
        case cute, angry
    }

    /// Nama file .usdz di bundle.
    let id: String
    let name: LocalizedStringResource
    let lore: LocalizedStringResource
    let mood: Mood
    /// Gerak khas saat melayang.
    let style: MotionStyle
    /// Cerita interaktif di layar AR.
    let story: GhostStory
    let voice: GhostVoice
    /// Warna kilau partikel saat gestur berhasil (RGB 0...1).
    let glow: SIMD3<Float>
    let credit: Credit

    static func == (lhs: Ghost, rhs: Ghost) -> Bool {
        lhs.id == rhs.id
    }
}

enum GhostCatalog {
    /// Urutan wujud saat bertransformasi (berputar kembali ke awal). Ukurannya disamakan saat
    /// dimuat (`GhostSizing`), jadi file baru tidak perlu diskalakan manual.
    static let all: [Ghost] = [
        Ghost(
            id: "Cute_ghost",
            name: "Mister Q (The Cute Ghost)",
            lore: "Don't be fooled by his cute looks! He loves to settle on top of people's heads and slowly drain the sadness from their aura. If your head suddenly feels heavy, he might be the culprit...",
            mood: .cute,
            style: .bob,
            story: .misterQ,
            voice: GhostVoice(pitch: 1.25, cheer: "cheer_misterq", jingle: "jingle_misterq"),
            glow: [1.0, 0.6, 0.25],
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
            mood: .angry,
            style: .jitter,
            story: .trueForm,
            voice: GhostVoice(pitch: 0.6, cheer: "cheer_trueform", jingle: "jingle_trueform"),
            glow: [1.0, 0.15, 0.15],
            credit: Ghost.Credit(
                title: "Ghost Boy",
                author: "20174720",
                license: "CC BY 4.0",
                url: URL(string: "https://sketchfab.com/3d-models/ghost-boy-b74bfc1894b743c793ad9fb37085395f")!
            )
        ),
        Ghost(
            id: "Boo_ghost",
            name: "Boo Buddy",
            lore: "Boo always opens his arms for a hug. Sadly, every hug goes right through you, but he never stops trying.",
            mood: .cute,
            style: .hugSway,
            story: .boo,
            voice: GhostVoice(pitch: 1.1, cheer: "cheer_boo", jingle: "jingle_boo"),
            glow: [1.0, 0.55, 0.75],
            credit: Ghost.Credit(
                title: "Graveyard Kit: Ghost",
                author: "Kenney",
                license: "CC0 1.0",
                url: URL(string: "https://kenney.nl/assets/graveyard-kit")!
            )
        ),
        Ghost(
            id: "Wavy_ghost",
            name: "Wavy",
            lore: "Wavy waves at everyone he floats past. Nobody ever waves back, because nobody can see him... except you. Wave back!",
            mood: .cute,
            style: .wave,
            story: .wavy,
            voice: GhostVoice(pitch: 1.4, cheer: "cheer_wavy", jingle: "jingle_wavy"),
            glow: [0.6, 0.95, 1.0],
            credit: Ghost.Credit(
                title: "Ghoooooost",
                author: "Nikki Morin",
                license: "CC BY 3.0",
                url: URL(string: "https://poly.pizza/m/112vpcommxv")!
            )
        ),
        Ghost(
            id: "Mochi_ghost",
            name: "Mochi the Ghost Cat",
            lore: "Mochi loved napping so much that she kept doing it in the afterlife. Her ears still twitch whenever someone opens a can of tuna.",
            mood: .cute,
            style: .nap,
            story: .mochi,
            voice: GhostVoice(pitch: 1.7, cheer: "cheer_mochi", jingle: "jingle_mochi"),
            glow: [1.0, 0.8, 0.6],
            credit: Ghost.Credit(
                title: "Low Poly Halloween Kit: Ghost 3",
                author: "Asset Quest",
                license: "CC0 1.0",
                url: URL(string: "https://opengameart.org/content/low-poly-halloween-kit")!
            )
        ),
        Ghost(
            id: "Nori_ghost",
            name: "Nori the Shadow Cat",
            lore: "Mochi's twin sister prefers dark corners. Her glowing eyes look spooky, but she only wants to knock your things off the table.",
            mood: .cute,
            style: .sneak,
            story: .nori,
            voice: GhostVoice(pitch: 1.5, cheer: "cheer_nori", jingle: "jingle_nori"),
            glow: [0.7, 0.4, 1.0],
            credit: Ghost.Credit(
                title: "Low Poly Halloween Kit: Ghost 4",
                author: "Asset Quest",
                license: "CC0 1.0",
                url: URL(string: "https://opengameart.org/content/low-poly-halloween-kit")!
            )
        ),
        Ghost(
            id: "Witch_ghost",
            name: "Little Witch",
            lore: "A tiny witch who never learned to steer her broom, so she just flies in circles. Her spells mostly turn tea into slightly colder tea.",
            mood: .cute,
            style: .orbit,
            story: .witch,
            voice: GhostVoice(pitch: 1.6, cheer: "cheer_witch", jingle: "jingle_witch"),
            glow: [0.5, 1.0, 0.5],
            credit: Ghost.Credit(
                title: "Low Poly Halloween Kit: Character 2",
                author: "Asset Quest",
                license: "CC0 1.0",
                url: URL(string: "https://opengameart.org/content/low-poly-halloween-kit")!
            )
        ),
        Ghost(
            id: "Reaper_ghost",
            name: "Sir Reaper",
            lore: "The most polite reaper in the underworld. He always tips his hat first, and he only uses his scythe to trim the graveyard grass.",
            mood: .cute,
            style: .glideBow,
            story: .reaper,
            voice: GhostVoice(pitch: 0.75, cheer: "cheer_reaper", jingle: "jingle_reaper"),
            glow: [0.85, 0.85, 0.95],
            credit: Ghost.Credit(
                title: "Low Poly Halloween Kit: Character 1",
                author: "Asset Quest",
                license: "CC0 1.0",
                url: URL(string: "https://opengameart.org/content/low-poly-halloween-kit")!
            )
        ),
        Ghost(
            id: "Captain_ghost",
            name: "Captain Boo",
            lore: "A pirate ghost who lost his ship, his crew, and his map. He kept the hat, though, and he still shouts \"Arrr!\" at every bathtub he sees.",
            mood: .cute,
            style: .rocking,
            story: .captain,
            voice: GhostVoice(pitch: 0.85, cheer: "cheer_captain", jingle: "jingle_captain"),
            glow: [1.0, 0.85, 0.3],
            credit: Ghost.Credit(
                title: "Low Poly Halloween Kit: Ghost 1 + Pirate Hat",
                author: "Asset Quest",
                license: "CC0 1.0",
                url: URL(string: "https://opengameart.org/content/low-poly-halloween-kit")!
            )
        ),
        Ghost(
            id: "Pixel_ghost",
            name: "Pixel",
            lore: "Pixel escaped from an old arcade game. He still thinks in squares, and he jumps whenever he hears a coin drop into a machine.",
            mood: .cute,
            style: .pixelStep,
            story: .pixel,
            voice: GhostVoice(blip: "sfx_voice_8bit", pitch: 1.0, cheer: "cheer_pixel", jingle: "jingle_pixel"),
            glow: [0.3, 0.6, 1.0],
            credit: Ghost.Credit(
                title: "Low Poly Ghost",
                author: "Robin Lamb",
                license: "CC0 1.0",
                url: URL(string: "https://opengameart.org/content/low-poly-ghost-0")!
            )
        ),
    ]

    /// Posisi hantu dengan `id` tersebut; kembali ke hantu pertama jika tidak dikenal
    /// (misalnya pilihan lama di UserDefaults untuk wujud yang sudah dihapus).
    static func index(ofID id: String) -> Int {
        all.firstIndex { $0.id == id } ?? 0
    }

    static func ghost(withID id: String) -> Ghost {
        all[index(ofID: id)]
    }

    /// Wujud berikutnya saat bertransformasi, berputar kembali ke awal.
    static func index(after index: Int) -> Int {
        (index + 1) % all.count
    }
}
