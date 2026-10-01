//
//  LCDDateWidgets.swift
//  LCDDateWidgets
//
//  The LCD Date complications: today's month, day and year as numbers
//  (month first or day first),
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

struct DateStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Date Style"
    static var description = IntentDescription("Choose how the month, day and year look.")

    @Parameter(title: "Order", default: .monthFirst)
    var order: DateOrderOption

    @Parameter(title: "Separator", default: .slash)
    var separator: SeparatorOption

    @Parameter(title: "Leading zeros", default: true)
    var leadingZeros: Bool

    @Parameter(title: "Short year", default: false)
    var shortYear: Bool
}

/// Turns a date into "10/01/2026" (or day-first "01/10/2026") text using the chosen style.
struct DateStyle {
    var dayFirst = false
    var separator = "/"
    var leadingZeros = true
    var shortYear = false

    init() {}

    init(_ intent: DateStyleIntent) {
        dayFirst = intent.order == .dayFirst
        separator = intent.separator.symbol
        leadingZeros = intent.leadingZeros
        shortYear = intent.shortYear
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

    func year(_ date: Date) -> String {
        let y = parts(date).year
        if shortYear {
            let short = y % 100
            return short < 10 ? "0\(short)" : "\(short)"
        }
        return "\(y)"
    }

    /// "10/01" month first, or "01/10" day first.
    func monthDay(_ date: Date) -> String {
        dayFirst ? day(date) + separator + month(date) : month(date) + separator + day(date)
    }

    /// "10/01/2026" month first, or "01/10/2026" day first. The year is always last.
    func full(_ date: Date) -> String { monthDay(date) + separator + year(date) }

    func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = DateStyle.calendar
        f.locale = Locale.autoupdatingCurrent
        f.timeZone = TimeZone.autoupdatingCurrent
        f.dateFormat = "EEEE"
        return f.string(from: date).uppercased()
    }
}

// MARK: - Timeline

struct MDEntry: TimelineEntry {
    let date: Date
    let style: DateStyle
}

struct MDProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MDEntry {
        MDEntry(date: Date(), style: DateStyle())
    }

    func snapshot(for configuration: DateStyleIntent, in context: Context) async -> MDEntry {
        MDEntry(date: Date(), style: DateStyle(configuration))
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
        let style = DateStyle(configuration)
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
        func make(_ separator: SeparatorOption, zeros: Bool, shortYear: Bool,
                  order: DateOrderOption = .monthFirst) -> DateStyleIntent {
            let intent = DateStyleIntent()
            intent.order = order
            intent.separator = separator
            intent.leadingZeros = zeros
            intent.shortYear = shortYear
            return intent
        }
        return [
            AppIntentRecommendation(intent: make(.slash, zeros: true, shortYear: false), description: "Month first 10/01/2026"),
            AppIntentRecommendation(intent: make(.dash, zeros: true, shortYear: false), description: "Month first 10-01-2026"),
            AppIntentRecommendation(intent: make(.dot, zeros: true, shortYear: false), description: "Month first 10.01.2026"),
            AppIntentRecommendation(intent: make(.dot, zeros: true, shortYear: true), description: "Month first 10.01.26"),
            AppIntentRecommendation(intent: make(.slash, zeros: false, shortYear: false), description: "Month first 10/1/2026"),
            // Day first (day/month/year), as used in most of the world
            AppIntentRecommendation(intent: make(.slash, zeros: true, shortYear: false, order: .dayFirst), description: "Day first 01/10/2026"),
            AppIntentRecommendation(intent: make(.dash, zeros: true, shortYear: false, order: .dayFirst), description: "Day first 01-10-2026"),
            AppIntentRecommendation(intent: make(.dot, zeros: true, shortYear: false, order: .dayFirst), description: "Day first 01.10.2026"),
            AppIntentRecommendation(intent: make(.dot, zeros: true, shortYear: true, order: .dayFirst), description: "Day first 01.10.26"),
            AppIntentRecommendation(intent: make(.slash, zeros: false, shortYear: false, order: .dayFirst), description: "Day first 1/10/2026"),
        ]
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
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(style.monthDay(entry.date))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text(style.year(entry.date))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(.horizontal, 3)
            }

        case .accessoryRectangular:
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
                    Text(style.year(entry.date))
                }

        default: // .accessoryInline
            Text(style.full(entry.date))
        }
    }
}

// MARK: - Widget

struct MDWidget: Widget {
    let kind = "MDDateWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DateStyleIntent.self, provider: MDProvider()) { entry in
            MDWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Month · Day · Year")
        .description("Today's date as numbers, retro style.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

@main
struct MDWidgetBundle: WidgetBundle {
    var body: some Widget {
        MDWidget()
    }
}
