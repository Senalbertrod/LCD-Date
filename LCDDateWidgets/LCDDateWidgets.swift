//
//  LCDDateWidgets.swift
//  LCDDateWidgets
//
//  The LCD Date complications: today's month, day and year as numbers
//  (month first or day first, with the year or the day name),
//  in a retro digital-watch style.
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Date style (chosen when you add the complication)

enum SeparatorOption: String, AppEnum {
    case slash, dash, dot

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Separator"
    static var caseDisplayRepresentations: [SeparatorOption: DisplayRepresentation] = [
        .slash: "Slash  10/01",
        .dash: "Dash  10-01",
        .dot: "Dot  10.01",
    ]

    var symbol: String {
        switch self {
        case .slash: return "/"
        case .dash: return "-"
        case .dot: return "."
        }
    }
}

enum DateOrderOption: String, AppEnum {
    case monthFirst, dayFirst

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Order"
    static var caseDisplayRepresentations: [DateOrderOption: DisplayRepresentation] = [
        .monthFirst: "Month first  10/01",
        .dayFirst: "Day first  01/10",
    ]
}

enum ExtraOption: String, AppEnum {
    case year, weekday

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static var caseDisplayRepresentations: [ExtraOption: DisplayRepresentation] = [
        .year: "Year  10/01/2026",
        .weekday: "Day name  Thursday 10/01",
    ]
}

struct DateStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Date Style"
    static var description = IntentDescription("Choose how the month, day and year look.")

    @Parameter(title: "Order", default: .monthFirst)
    var order: DateOrderOption

    @Parameter(title: "Separator", default: .slash)
    var separator: SeparatorOption

    @Parameter(title: "Leading zeros", default: true)
    var leadingZeros: Bool

    @Parameter(title: "Show", default: .year)
    var extra: ExtraOption
}

/// Turns a date into "10/01/2026" (or day-first "01/10/2026") text using the chosen style.
struct DateStyle {
    var dayFirst = false
    var separator = "/"
    var leadingZeros = true
    /// Show the day name (on top) instead of the year (underneath).
    var showWeekday = false

    init() {}

    init(_ intent: DateStyleIntent) {
        dayFirst = intent.order == .dayFirst
        separator = intent.separator.symbol
        leadingZeros = intent.leadingZeros
        showWeekday = intent.extra == .weekday
    }

    /// Always the regular month/day/year calendar, in whatever time zone
    /// the watch is in right now (it updates itself when you travel).
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.autoupdatingCurrent
        return cal
    }

    private func parts(_ date: Date) -> (month: Int, day: Int, year: Int) {
        let c = DateStyle.calendar.dateComponents([.year, .month, .day], from: date)
        return (c.month ?? 1, c.day ?? 1, c.year ?? 2000)
    }

    private func number(_ n: Int) -> String {
        leadingZeros && n < 10 ? "0\(n)" : "\(n)"
    }

    func month(_ date: Date) -> String { number(parts(date).month) }
    func day(_ date: Date) -> String { number(parts(date).day) }

    /// Always the full four-digit year, like "2026".
    func year(_ date: Date) -> String { "\(parts(date).year)" }

    /// "10/01" month first, or "01/10" day first.
    func monthDay(_ date: Date) -> String {
        dayFirst ? day(date) + separator + month(date) : month(date) + separator + day(date)
    }

    /// "10/01/2026" month first, or "01/10/2026" day first. The year is always last.
    func full(_ date: Date) -> String { monthDay(date) + separator + year(date) }

    /// "THURSDAY" in the watch's language.
    func weekday(_ date: Date) -> String { weekdayName(date, format: "EEEE") }

    /// "THU", for the small round complication.
    func shortWeekday(_ date: Date) -> String { weekdayName(date, format: "EEE") }

    private func weekdayName(_ date: Date, format: String) -> String {
        let f = DateFormatter()
        f.calendar = DateStyle.calendar
        f.locale = Locale.autoupdatingCurrent
        f.timeZone = TimeZone.autoupdatingCurrent
        f.dateFormat = format
        return f.string(from: date).uppercased()
    }

    /// One line: "10/01/2026", or "THURSDAY 10/01" when showing the day name.
    func line(_ date: Date) -> String {
        showWeekday ? weekday(date) + " " + monthDay(date) : full(date)
    }
}

// MARK: - Timeline

struct MDEntry: TimelineEntry {
    let date: Date
    let style: DateStyle
}

/// One provider per complication. Apple Watch shows at most 15 ready-made
/// choices per complication, so month-first and day-first each get their own
/// complication with 12 choices.
struct MDProvider: AppIntentTimelineProvider {
    /// Which order this complication's list of choices offers.
    let listOrder: DateOrderOption
    /// The Day first complication always shows day first. The original complication
    /// (Month first) respects whatever order was saved, so faces set up earlier keep working.
    let forcesOrder: Bool

    private func makeStyle(_ configuration: DateStyleIntent) -> DateStyle {
        var s = DateStyle(configuration)
        if forcesOrder { s.dayFirst = listOrder == .dayFirst }
        return s
    }

    func placeholder(in context: Context) -> MDEntry {
        var s = DateStyle()
        s.dayFirst = listOrder == .dayFirst
        return MDEntry(date: Date(), style: s)
    }

    func snapshot(for configuration: DateStyleIntent, in context: Context) async -> MDEntry {
        MDEntry(date: Date(), style: makeStyle(configuration))
    }

    /// An entry every 15 minutes for the next 24 hours, then a fresh timeline.
    ///
    /// Why not just one entry per midnight? Midnight depends on the time zone.
    /// If you fly to another country, midnights planned for the old time zone
    /// would flip the date hours late. Every time zone on Earth is a multiple
    /// of 15 minutes from UTC, and each entry is drawn using the watch's
    /// *current* time zone, so the date always flips at your local midnight,
    /// wherever you are. 97 tiny entries a day is still very light on battery.
    func timeline(for configuration: DateStyleIntent, in context: Context) async -> Timeline<MDEntry> {
        let style = makeStyle(configuration)
        let now = Date()
        var entries = [MDEntry(date: now, style: style)]

        // Line up with the next quarter hour (:00, :15, :30, :45) in UTC.
        let quarter: TimeInterval = 15 * 60
        let nextQuarter = Date(timeIntervalSince1970: (now.timeIntervalSince1970 / quarter).rounded(.down) * quarter + quarter)
        for step in 0..<96 {
            entries.append(MDEntry(date: nextQuarter.addingTimeInterval(Double(step) * quarter), style: style))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// On Apple Watch, these appear as ready-made choices when you add the complication.
    func recommendations() -> [AppIntentRecommendation<DateStyleIntent>] {
        func make(_ separator: SeparatorOption, zeros: Bool, weekday: Bool,
                  order: DateOrderOption) -> DateStyleIntent {
            let intent = DateStyleIntent()
            intent.order = order
            intent.separator = separator
            intent.leadingZeros = zeros
            intent.extra = weekday ? .weekday : .year
            return intent
        }
        // For each order and separator, four choices side by side:
        // with zeros + year, with zeros + day name, no zeros + year, no zeros + day name.
        // The descriptions use Thursday, October 1, 2026 as the example.
        var list: [AppIntentRecommendation<DateStyleIntent>] = []
        for order in [listOrder] {
            let label = order == .monthFirst ? "Month first" : "Day first"
            for separator in [SeparatorOption.slash, .dash, .dot] {
                let sep = separator.symbol
                for zeros in [true, false] {
                    let month = "10", day = zeros ? "01" : "1"
                    let md = order == .monthFirst ? month + sep + day : day + sep + month
                    list.append(AppIntentRecommendation(
                        intent: make(separator, zeros: zeros, weekday: false, order: order),
                        description: Text(verbatim: "\(label) \(md)\(sep)2026")))
                    list.append(AppIntentRecommendation(
                        intent: make(separator, zeros: zeros, weekday: true, order: order),
                        description: Text(verbatim: "\(label) Thursday \(md)")))
                }
            }
        }
        return list
    }
}

// MARK: - Complication views

struct MDWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MDEntry

    private var style: DateStyle { entry.style }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // No circle behind it, like PM & DST: just the text on the watch face.
            VStack(spacing: 0) {
                if style.showWeekday {
                    // Day name on top: THU over 10/01
                    Text(style.shortWeekday(entry.date))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Text(style.monthDay(entry.date))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .widgetAccentable()
                if !style.showWeekday {
                    // Year underneath: 10/01 over 2026
                    Text(style.year(entry.date))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 3)

        case .accessoryRectangular:
            // Always the day name and the full date with the year.
            VStack(alignment: .leading, spacing: 1) {
                Text(style.weekday(entry.date))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(style.full(entry.date))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryCorner:
            Text(style.monthDay(entry.date))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .widgetAccentable()
                .widgetLabel {
                    Text(style.showWeekday ? style.weekday(entry.date) : style.year(entry.date))
                }

        default: // .accessoryInline
            Text(style.line(entry.date))
        }
    }
}

// MARK: - Widget

/// "Month first": 10/01/2026. Keeps the original kind so faces set up earlier keep working.
struct MDWidget: Widget {
    let kind = "MDDateWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DateStyleIntent.self,
                               provider: MDProvider(listOrder: .monthFirst, forcesOrder: false)) { entry in
            MDWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Month first")
        .description("Today's date as numbers, month first, retro style.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

/// "Day first": 01/10/2026.
struct MDDayFirstWidget: Widget {
    let kind = "MDDateDayFirstWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DateStyleIntent.self,
                               provider: MDProvider(listOrder: .dayFirst, forcesOrder: true)) { entry in
            MDWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Day first")
        .description("Today's date as numbers, day first, retro style.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

/// Two complications, each with 12 ready-made styles (Apple Watch shows at most 15 per complication).
@main
struct MDWidgetBundle: WidgetBundle {
    var body: some Widget {
        MDWidget()
        MDDayFirstWidget()
    }
}
