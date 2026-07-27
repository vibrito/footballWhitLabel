import Testing
import Foundation
@testable import BR2026

@Suite("MatchdayViewModel")
@MainActor
struct MatchdayViewModelTests {
    private let team = Team(id: 1, name: "Test FC", shortName: "TFC", crestURL: nil)

    private func date(day: Int, hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    private func today(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    private func daysFromNow(_ days: Int, hour: Int) -> Date {
        let future = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: future)!
    }

    @Test("nextMatch is the earliest live-or-scheduled match, ignoring finished ones")
    func nextMatchIsEarliestUpcoming() async {
        let finishedYesterday = Match(
            id: 1, utcDate: date(day: 9, hour: 20), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let scheduledLater = Match(
            id: 2, utcDate: date(day: 10, hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let scheduledSooner = Match(
            id: 3, utcDate: date(day: 10, hour: 16), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduledLater, finishedYesterday, scheduledSooner], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 3)
    }

    @Test("nextMatch prefers a match live right now over one scheduled for a later day")
    func nextMatchPrefersLiveMatch() async {
        let live = Match(
            id: 1, utcDate: date(day: 10, hour: 15), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let scheduledTomorrow = Match(
            id: 2, utcDate: date(day: 11, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduledTomorrow, live], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 1)
    }

    @Test("otherMatchesForNextMatchDay returns same-day matches excluding nextMatch, sorted by kickoff")
    func otherMatchesForNextMatchDayFiltersAndSorts() async {
        let next = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let sameDayLater = Match(
            id: 2, utcDate: date(day: 10, hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let sameDayEarlier = Match(
            id: 3, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let differentDay = Match(
            id: 4, utcDate: date(day: 11, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [differentDay, sameDayLater, next, sameDayEarlier], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.otherMatchesForNextMatchDay.map(\.id) == [3, 2])
    }

    @Test("finishedMatchesForNextMatchDay and upcomingMatchesForNextMatchDay split same-day matches by status")
    func splitsOtherMatchesByFinishedStatus() async {
        let next = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let finishedSameDay = Match(
            id: 2, utcDate: date(day: 10, hour: 9), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let scheduledSameDay = Match(
            id: 3, utcDate: date(day: 10, hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduledSameDay, next, finishedSameDay], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.finishedMatchesForNextMatchDay.map(\.id) == [2])
        #expect(viewModel.upcomingMatchesForNextMatchDay.map(\.id) == [3])
    }

    @Test("nextMatch and otherMatchesForNextMatchDay are empty when nothing is live or scheduled")
    func emptyWhenNothingUpcoming() async {
        let finished = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [finished], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch == nil)
        #expect(viewModel.otherMatchesForNextMatchDay.isEmpty)
    }

    @Test("load() shows cached matches immediately and keeps them if the background refresh fails")
    func loadKeepsCachedDataWhenRefreshFails() async {
        let cachedMatch = Match(
            id: 99, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [], standings: [])
        service.cachedMatchesOverride = [cachedMatch]
        service.shouldThrowOnFetch = true
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [99])
        #expect(viewModel.isRefreshing == false)
    }

    @Test("load() replaces stale cached matches with freshly fetched ones on success")
    func loadReplacesCacheWithFreshDataOnSuccess() async {
        let staleMatch = Match(
            id: 1, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let freshMatch = Match(
            id: 2, utcDate: date(day: 2, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [freshMatch], standings: [])
        service.cachedMatchesOverride = [staleMatch]
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.matches.map(\.id) == [2])
    }

    @Test("loadOnce() only fetches on the first call, not on repeated calls")
    func loadOnceOnlyFetchesOnce() async {
        let match = Match(
            id: 1, utcDate: date(day: 1, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.loadOnce()
        await viewModel.loadOnce()
        await viewModel.loadOnce()

        #expect(service.fetchMatchesCallCount == 1)
        #expect(viewModel.matches.map(\.id) == [1])
    }

    @Test("nextMatch features the selected team's own match when it's today, even over an earlier league-wide match")
    func nextMatchFeaturesSelectedTeamWhenTodayMatch() async {
        let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
        let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
        let earlierLeagueWideMatch = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: otherTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let selectedTeamsTodayMatch = Match(
            id: 2, utcDate: today(hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [earlierLeagueWideMatch, selectedTeamsTodayMatch], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
            away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
            third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
        )
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        await themeStore.select(.palmeirasHome)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 2)
    }

    @Test("nextMatch features the selected team's own today match even when a different match is live right now")
    func nextMatchFeaturesSelectedTeamOverLiveMatchElsewhere() async {
        let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
        let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
        let liveElsewhere = Match(
            id: 1, utcDate: today(hour: 10), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: otherTeam, awayTeam: otherTeam, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 40
        )
        let selectedTeamsTodayMatch = Match(
            id: 2, utcDate: today(hour: 20), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [liveElsewhere, selectedTeamsTodayMatch], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
            away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
            third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
        )
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        await themeStore.select(.palmeirasHome)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 2)
    }

    @Test("nextMatch falls back to the league-wide earliest match when the selected team's own match isn't today")
    func nextMatchFallsBackWhenSelectedTeamMatchIsNotToday() async {
        let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
        let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
        let liveElsewhereToday = Match(
            id: 1, utcDate: today(hour: 10), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: otherTeam, awayTeam: otherTeam, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 40
        )
        let selectedTeamsFutureMatch = Match(
            id: 2, utcDate: daysFromNow(10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [liveElsewhereToday, selectedTeamsFutureMatch], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
            away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
            third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
        )
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        await themeStore.select(.palmeirasHome)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 1)
    }

    @Test("nextMatch falls back to the league-wide earliest match when the selected team has none live/scheduled")
    func nextMatchFallsBackWhenSelectedTeamHasNoMatch() async {
        let selectedTeam = Team(id: TeamThemeOption.palmeirasHome.teamID, name: "Palmeiras", shortName: "PAL", crestURL: nil)
        let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
        let selectedTeamsFinishedMatch = Match(
            id: 1, utcDate: date(day: 9, hour: 12), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: selectedTeam, awayTeam: otherTeam, homeScore: 2, awayScore: 1, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let leagueWideMatch = Match(
            id: 2, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: otherTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [selectedTeamsFinishedMatch, leagueWideMatch], standings: [])
        service.cachedTeamThemeColorSetOverride = TeamThemeColorSet(
            home: TeamThemeColors(mainColorHex: "006437", fontColorHex: "ffffff"),
            away: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "035336"),
            third: TeamThemeColors(mainColorHex: "ffffff", fontColorHex: "2c5434")
        )
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        await themeStore.select(.palmeirasHome)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 2)
    }

    @Test("nextMatch uses the existing league-wide-earliest behavior when no team is selected")
    func nextMatchUnchangedWhenNoTeamSelected() async {
        let otherTeam = Team(id: 999, name: "Other FC", shortName: "OFC", crestURL: nil)
        let match = Match(
            id: 1, utcDate: date(day: 10, hour: 12), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: otherTeam, awayTeam: otherTeam, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [match], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.nextMatch?.id == 1)
    }

    @Test("hasLiveMatch is true when any match is live")
    func hasLiveMatchTrueWhenLive() async {
        let live = Match(
            id: 1, utcDate: date(day: 10, hour: 15), status: .live, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: nil, venue: nil, minute: 30
        )
        let service = StubMatchService(matches: [live], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.hasLiveMatch == true)
    }

    @Test("hasLiveMatch is false when no match is live")
    func hasLiveMatchFalseWhenNoneLive() async {
        let scheduled = Match(
            id: 1, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduled], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        #expect(viewModel.hasLiveMatch == false)
    }

    @Test("refreshIfNeeded does the one-time cache-then-refresh on its first call")
    func refreshIfNeededFirstCallLoadsOnce() async {
        let scheduled = Match(
            id: 1, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduled], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.refreshIfNeeded()

        #expect(service.fetchMatchesCallCount == 1)
    }

    @Test("refreshIfNeeded refetches on every subsequent call")
    func refreshIfNeededSubsequentCallsAlwaysRefetch() async {
        let scheduled = Match(
            id: 1, utcDate: date(day: 10, hour: 15), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let service = StubMatchService(matches: [scheduled], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.refreshIfNeeded()
        await viewModel.refreshIfNeeded()
        await viewModel.refreshIfNeeded()

        #expect(service.fetchMatchesCallCount == 3)
    }
    // MARK: - The shared board rule
    //
    // Matches the marketing site's dayGroups and Fixture 2026's LeagueTodayViewModel:
    // a match is on the board if it is on the featured day, OR live now, OR kicked off
    // within the last 24 hours.

    private func match(_ id: Int, _ utcDate: Date, _ status: MatchStatus,
                       minute: Int? = nil) -> Match {
        Match(id: id, utcDate: utcDate, status: status, matchday: 1, stage: "REGULAR_SEASON",
              homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil,
              winner: nil, venue: nil, minute: minute)
    }

    private func viewModel(_ matches: [Match], now: Date) async -> MatchdayViewModel {
        let service = StubMatchService(matches: matches, standings: [])
        let vm = MatchdayViewModel(service: service,
                                   themeStore: TeamThemeStore(setting: StubTeamThemeSetting(), service: service))
        vm.now = { now }
        await vm.load()
        return vm
    }

    @Test("A live match stays on the board after the reader's midnight")
    func liveMatchSurvivesMidnight() async {
        // The Lisbon case: kicked off 22:30 yesterday local, the clock has just passed
        // midnight, and the match is barely into the first half.
        let now = Date()
        let live = match(10, now.addingTimeInterval(-30 * 60), .live, minute: 30)
        let laterToday = match(11, now.addingTimeInterval(6 * 3600), .scheduled)

        let vm = await viewModel([live, laterToday], now: now)
        let onBoard = ([vm.nextMatch] + vm.otherMatchesForNextMatchDay).compactMap(\.self).map(\.id)
        #expect(onBoard.contains(10), "a match being played is never off the board")
    }

    @Test("A finished match is held for 24 hours after kickoff")
    func finishedMatchHeldForADay() async {
        let now = Date()
        // Kicked off 20 hours ago — inside the window — but on the previous local day.
        let lastNight = match(20, now.addingTimeInterval(-20 * 3600), .finished)
        let upcoming = match(21, now.addingTimeInterval(4 * 3600), .scheduled)

        let vm = await viewModel([lastNight, upcoming], now: now)
        #expect(vm.otherMatchesForNextMatchDay.map(\.id).contains(20))
        #expect(vm.finishedMatchesForNextMatchDay.map(\.id).contains(20))
    }

    @Test("The hold window expires: an older finished match is dropped")
    func oldFinishedMatchDropped() async {
        let now = Date()
        let longAgo = match(30, now.addingTimeInterval(-26 * 3600), .finished)
        let upcoming = match(31, now.addingTimeInterval(4 * 3600), .scheduled)

        let vm = await viewModel([longAgo, upcoming], now: now)
        #expect(!vm.otherMatchesForNextMatchDay.map(\.id).contains(30),
                "past 24h from kickoff, last night's result is no longer news")
    }

    @Test("holdWindow is 24 hours, the same value the other two codebases use")
    func holdWindowIsOneDay() {
        #expect(MatchdayViewModel.holdWindow == 24 * 60 * 60)
    }

    @Test("Postponed matches are kept off the board entirely")
    func postponedIsExcludedFromTheBoard() async {
        let scheduled = Match(
            id: 1, utcDate: date(day: 10, hour: 16), status: .scheduled, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let postponed = Match(
            id: 2, utcDate: date(day: 10, hour: 18), status: .postponed, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: nil, awayScore: nil, winner: nil, venue: nil, minute: nil
        )
        let finished = Match(
            id: 3, utcDate: date(day: 10, hour: 14), status: .finished, matchday: 1, stage: "REGULAR_SEASON",
            homeTeam: team, awayTeam: team, homeScore: 1, awayScore: 0, winner: "HOME_TEAM", venue: nil, minute: 90
        )
        let service = StubMatchService(matches: [scheduled, postponed, finished], standings: [])
        let themeStore = TeamThemeStore(setting: StubTeamThemeSetting(), service: service)
        let viewModel = MatchdayViewModel(service: service, themeStore: themeStore)

        await viewModel.load()

        let shown = (viewModel.finishedMatchesForNextMatchDay
                     + viewModel.upcomingMatchesForNextMatchDay).map(\.id)
        #expect(!shown.contains(2), "a postponed match must not appear in any Matchday section")
    }

}

final class StubMatchService: MatchService {
    let matches: [Match]
    let standings: [Standing]
    let events: [MatchEvent]
    let competition: Competition
    var cachedMatchesOverride: [Match]?
    var cachedStandingsOverride: [Standing]?
    var cachedCompetitionOverride: Competition?
    var statisticsOverride: MatchStatistics?
    var lineupsOverride: MatchLineup?
    var teamThemeColorSetOverride: TeamThemeColorSet?
    var cachedTeamThemeColorSetOverride: TeamThemeColorSet?
    var shouldThrowOnFetch = false
    var shouldThrowOnTeamThemeFetch = false
    private(set) var fetchMatchesCallCount = 0
    private(set) var fetchStandingsCallCount = 0
    private(set) var fetchCompetitionCallCount = 0
    private(set) var fetchTeamThemeColorSetCallCount = 0

    init(
        matches: [Match],
        standings: [Standing],
        events: [MatchEvent] = [],
        competition: Competition = Competition(
            code: "BSA", name: "Campeonato Brasileiro Série A", season: 2026,
            logoURL: URL(string: "https://example.com/logo.png")!
        )
    ) {
        self.matches = matches
        self.standings = standings
        self.events = events
        self.competition = competition
    }

    func fetchMatches() async throws -> [Match] {
        fetchMatchesCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return matches
    }

    func fetchStandings() async throws -> [Standing] {
        fetchStandingsCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return standings
    }

    func fetchEvents(matchID: Int) async throws -> [MatchEvent] {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return events
    }

    func fetchMatchStatistics(matchID: Int) async throws -> MatchStatistics? {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return statisticsOverride
    }

    func fetchMatchLineups(matchID: Int) async throws -> MatchLineup? {
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return lineupsOverride
    }

    func fetchCompetition() async throws -> Competition {
        fetchCompetitionCallCount += 1
        if shouldThrowOnFetch { throw StubServiceError.simulatedFailure }
        return competition
    }

    func fetchTeamThemeColorSet(teamID: Int) async throws -> TeamThemeColorSet {
        fetchTeamThemeColorSetCallCount += 1
        if shouldThrowOnTeamThemeFetch { throw StubServiceError.simulatedFailure }
        guard let teamThemeColorSetOverride else { throw StubServiceError.simulatedFailure }
        return teamThemeColorSetOverride
    }

    func cachedMatches() -> [Match] { cachedMatchesOverride ?? matches }
    func cachedStandings() -> [Standing] { cachedStandingsOverride ?? standings }
    func cachedCompetition() -> Competition? { cachedCompetitionOverride }
    func cachedTeamThemeColorSet(teamID: Int) -> TeamThemeColorSet? { cachedTeamThemeColorSetOverride }
}

enum StubServiceError: Error {
    case simulatedFailure
}
