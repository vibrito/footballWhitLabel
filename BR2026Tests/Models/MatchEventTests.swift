// BR2026Tests/Models/MatchEventTests.swift
import Testing
import Foundation
@testable import BR2026

@Suite("MatchEvent")
struct MatchEventTests {
    @Test("accessibilityLabel for a normal goal")
    func accessibilityLabelGoal() {
        let event = MatchEvent(
            team: .home, type: .goal, assist: nil, detail: "Normal Goal", minute: 67,
            player: "Neymar", playerOut: nil, extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("67"))
        #expect(label.contains("Neymar"))
    }

    @Test("accessibilityLabel for a penalty goal")
    func accessibilityLabelPenalty() {
        let event = MatchEvent(
            team: .home, type: .goal, assist: nil, detail: "Penalty", minute: 45,
            player: "Neymar", playerOut: nil, extraMinute: 2
        )
        let label = event.accessibilityLabel
        #expect(label.contains("45"))
        #expect(label.contains("2"))
        #expect(label.contains("Neymar"))
    }

    @Test("accessibilityLabel for an own goal")
    func accessibilityLabelOwnGoal() {
        let event = MatchEvent(
            team: .away, type: .goal, assist: nil, detail: "Own Goal", minute: 30,
            player: "Defender Name", playerOut: nil, extraMinute: nil
        )
        #expect(event.accessibilityLabel.contains("Defender Name"))
    }

    @Test("accessibilityLabel for a yellow card")
    func accessibilityLabelYellowCard() {
        let event = MatchEvent(
            team: .home, type: .yellowCard, assist: nil, detail: "", minute: 23,
            player: "Casemiro", playerOut: nil, extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("23"))
        #expect(label.contains("Casemiro"))
    }

    @Test("accessibilityLabel for a red card")
    func accessibilityLabelRedCard() {
        let event = MatchEvent(
            team: .home, type: .redCard, assist: nil, detail: "", minute: 80,
            player: "Casemiro", playerOut: nil, extraMinute: nil
        )
        #expect(event.accessibilityLabel.contains("Casemiro"))
    }

    @Test("accessibilityLabel for a substitution")
    func accessibilityLabelSubstitution() {
        let event = MatchEvent(
            team: .home, type: .substitution, assist: nil, detail: "", minute: 75,
            player: "Player In", playerOut: "Player Out", extraMinute: nil
        )
        let label = event.accessibilityLabel
        #expect(label.contains("Player In"))
        #expect(label.contains("Player Out"))
    }
}
