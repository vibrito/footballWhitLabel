import Foundation

enum MockDataProvider {
    static let matchesJSON = """
    {
        "matches": [
            {
                "id": 1492111,
                "utcDate": "2026-01-30T00:30:00+00:00",
                "status": "FINISHED",
                "matchday": 1,
                "stage": "REGULAR_SEASON",
                "homeTeam": { "id": 120, "tla": null, "name": "Botafogo", "crest": "https://media.api-sports.io/football/teams/120.png", "shortName": "Botafogo" },
                "awayTeam": { "id": 135, "tla": null, "name": "Cruzeiro", "crest": "https://media.api-sports.io/football/teams/135.png", "shortName": "Cruzeiro" },
                "score": { "winner": "HOME_TEAM", "fullTime": { "away": 0, "home": 4 }, "halfTime": { "away": 0, "home": 0 } },
                "venue": "Estadio Olimpico Nilton Santos",
                "minute": 90
            },
            {
                "id": 1492140,
                "utcDate": "2026-07-17T22:30:00+00:00",
                "status": "SCHEDULED",
                "matchday": 4,
                "stage": "REGULAR_SEASON",
                "homeTeam": { "id": 118, "tla": null, "name": "Bahia", "crest": "https://media.api-sports.io/football/teams/118.png", "shortName": "Bahia" },
                "awayTeam": { "id": 132, "tla": null, "name": "Chapecoense-sc", "crest": "https://media.api-sports.io/football/teams/132.png", "shortName": "Chapecoense-sc" },
                "score": { "winner": null, "fullTime": { "away": null, "home": null }, "halfTime": { "away": null, "home": null } },
                "venue": "Arena Fonte Nova",
                "minute": null
            },
            {
                "id": 1492145,
                "utcDate": "2026-02-25T21:00:00+00:00",
                "status": "POSTPONED",
                "matchday": 4,
                "stage": "REGULAR_SEASON",
                "homeTeam": { "id": 127, "tla": null, "name": "Flamengo", "crest": "https://media.api-sports.io/football/teams/127.png", "shortName": "Flamengo" },
                "awayTeam": { "id": 7848, "tla": null, "name": "Mirassol", "crest": "https://media.api-sports.io/football/teams/7848.png", "shortName": "Mirassol" },
                "score": { "winner": null, "fullTime": { "away": null, "home": null }, "halfTime": { "away": null, "home": null } },
                "venue": null,
                "minute": null
            }
        ]
    }
    """

    static let standingsJSON = """
    {
        "standings": [
            {
                "position": 1,
                "team": { "id": 121, "tla": null, "name": "Palmeiras", "crest": "https://media.api-sports.io/football/teams/121.png", "shortName": "Palmeiras" },
                "playedGames": 15, "won": 12, "draw": 5, "lost": 1,
                "goalsFor": 41, "goalsAgainst": 18, "goalDifference": 23, "points": 41
            },
            {
                "position": 2,
                "team": { "id": 127, "tla": null, "name": "Flamengo", "crest": "https://media.api-sports.io/football/teams/127.png", "shortName": "Flamengo" },
                "playedGames": 15, "won": 10, "draw": 4, "lost": 1,
                "goalsFor": 34, "goalsAgainst": 19, "goalDifference": 15, "points": 34
            },
            {
                "position": 3,
                "team": { "id": 119, "tla": null, "name": "Internacional", "crest": "https://media.api-sports.io/football/teams/119.png", "shortName": "Internacional" },
                "playedGames": 15, "won": 9, "draw": 4, "lost": 2,
                "goalsFor": 26, "goalsAgainst": 15, "goalDifference": 11, "points": 31
            }
        ]
    }
    """
}
