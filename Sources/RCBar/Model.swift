import AppKit
import ServiceManagement

/// Delta to report as an event, or nil (first value, no change, or fiscal month rolled over).
func eventDelta(old: Double?, oldMonth: String?, new: Double, month: String) -> Double? {
    guard let old, oldMonth == month, abs(new - old) >= 0.005 else { return nil }
    return new - old
}

let cashSound = NSSound(named: "Glass")

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
                defaults.set(today, forKey: "eventDate")
                if delta > 0, !defaults.bool(forKey: "muted") { cashSound?.play() }
            }
            defaults.set(cur.value, forKey: "baseline")
            defaults.set(month, forKey: "baselineMonth")

            let next = months[0], nextRev = amounts[0]
            title = money(cur.value, cur.currency)
            lines = [
                "Next payout · \(fmt(next.payout, "EEE MMM d")): \(money(nextRev.value, nextRev.currency))",
                "    covers \(fmt(next.start, "MMM d")) – \(fmt(next.end, "MMM d"))",
            ]
            if let date = defaults.object(forKey: "eventDate") as? Date {
                let delta = defaults.double(forKey: "eventDelta")
                lines.append("Latest: \(delta >= 0 ? "+" : "-")\(money(abs(delta), cur.currency)) · \(fmt(date, Calendar.current.isDateInToday(date) ? "HH:mm" : "MMM d HH:mm", tz: .current))")
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
