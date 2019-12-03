import XCTest
@testable import WooCommerce


/// Date+Woo: Unit Tests
///
final class DateWooTests: XCTestCase {

    func testUpdateStringWorksForIntervalsUnderTwoMinutes() {

        // 1 second
        let momentsAgo = NSLocalizedString("Updated moments ago",
                                           comment: "A unit test string for relative time intervals")
        let oneSecondAgo = Calendar.current.date(byAdding: .second, value: -1, to: Date())!
        XCTAssertEqual(oneSecondAgo.relativelyFormattedUpdateString, momentsAgo)

        // 12 seconds
        let twelveSecondsAgo = Calendar.current.date(byAdding: .second, value: -12, to: Date())!
        XCTAssertEqual(twelveSecondsAgo.relativelyFormattedUpdateString, momentsAgo)

        // 1 minute, 59 seconds
        let almostTwoMinutesAgo = Calendar.current.date(byAdding: .second, value: -119, to: Date())!
        XCTAssertEqual(almostTwoMinutesAgo.relativelyFormattedUpdateString, momentsAgo)

        // 2 minutes
        let twoMinutesAgo = Calendar.current.date(byAdding: .minute, value: -2, to: Date())!
        XCTAssertNotEqual(twoMinutesAgo.relativelyFormattedUpdateString, momentsAgo)
    }

    func testUpdateStringWorksForIntervalsOneDayOrLess() {

        let minutesAgo = NSLocalizedString("Updated 2 minutes ago",
                                           comment: "A unit test string for time intervals")
        let almostHourAgo = NSLocalizedString("Updated 59 minutes ago",
                                              comment: "A unit test string for a plural time interval in minutes")
        let hourAgo = NSLocalizedString("Updated 1 hour ago",
                                        comment: "A unit test string for a singular time interval")
        let nineAgo = NSLocalizedString("Updated 9 hours ago",
                                        comment: "A unit test string for a plural time interval in hours")
        let almostDayAgo = NSLocalizedString("Updated 23 hours ago",
                                             comment: "A unit test string for time interval just under 1 day")
        let dayAgo = NSLocalizedString("Updated 24 hours ago",
                                       comment: "A unit test string for 1 day, represented as plural time interval in hours")

        // 2 minutes
        let twoMinutesAgo = Calendar.current.date(byAdding: .minute, value: -2, to: Date())!
        XCTAssertEqual(twoMinutesAgo.relativelyFormattedUpdateString, minutesAgo)

        // 2 minutes, 3 seconds
        let twoPlusMinutesAgo = Calendar.current.date(byAdding: .second, value: -123, to: Date())!
        XCTAssertEqual(twoPlusMinutesAgo.relativelyFormattedUpdateString, minutesAgo)

        // 59 minutes
        let twoFiftyNineMinutesAgo = Calendar.current.date(byAdding: .minute, value: -59, to: Date())!
        XCTAssertEqual(twoFiftyNineMinutesAgo.relativelyFormattedUpdateString, almostHourAgo)

        // 1 hour
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        XCTAssertEqual(oneHourAgo.relativelyFormattedUpdateString, hourAgo)

        /// 9 hours
        let nineHoursAgo = Calendar.current.date(byAdding: .hour, value: -9, to: Date())!
        XCTAssertEqual(nineHoursAgo.relativelyFormattedUpdateString, nineAgo)

        /// 23 hours, 59 minutes
        let underOneDayAgo = Calendar.current.date(byAdding: .minute, value: -1439, to: Date())!
        XCTAssertEqual(underOneDayAgo.relativelyFormattedUpdateString, almostDayAgo)

        // 1 day
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertNotEqual(oneDayAgo.relativelyFormattedUpdateString, dayAgo)
    }

    func testUpdateStringWorksForIntervalsOverOneDay() {

        // Skip verifying the time part of the resulting string because of TZ madness

        // Oct 10,2018
        let calendar = Calendar(identifier: .gregorian)
        let dateComponents1 = DateComponents(calendar: calendar, year: 2018, month: 10, day: 10)
        let specificPastDate1 = Calendar.current.date(from: dateComponents1)!
        XCTAssertTrue(specificPastDate1.relativelyFormattedUpdateString.contains("Updated on Oct 10, 2018"))

        // Feb 2, 2016
        let dateComponents2 = DateComponents(calendar: calendar, year: 2016, month: 2, day: 2)
        let specificPastDate2 = Calendar.current.date(from: dateComponents2)!
        XCTAssertTrue(specificPastDate2.relativelyFormattedUpdateString.contains("Updated on Feb 2, 2016"))
    }

    func testUpdateStringWorksForFutureIntervals() {

        // 1 second in future
        let futureDate = Calendar.current.date(byAdding: .second, value: 1, to: Date())!
        XCTAssertEqual(futureDate.relativelyFormattedUpdateString, "Updated moments ago")

        // 1 year in future
        let futureDate2 = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        XCTAssertEqual(futureDate2.relativelyFormattedUpdateString, "Updated moments ago")
    }
}
