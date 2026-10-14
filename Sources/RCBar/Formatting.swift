import Foundation

/// Formats in Pacific time by default (fiscal dates); pass `.current` for wall-clock times.
func fmt(_ d: Date, _ pattern: String, tz: TimeZone = cal.timeZone) -> String {
    let f = DateFormatter()
    f.calendar = cal
    f.timeZone = tz
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = pattern
    return f.string(from: d)
}

func money(_ v: Double, _ currency: String) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currency
    return f.string(from: NSNumber(value: v)) ?? "\(v) \(currency)"
}
