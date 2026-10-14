import AppKit
import ServiceManagement
import SwiftUI

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

/// Formats in Pacific time by default (fiscal dates); pass `.current` for wall-clock times.
func fmt(_ d: Date, _ pattern: String, tz: TimeZone = cal.timeZone) -> String {
    let f = DateFormatter()
    f.calendar = cal
    f.timeZone = tz
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = pattern
    return f.string(from: d)
}

/// Delta to report as an event, or nil (first value, no change, or fiscal month rolled over).
func eventDelta(old: Double?, oldMonth: String?, new: Double, month: String) -> Double? {
    guard let old, oldMonth == month, abs(new - old) >= 0.005 else { return nil }
    return new - old
}

func money(_ v: Double, _ currency: String, digits: Int = 2) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currency
    f.maximumFractionDigits = digits
    f.minimumFractionDigits = digits
    return f.string(from: NSNumber(value: v)) ?? "\(v) \(currency)"
}

// MARK: - Selftest

if CommandLine.arguments.contains("--selftest") {
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
    exit(0)
}

// MARK: - RevenueCat API

struct Config: Decodable { let apiKey: String; let projectId: String?; let currency: String? }
struct Revenue: Decodable { let value: Double; let currency: String }
struct Projects: Decodable { struct Item: Decodable { let id: String }; let items: [Item] }
struct Failure: Error { let text: String }

let configPath = NSString("~/.config/rcbar/config.json").expandingTildeInPath

func get<T: Decodable>(_ path: String, key: String) async throws -> T {
    var req = URLRequest(url: URL(string: "https://api.revenuecat.com/v2" + path)!)
    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(code) else {
        throw Failure(text: "HTTP \(code) \(path.prefix(40))…: \(String(decoding: data.prefix(300), as: UTF8.self))")
    }
    return try JSONDecoder().decode(T.self, from: data)
}

// MARK: - App

@MainActor final class Model: ObservableObject {
    @Published var title = "…"
    @Published var lines: [String] = []
    @Published var error: String?
    @Published var updated: Date?
    var projectId: String?
    var loading = false
    let defaults = UserDefaults.standard

    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    init() {
        // Register as a login item on first launch from the .app bundle; the menu toggle can undo it.
        if Bundle.main.bundlePath.hasSuffix(".app"), !defaults.bool(forKey: "loginItemSet") {
            defaults.set(true, forKey: "loginItemSet")
            setLaunchAtLogin(true)
        }
        Task {
            while true {
                await refresh()
                try? await Task.sleep(nanoseconds: 300 * 1_000_000_000)
            }
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            self.error = "Launch at login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            guard let data = FileManager.default.contents(atPath: configPath),
                  let config = try? JSONDecoder().decode(Config.self, from: data), !config.apiKey.isEmpty else {
                throw Failure(text: "Missing/invalid config at \(configPath)\nFormat: {\"apiKey\":\"sk_...\",\"projectId\":\"proj...\",\"currency\":\"EUR\"}")
            }
            if projectId == nil {
                projectId = config.projectId
                if projectId == nil {
                    let projects: Projects = try await get("/projects", key: config.apiKey)
                    guard let first = projects.items.first else { throw Failure(text: "No projects for this API key") }
                    projectId = first.id
                }
            }
            let today = Date()
            let months = unpaidMonths(today: today)
            var amounts: [Revenue] = []
            for m in months {
                let end = min(m.end, cal.startOfDay(for: today))
                let q = "start_date=\(fmt(m.start, "yyyy-MM-dd"))&end_date=\(fmt(end, "yyyy-MM-dd"))&revenue_type=proceeds&currency=\(config.currency ?? "EUR")"
                amounts.append(try await get("/projects/\(projectId!)/metrics/revenue?\(q)", key: config.apiKey))
            }

            // Latest event: diff the current month's running total against the persisted baseline.
            let cur = amounts.last!, month = fmt(months.last!.start, "yyyy-MM-dd")
            if let delta = eventDelta(old: defaults.object(forKey: "baseline") as? Double,
                                      oldMonth: defaults.string(forKey: "baselineMonth"),
                                      new: cur.value, month: month) {
                defaults.set(delta, forKey: "eventDelta")
                defaults.set(cur.currency, forKey: "eventCurrency")
                defaults.set(today, forKey: "eventDate")
            }
            defaults.set(cur.value, forKey: "baseline")
            defaults.set(month, forKey: "baselineMonth")

            let next = months[0], nextRev = amounts[0]
            title = money(cur.value, cur.currency)
            lines = [
                "Next payout · \(fmt(next.payout, "EEE MMM d")): \(money(nextRev.value, nextRev.currency))",
                "    covers \(fmt(next.start, "MMM d")) – \(fmt(next.end, "MMM d"))",
            ]
            if months.count > 1 {
                lines.append("Accruing for \(fmt(months.last!.payout, "MMM d")): \(money(cur.value, cur.currency))")
            }
            if let date = defaults.object(forKey: "eventDate") as? Date {
                let delta = defaults.double(forKey: "eventDelta")
                let c = defaults.string(forKey: "eventCurrency") ?? cur.currency
                lines.append("Latest: \(delta >= 0 ? "+" : "-")\(money(abs(delta), c)) · \(fmt(date, Calendar.current.isDateInToday(date) ? "HH:mm" : "MMM d HH:mm", tz: .current))")
            } else {
                lines.append("No new events since launch")
            }
            error = nil
            updated = today
        } catch {
            self.error = (error as? Failure)?.text ?? "\(error)"
            title = "RC error"
        }
    }
}

struct RCBarApp: App {
    @StateObject var model = Model()

    init() { NSApplication.shared.setActivationPolicy(.accessory) }

    var body: some Scene {
        MenuBarExtra {
            ForEach(model.lines, id: \.self) { Text($0) }
            if let error = model.error {
                Divider()
                ForEach(error.components(separatedBy: "\n"), id: \.self) { Text($0) }
            }
            Divider()
            if let updated = model.updated { Text("Updated \(fmt(updated, "HH:mm", tz: .current))") }
            Button("Refresh") { Task { await model.refresh() } }.keyboardShortcut("r")
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            Button("Open RevenueCat dashboard") { NSWorkspace.shared.open(URL(string: "https://app.revenuecat.com")!) }
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Text(model.title)
        }
    }
}

RCBarApp.main()
