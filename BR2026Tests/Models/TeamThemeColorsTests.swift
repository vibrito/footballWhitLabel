import Testing
import Foundation
@testable import BR2026

@Suite("TeamThemeColors decoding")
struct TeamThemeColorsTests {
    private let json = """
    {
      "team": {"id": 121, "name": "Palmeiras"},
      "home": {"fontColor": "ffffff", "mainColor": "225638", "secondaryColor": "225638", "matchesConsidered": 15},
      "away": {"fontColor": "035336", "mainColor": "ffffff", "secondaryColor": "ffffff", "matchesConsidered": 1},
      "third": {"fontColor": "2c5434", "mainColor": "ffffff", "secondaryColor": "ffffff", "matchesConsidered": 1}
    }
    """.data(using: .utf8)!

    @Test("Decodes all 3 kits from the live wire shape, ignoring secondaryColor/matchesConsidered/team")
    func decodesAllThreeKits() throws {
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: json)
        let colorSet = TeamThemeColorSet(response: response)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "225638", fontColorHex: "ffffff"))
        #expect(colorSet.away == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"))
        #expect(colorSet.third == TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434"))
    }

    @Test("Subscripting by TeamKit returns the matching kit's colors")
    func subscriptByKit() throws {
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: json)
        let colorSet = TeamThemeColorSet(response: response)

        #expect(colorSet[.home] == colorSet.home)
        #expect(colorSet[.away] == colorSet.away)
        #expect(colorSet[.third] == colorSet.third)
    }

    @Test("TeamThemeColorCache round-trips a TeamThemeColorSet through its colorSet property")
    func cacheRoundTrips() throws {
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: json)
        let colorSet = TeamThemeColorSet(response: response)
        let cache = TeamThemeColorCache(teamID: 121, colors: colorSet)

        #expect(cache.teamID == 121)
        #expect(cache.colorSet == colorSet)
    }

    @Test("Decodes a response with null away/third (the real shape for some teams, e.g. Flamengo) without throwing")
    func decodesWithNullAwayAndThird() throws {
        let flamengoJSON = """
        {
          "team": {"id": 127, "name": "Flamengo"},
          "home": {"fontColor": "ffffff", "mainColor": "ab1b10", "secondaryColor": "ab1b10", "matchesConsidered": 17},
          "away": null,
          "third": null
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(TeamThemeColorsResponse.self, from: flamengoJSON)
        let colorSet = TeamThemeColorSet(response: response)

        #expect(colorSet.home == TeamThemeColors(mainColorHex: "ab1b10", fontColorHex: "ffffff"))
        #expect(colorSet.away == nil)
        #expect(colorSet.third == nil)

        let cache = TeamThemeColorCache(teamID: 127, colors: colorSet)
        #expect(cache.colorSet == colorSet)
    }
}
