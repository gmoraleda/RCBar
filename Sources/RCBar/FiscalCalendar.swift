import Foundation

// MARK: - Apple fiscal calendar (Pacific time)
// ponytail: computed rule (last Sat of Sep, 5-4-4 weeks, 53rd week in Dec). Apple's official
// fiscal calendar in App Store Connect (Payments and Financial Reports) is the source of truth.

let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
}()

func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }
func add(_ days: Int, _ d: Date) -> Date { cal.date(byAdding: .day, value: days, to: d)! }

/// Last Saturday of September of `year` (weekday: Sun=1 ... Sat=7, so `% 7` = days back to Saturday).
func fiscalYearEnd(_ year: Int) -> Date {
    let sep30 = day(year, 9, 30)
    return add(-(cal.component(.weekday, from: sep30) % 7), sep30)
}

struct FiscalMonth: Equatable {
    let start: Date // Sunday
    let end: Date   // Saturday, inclusive
    var payout: Date { add(33, end) }
}

func fiscalMonth(containing date: Date) -> FiscalMonth {
    let d = cal.startOfDay(for: date)
    var fy = cal.component(.year, from: d)
    if d > fiscalYearEnd(fy) { fy += 1 }
    var start = add(1, fiscalYearEnd(fy - 1))
    let fyDays = cal.dateComponents([.day], from: start, to: fiscalYearEnd(fy)).day! + 1
    for (i, weeks) in [5, 4, 4, 5, 4, 4, 5, 4, 4, 5, 4, 4].enumerated() {
        let w = (i == 2 && fyDays == 371) ? 5 : weeks // 53-week year: December gets 5 weeks
        let end = add(w * 7 - 1, start)
        if d <= end { return FiscalMonth(start: start, end: end) }
        start = add(1, end)
    }
    fatalError("date outside fiscal year \(fy)")
}

/// Fiscal months from the oldest unpaid one (payout >= today) up to the current one.
func unpaidMonths(today: Date) -> [FiscalMonth] {
    let t = cal.startOfDay(for: today)
    var months = [fiscalMonth(containing: t)]
    while case let prev = fiscalMonth(containing: add(-1, months[0].start)), prev.payout >= t {
        months.insert(prev, at: 0)
    }
    return months
}
