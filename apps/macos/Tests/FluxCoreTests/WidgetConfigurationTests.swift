import XCTest
import Foundation
@testable import FluxCore

final class FluxWidgetConfigurationTests: XCTestCase {
    func testConfigurationRoundTripAndInvalidValues() throws {
        var value = FluxWidgetConfiguration(); value.diameter = 360; value.opacity = 0.9
        value.theme = .dark; value.accent = .violet; value.trigger = .optionRightClick
        value.rightClickEnabled = true; value.showLabels = false
        let restored = try JSONDecoder().decode(FluxWidgetConfiguration.self, from: JSONEncoder().encode(value)).validated()
        XCTAssertEqual(restored, value)
        value.diameter = .nan; XCTAssertThrowsError(try value.validated())
        value.diameter = 10000; XCTAssertThrowsError(try value.validated())
        value.diameter = 300; value.opacity = 0.2; XCTAssertThrowsError(try value.validated())
        value.opacity = 1; value.version = 9; XCTAssertThrowsError(try value.validated())
    }
    func testGestureDoesNotConsumeOtherModifiers() {
        XCTAssertTrue(WidgetTrigger.rightClick.matches(option: false, control: false, shift: false, command: false))
        XCTAssertFalse(WidgetTrigger.rightClick.matches(option: true, control: false, shift: false, command: false))
        XCTAssertTrue(WidgetTrigger.optionRightClick.matches(option: true, control: false, shift: false, command: false))
        XCTAssertFalse(WidgetTrigger.optionRightClick.matches(option: true, control: true, shift: false, command: false))
        XCTAssertFalse(WidgetTrigger.controlRightClick.matches(option: false, control: true, shift: false, command: true))
    }
    func testDownUpPairAndWidgetExclusion() {
        var gate = RightClickGate()
        XCTAssertFalse(gate.consume(isDown: false, enabled: true, matches: true, insideWidget: false))
        XCTAssertFalse(gate.consume(isDown: true, enabled: false, matches: true, insideWidget: false))
        XCTAssertFalse(gate.consume(isDown: true, enabled: true, matches: true, insideWidget: true))
        XCTAssertFalse(gate.consume(isDown: false, enabled: true, matches: true, insideWidget: true))
        XCTAssertTrue(gate.consume(isDown: true, enabled: true, matches: true, insideWidget: false))
        XCTAssertTrue(gate.consume(isDown: false, enabled: false, matches: false, insideWidget: true))
        XCTAssertFalse(gate.awaitingUp)
        XCTAssertFalse(gate.consume(isDown: false, enabled: true, matches: true, insideWidget: false))
    }
    func testAppearanceResetKeepsActivationChoice() {
        var value = FluxWidgetConfiguration(); value.trigger = .controlRightClick; value.rightClickEnabled = true
        value.accent = .green; value.diameter = 380; value.resetAppearance()
        XCTAssertEqual(value.diameter, 300); XCTAssertEqual(value.accent, .coral)
        XCTAssertEqual(value.trigger, .controlRightClick); XCTAssertTrue(value.rightClickEnabled)
    }
}
