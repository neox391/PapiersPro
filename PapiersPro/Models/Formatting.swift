import Foundation

extension Country {
    func money(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }

    func number(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    func date(_ value: Date) -> String {
        value.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale))
    }

    func longDate(_ value: Date) -> String {
        value.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }

    func time(_ value: Date) -> String {
        value.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
    }

    func dateTime(_ value: Date) -> String {
        "\(date(value)) à \(time(value))"
    }
}

enum DecimalParser {
    /// Parses user input accepting both "," and "." as decimal separator and ignoring spaces.
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
