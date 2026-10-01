//
//  GhostCatalogTests.swift
//  AR2Tests
//

import Foundation
import Testing
@testable import AR2

struct GhostSizingTests {
    @Test func tallModelIsScaledToTargetHeight() {
        let factor = GhostSizing.scale(forExtents: [50, 200, 40], height: 0.2)
        #expect(abs(200 * factor - 0.2) < 0.0001)
    }

    @Test func dioramaBaseKeepsTheSameHeight() {
        // Mister Q: alas diorama 1,75× lebih lebar dari tingginya, tetap disamakan tingginya
        let factor = GhostSizing.scale(forExtents: [506, 300, 524], height: 0.2)
        #expect(abs(300 * factor - 0.2) < 0.0001)
    }

    @Test func veryWideModelIsLimitedByWidth() {
        let factor = GhostSizing.scale(forExtents: [900, 300, 100], height: 0.2)
        #expect(abs(900 * factor - 0.2 * GhostSizing.maxWidthRatio) < 0.0001)
        #expect(300 * factor < 0.2)
    }

    @Test func flatModelDoesNotDivideByZero() {
        let factor = GhostSizing.scale(forExtents: [0, 0, 0], height: 0.2)
        #expect(factor.isFinite)
    }
}

struct GhostCatalogTests {
    @Test func hasTenUniqueGhosts() {
        #expect(GhostCatalog.all.count == 10)
        #expect(Set(GhostCatalog.all.map(\.id)).count == GhostCatalog.all.count)
    }

    @Test func everyModelIsInTheBundle() {
        let bundle = Bundle(for: GhostARModel.self)
        for ghost in GhostCatalog.all {
            #expect(bundle.url(forResource: ghost.id, withExtension: "usdz") != nil, "\(ghost.id).usdz hilang")
        }
    }

    @Test func unknownIDFallsBackToFirstGhost() {
        #expect(GhostCatalog.index(ofID: "bukan-hantu") == 0)
        #expect(GhostCatalog.index(ofID: GhostCatalog.all[3].id) == 3)
    }

    @Test func nextWrapsAround() {
        #expect(GhostCatalog.index(after: GhostCatalog.all.count - 1) == 0)
        #expect(GhostCatalog.index(after: 0) == 1)
    }
}
