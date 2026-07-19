// BR2026Tests/Models/MatchLineupTests.swift
import Testing
import Foundation
@testable import BR2026

@Suite("MatchLineup decoding and mapping")
struct MatchLineupTests {
    // Real response for BSA match 1492295 (Fluminense vs RB Bragantino, round 19) — chosen
    // because the two teams' real kit colors are visually distinct and don't need the
    // WCAG-correction fallback, unlike Botafogo/Santos (covered by the next test).
    private let fluminenseVsBragantinoJSON = Data("""
    {
        "home": {
            "colors": { "fontColor": "ffffff", "mainColor": "6e202e", "secondaryColor": "6e202e" },
            "formation": "4-2-3-1",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Fábio", "number": 1, "position": "G" },
                { "col": 1, "row": 5, "name": "Hulk", "number": 7, "position": "F" }
            ],
            "substitutes": [
                { "name": "Backup GK", "number": 12, "position": "G" }
            ]
        },
        "away": {
            "colors": { "fontColor": "f50000", "mainColor": "fcfcfc", "secondaryColor": "fcfcfc" },
            "formation": "4-1-4-1",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Tiago Volpi", "number": 18, "position": "G" }
            ],
            "substitutes": []
        }
    }
    """.utf8)

    @Test("Decodes a lineups response and maps it to the display model")
    func decodesAndMaps() throws {
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: fluminenseVsBragantinoJSON)
        let lineup = MatchLineup(dto: dto)

        #expect(lineup.home.formation == "4-2-3-1")
        #expect(lineup.home.startingXI.count == 2)
        #expect(lineup.home.startingXI[0].name == "Fábio")
        #expect(lineup.home.startingXI[0].col == 1)
        #expect(lineup.home.startingXI[0].row == 1)
        #expect(lineup.home.substitutes.count == 1)
        #expect(lineup.home.substitutes[0].col == nil)
        #expect(lineup.home.substitutes[0].row == nil)
    }

    @Test("A passing kit color pair is used unchanged; a failing one is corrected")
    func kitColorsCorrectOnlyWhenFailing() throws {
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: fluminenseVsBragantinoJSON)
        let lineup = MatchLineup(dto: dto)

        // Fluminense: white on grenat, 11.0:1 — passes, unchanged.
        #expect(lineup.home.kitColorHex == "6e202e")
        #expect(lineup.home.kitFontColorHex == "ffffff")
        // Bragantino: red f50000 on white fcfcfc is only 4.19:1 — verified below the 4.5
        // WCAG AA threshold despite looking reasonable, so it's corrected to black
        // (20.5:1) rather than kept as the real API value. A useful reminder that "looks
        // fine" and "passes WCAG AA" aren't the same thing — always compute the ratio
        // rather than eyeballing a color pair, including during this feature's own design.
        #expect(lineup.away.kitColorHex == "fcfcfc")
        #expect(lineup.away.kitFontColorHex == "000000")
    }

    @Test("Kit font color is corrected when the real API value fails WCAG AA against the kit color")
    func kitFontColorCorrectedWhenFailing() throws {
        // Real response for BSA match 1492291 (Botafogo vs Santos): fontColor ffffff
        // against mainColor f7f7f7 — near-white on near-white, fails WCAG AA.
        let json = Data("""
        {
            "home": {
                "colors": { "fontColor": "ffffff", "mainColor": "f7f7f7", "secondaryColor": "f7f7f7" },
                "formation": "4-4-2",
                "startingXI": [ { "col": 1, "row": 1, "name": "Léo Linck", "number": 24, "position": "G" } ],
                "substitutes": []
            },
            "away": {
                "colors": { "fontColor": "000000", "mainColor": "ffffff", "secondaryColor": "ffffff" },
                "formation": "4-2-3-1",
                "startingXI": [ { "col": 1, "row": 1, "name": "Gabriel Brazão", "number": 77, "position": "G" } ],
                "substitutes": []
            }
        }
        """.utf8)
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: json)
        let lineup = MatchLineup(dto: dto)

        #expect(lineup.home.kitFontColorHex == "000000")
        // Away's real values (black on white) already pass — unchanged.
        #expect(lineup.away.kitFontColorHex == "000000")
    }

    @Test("Decodes a scheduled match's empty placeholder lineups response without crashing")
    func decodesScheduledMatchPlaceholderResponse() throws {
        // Real response for a not-yet-played BSA match: HTTP 200, empty formation/players,
        // and critically `"colors": null` — not omitted, not a 404. Confirmed directly
        // against the live backend.
        let json = Data("""
        {
            "home": { "formation": "", "startingXI": [], "substitutes": [], "colors": null },
            "away": { "formation": "", "startingXI": [], "substitutes": [], "colors": null }
        }
        """.utf8)
        let dto = try JSONDecoder().decode(MatchLineupDTO.self, from: json)
        let lineup = MatchLineup(dto: dto)

        #expect(lineup.home.startingXI.isEmpty)
        #expect(lineup.home.kitColorHex == "808080")
        // The "FFFFFF" fallback font candidate actually fails WCAG AA against the "808080"
        // fallback main color (3.95:1, below the 4.5 threshold — verified directly), so
        // accessibleColorHex corrects it to black (5.32:1) — exercising the same
        // correction path a real near-invisible per-match kit color would take.
        #expect(lineup.home.kitFontColorHex == "000000")
    }

    @Test("LineupPlayer's position letter maps to a full localized word")
    func positionAccessibilityLabels() {
        let goalkeeper = LineupPlayer(name: "Test", number: 1, position: "G", col: 1, row: 1)
        let defender = LineupPlayer(name: "Test", number: 2, position: "D", col: 1, row: 2)
        let midfielder = LineupPlayer(name: "Test", number: 3, position: "M", col: 1, row: 3)
        let forward = LineupPlayer(name: "Test", number: 4, position: "F", col: 1, row: 4)

        #expect(goalkeeper.positionAccessibilityLabel == "Goalkeeper")
        #expect(defender.positionAccessibilityLabel == "Defender")
        #expect(midfielder.positionAccessibilityLabel == "Midfielder")
        #expect(forward.positionAccessibilityLabel == "Forward")
    }
}
