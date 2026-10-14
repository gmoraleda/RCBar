import Foundation

/// `RCBar --selftest`: checks the fiscal calendar and event diffing, then exits.
func runSelfTest() {
    let today = day(2026, 10, 13)
    let cur = fiscalMonth(containing: today)
    precondition(cur == FiscalMonth(start: day(2026, 9, 27), end: day(2026, 10, 31)), "current month")
    precondition(cur.payout == day(2026, 12, 3), "current payout")
    let prev = fiscalMonth(containing: day(2026, 9, 26))
    precondition(prev == FiscalMonth(start: day(2026, 8, 30), end: day(2026, 9, 26)), "previous month")
    precondition(prev.payout == day(2026, 10, 29), "previous payout")
    let nov = fiscalMonth(containing: day(2026, 11, 15))
    precondition(nov == FiscalMonth(start: day(2026, 11, 1), end: day(2026, 11, 28)), "nov")
    precondition(nov.payout == day(2026, 12, 31), "nov payout")
    precondition(fiscalMonth(containing: day(2026, 12, 10)) == FiscalMonth(start: day(2026, 11, 29), end: day(2026, 12, 26)), "dec")
    precondition(fiscalYearEnd(2027) == day(2027, 9, 25), "FY2027 end")
    precondition(fiscalYearEnd(2026) == day(2026, 9, 26), "FY2026 end")
    precondition(unpaidMonths(today: today) == [prev, cur], "unpaid on Oct 13")
    precondition(unpaidMonths(today: day(2026, 10, 29)) == [prev, cur], "unpaid on payout day")
    precondition(unpaidMonths(today: day(2026, 10, 30)) == [cur], "unpaid after payout")
    precondition(fmt(today, "yyyy-MM-dd") == "2026-10-13", "api date format")
    // Every fiscal year is 364 or 371 days and months tile it without gaps.
    for y in 2015...2035 {
        let start = add(1, fiscalYearEnd(y - 1))
        var m = fiscalMonth(containing: start), count = 1
        precondition(m.start == start && cal.component(.weekday, from: m.start) == 1, "FY\(y) start")
        while m.end < fiscalYearEnd(y) { m = fiscalMonth(containing: add(1, m.end)); count += 1 }
        precondition(m.end == fiscalYearEnd(y) && count == 12, "FY\(y) tiling")
        let days = cal.dateComponents([.day], from: start, to: fiscalYearEnd(y)).day! + 1
        precondition(days == 364 || days == 371, "FY\(y) length")
    }
    precondition(abs(eventDelta(old: 10, oldMonth: "a", new: 14.99, month: "a")! - 4.99) < 1e-9, "increase")
    precondition(abs(eventDelta(old: 14.99, oldMonth: "a", new: 10, month: "a")! + 4.99) < 1e-9, "refund")
    precondition(eventDelta(old: 10, oldMonth: "a", new: 10, month: "a") == nil, "no change")
    precondition(eventDelta(old: 500, oldMonth: "a", new: 3, month: "b") == nil, "rollover")
    precondition(eventDelta(old: nil, oldMonth: nil, new: 3, month: "a") == nil, "first run")
    print("selftest ok")
}
