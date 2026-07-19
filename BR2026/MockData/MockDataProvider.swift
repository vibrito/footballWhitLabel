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

    static let eventsJSON = """
    {
        "events": [
            { "team": "home", "type": "YELLOW_CARD", "assist": null, "detail": "Yellow Card", "minute": 17, "player": "R. Dias", "playerOut": null, "extraMinute": null },
            { "team": "away", "type": "SUBSTITUTION", "assist": null, "detail": "Substitution 1", "minute": 46, "player": "A. Budimir", "playerOut": "I. Matanovic", "extraMinute": null },
            { "team": "away", "type": "GOAL", "assist": null, "detail": "Normal Goal", "minute": 53, "player": "I. Perisic", "playerOut": null, "extraMinute": null },
            { "team": "home", "type": "GOAL", "assist": null, "detail": "Penalty", "minute": 68, "player": "C. Ronaldo", "playerOut": null, "extraMinute": null }
        ]
    }
    """

    static let statisticsJSON = """
    {
        "home": { "fouls": 10, "shots": 17, "corners": 5, "possession": 48, "passAccuracy": 81, "shotsOnTarget": 7 },
        "away": { "fouls": 13, "shots": 22, "corners": 5, "possession": 52, "passAccuracy": 79, "shotsOnTarget": 9 }
    }
    """

    static let lineupsJSON = """
    {
        "home": {
            "colors": { "fontColor": "ffffff", "mainColor": "1e1e20", "secondaryColor": "1e1e20" },
            "formation": "4-4-2",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Léo Linck", "number": 24, "position": "G" },
                { "col": 4, "row": 2, "name": "Vitinho", "number": 2, "position": "D" },
                { "col": 3, "row": 2, "name": "Gabriel Justino", "number": 34, "position": "D" },
                { "col": 2, "row": 2, "name": "Nahuel Ferraresi", "number": 5, "position": "D" },
                { "col": 1, "row": 2, "name": "Alex Telles", "number": 13, "position": "D" },
                { "col": 4, "row": 3, "name": "Lucas Villalba", "number": 77, "position": "M" },
                { "col": 3, "row": 3, "name": "Huguinho", "number": 75, "position": "M" },
                { "col": 2, "row": 3, "name": "Marlon Freitas", "number": 8, "position": "M" },
                { "col": 1, "row": 3, "name": "Allan", "number": 14, "position": "M" },
                { "col": 2, "row": 4, "name": "Chris Ramos", "number": 19, "position": "F" },
                { "col": 1, "row": 4, "name": "Igor Jesus", "number": 9, "position": "F" }
            ],
            "substitutes": [
                { "name": "Diogenes", "number": 1, "position": "G" },
                { "name": "Adonis Frías", "number": 98, "position": "D" },
                { "name": "Gabriel Menino", "number": 25, "position": "M" }
            ]
        },
        "away": {
            "colors": { "fontColor": "000000", "mainColor": "ffffff", "secondaryColor": "ffffff" },
            "formation": "4-2-3-1",
            "startingXI": [
                { "col": 1, "row": 1, "name": "Gabriel Brazão", "number": 77, "position": "G" },
                { "col": 4, "row": 2, "name": "Igor Vinícius", "number": 18, "position": "D" },
                { "col": 3, "row": 2, "name": "Lucas Veríssimo", "number": 4, "position": "D" },
                { "col": 2, "row": 2, "name": "Luan Peres", "number": 14, "position": "D" },
                { "col": 1, "row": 2, "name": "Gonzalo Escobar", "number": 31, "position": "D" },
                { "col": 2, "row": 3, "name": "Gustavo Henrique Pereira", "number": 48, "position": "M" },
                { "col": 1, "row": 3, "name": "Willian Arão", "number": 15, "position": "M" },
                { "col": 3, "row": 4, "name": "Miguelito", "number": 30, "position": "M" },
                { "col": 2, "row": 4, "name": "Benjamín Rollheiser", "number": 32, "position": "M" },
                { "col": 1, "row": 4, "name": "Álvaro Barreal", "number": 22, "position": "M" },
                { "col": 1, "row": 5, "name": "Thaciano", "number": 16, "position": "F" }
            ],
            "substitutes": [
                { "name": "João Paulo Ananias", "number": 26, "position": "D" },
                { "name": "Rony", "number": 11, "position": "F" }
            ]
        }
    }
    """

    static let competitionJSON = """
    {
        "code": "BSA",
        "name": "Campeonato Brasileiro Série A",
        "season": 2026,
        "logo": "https://media.api-sports.io/football/leagues/71.png"
    }
    """

    static let standingsJSON = """
    {
        "standings": [
            {
                "position": 1,
                "team": { "id": 121, "tla": null, "name": "Palmeiras", "crest": "https://media.api-sports.io/football/teams/121.png", "shortName": "Palmeiras" },
                "playedGames": 15, "won": 10, "draw": 3, "lost": 2,
                "goalsFor": 30, "goalsAgainst": 12, "goalDifference": 18, "points": 33,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
            {
                "position": 2,
                "team": { "id": 127, "tla": null, "name": "Flamengo", "crest": "https://media.api-sports.io/football/teams/127.png", "shortName": "Flamengo" },
                "playedGames": 15, "won": 9, "draw": 4, "lost": 2,
                "goalsFor": 28, "goalsAgainst": 14, "goalDifference": 14, "points": 31,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
            {
                "position": 3,
                "team": { "id": 119, "tla": null, "name": "Internacional", "crest": "https://media.api-sports.io/football/teams/119.png", "shortName": "Internacional" },
                "playedGames": 15, "won": 8, "draw": 5, "lost": 2,
                "goalsFor": 25, "goalsAgainst": 15, "goalDifference": 10, "points": 29,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
            {
                "position": 4,
                "team": { "id": 120, "tla": null, "name": "Botafogo", "crest": "https://media.api-sports.io/football/teams/120.png", "shortName": "Botafogo" },
                "playedGames": 15, "won": 8, "draw": 4, "lost": 3,
                "goalsFor": 24, "goalsAgainst": 16, "goalDifference": 8, "points": 28,
                "description": "Promotion - Copa Libertadores (Group Stage)"
            },
            {
                "position": 5,
                "team": { "id": 126, "tla": null, "name": "São Paulo", "crest": "https://media.api-sports.io/football/teams/126.png", "shortName": "São Paulo" },
                "playedGames": 15, "won": 8, "draw": 3, "lost": 4,
                "goalsFor": 22, "goalsAgainst": 17, "goalDifference": 5, "points": 27,
                "description": "Promotion - Copa Libertadores (Qualification)"
            },
            {
                "position": 6,
                "team": { "id": 131, "tla": null, "name": "Corinthians", "crest": "https://media.api-sports.io/football/teams/131.png", "shortName": "Corinthians" },
                "playedGames": 15, "won": 7, "draw": 5, "lost": 3,
                "goalsFor": 21, "goalsAgainst": 16, "goalDifference": 5, "points": 26,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
            {
                "position": 7,
                "team": { "id": 135, "tla": null, "name": "Cruzeiro", "crest": "https://media.api-sports.io/football/teams/135.png", "shortName": "Cruzeiro" },
                "playedGames": 15, "won": 7, "draw": 4, "lost": 4,
                "goalsFor": 20, "goalsAgainst": 17, "goalDifference": 3, "points": 25,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
            {
                "position": 8,
                "team": { "id": 1062, "tla": null, "name": "Atlético-MG", "crest": "https://media.api-sports.io/football/teams/1062.png", "shortName": "Atlético-MG" },
                "playedGames": 15, "won": 7, "draw": 3, "lost": 5,
                "goalsFor": 19, "goalsAgainst": 18, "goalDifference": 1, "points": 24,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
            {
                "position": 9,
                "team": { "id": 118, "tla": null, "name": "Bahia", "crest": "https://media.api-sports.io/football/teams/118.png", "shortName": "Bahia" },
                "playedGames": 15, "won": 6, "draw": 5, "lost": 4,
                "goalsFor": 18, "goalsAgainst": 17, "goalDifference": 1, "points": 23,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
            {
                "position": 10,
                "team": { "id": 124, "tla": null, "name": "Fluminense", "crest": "https://media.api-sports.io/football/teams/124.png", "shortName": "Fluminense" },
                "playedGames": 15, "won": 6, "draw": 4, "lost": 5,
                "goalsFor": 17, "goalsAgainst": 18, "goalDifference": -1, "points": 22,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
            {
                "position": 11,
                "team": { "id": 130, "tla": null, "name": "Grêmio", "crest": "https://media.api-sports.io/football/teams/130.png", "shortName": "Grêmio" },
                "playedGames": 15, "won": 6, "draw": 3, "lost": 6,
                "goalsFor": 16, "goalsAgainst": 18, "goalDifference": -2, "points": 21,
                "description": "Promotion - Copa Sudamericana (Group Stage)"
            },
            {
                "position": 12,
                "team": { "id": 133, "tla": null, "name": "Vasco da Gama", "crest": "https://media.api-sports.io/football/teams/133.png", "shortName": "Vasco da Gama" },
                "playedGames": 15, "won": 5, "draw": 5, "lost": 5,
                "goalsFor": 16, "goalsAgainst": 19, "goalDifference": -3, "points": 20,
                "description": "None"
            },
            {
                "position": 13,
                "team": { "id": 207, "tla": null, "name": "Fortaleza", "crest": "https://media.api-sports.io/football/teams/207.png", "shortName": "Fortaleza" },
                "playedGames": 15, "won": 5, "draw": 4, "lost": 6,
                "goalsFor": 15, "goalsAgainst": 19, "goalDifference": -4, "points": 19,
                "description": "None"
            },
            {
                "position": 14,
                "team": { "id": 794, "tla": null, "name": "Bragantino", "crest": "https://media.api-sports.io/football/teams/794.png", "shortName": "Bragantino" },
                "playedGames": 15, "won": 5, "draw": 3, "lost": 7,
                "goalsFor": 14, "goalsAgainst": 20, "goalDifference": -6, "points": 18,
                "description": "None"
            },
            {
                "position": 15,
                "team": { "id": 134, "tla": null, "name": "Athletico-PR", "crest": "https://media.api-sports.io/football/teams/134.png", "shortName": "Athletico-PR" },
                "playedGames": 15, "won": 4, "draw": 5, "lost": 6,
                "goalsFor": 13, "goalsAgainst": 19, "goalDifference": -6, "points": 17,
                "description": "None"
            },
            {
                "position": 16,
                "team": { "id": 210, "tla": null, "name": "Juventude", "crest": "https://media.api-sports.io/football/teams/210.png", "shortName": "Juventude" },
                "playedGames": 15, "won": 4, "draw": 4, "lost": 7,
                "goalsFor": 13, "goalsAgainst": 21, "goalDifference": -8, "points": 16,
                "description": "None"
            },
            {
                "position": 17,
                "team": { "id": 211, "tla": null, "name": "Cuiabá", "crest": "https://media.api-sports.io/football/teams/211.png", "shortName": "Cuiabá" },
                "playedGames": 15, "won": 4, "draw": 3, "lost": 8,
                "goalsFor": 12, "goalsAgainst": 22, "goalDifference": -10, "points": 15,
                "description": "Relegation - Serie B"
            },
            {
                "position": 18,
                "team": { "id": 136, "tla": null, "name": "Vitória", "crest": "https://media.api-sports.io/football/teams/136.png", "shortName": "Vitória" },
                "playedGames": 15, "won": 3, "draw": 4, "lost": 8,
                "goalsFor": 11, "goalsAgainst": 23, "goalDifference": -12, "points": 13,
                "description": "Relegation - Serie B"
            },
            {
                "position": 19,
                "team": { "id": 132, "tla": null, "name": "Chapecoense-sc", "crest": "https://media.api-sports.io/football/teams/132.png", "shortName": "Chapecoense-sc" },
                "playedGames": 15, "won": 3, "draw": 3, "lost": 9,
                "goalsFor": 10, "goalsAgainst": 25, "goalDifference": -15, "points": 12,
                "description": "Relegation - Serie B"
            },
            {
                "position": 20,
                "team": { "id": 7848, "tla": null, "name": "Mirassol", "crest": "https://media.api-sports.io/football/teams/7848.png", "shortName": "Mirassol" },
                "playedGames": 15, "won": 2, "draw": 4, "lost": 9,
                "goalsFor": 9, "goalsAgainst": 27, "goalDifference": -18, "points": 10,
                "description": "Relegation - Serie B"
            }
        ]
    }
    """
}
