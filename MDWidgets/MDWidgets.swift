//
//  MDWidgets.swift
//  MDWidgets
//
//  The M-D complications: today's month, day and year as numbers,
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

struct DateStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Date Style"
    static var description = IntentDescription("Choose how the month, day and year look.")

    @Parameter(title: "Separator", default: .slash)
    var separator: SeparatorOption

    @Parameter(title: "Leading zeros", default: true)
    var leadingZeros: Bool

    @Parameter(title: "Short year", default: false)
    var shortYear: Bool
}

/// Turns a date into "10/01/2026"-style text using the chosen style.
struct DateStyle {
    var separator = "/"
    var leadingZeros = true
    var shortYear = false

    init() {}

    init(_ intent: DateStyleIntent) {
        separator = intent.separator.symbol
        leadingZeros = intent.leadingZeros
        shortYear = intent.shortYear
    }

    private func parts(_ date: Date) -> (month: Int, day: Int, year: Int) {
        let c = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
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

    func monthDay(_ date: Date) -> String { month(date) + separator + day(date) }
    func full(_ date: Date) -> String { monthDay(date) + separator + year(date) }

    func weekday(_ date: Date) -> String {
        let f = DateFormatter()
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

    /// One entry now, then one at each of the next 7 midnights, so the date
    /// flips right at 12:00 AM with almost no battery use.
    func timeline(for configuration: DateStyleIntent, in context: Context) async -> Timeline<MDEntry> {
        let style = DateStyle(configuration)
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        var entries = [MDEntry(date: now, style: style)]
        let today = calendar.startOfDay(for: now)
        for offset in 1...7 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(MDEntry(date: midnight, style: style))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// On Apple Watch, these appear as ready-made choices when you add the complication.
    func recommendations() -> [AppIntentRecommendation<DateStyleIntent>] {
        func make(_ separator: SeparatorOption, zeros: Bool, shortYear: Bool) -> DateStyleIntent {
            let intent = DateStyleIntent()
            intent.separator = separator
            intent.leadingZeros = zeros
            intent.shortYear = shortYear
            return intent
        }
        return [
            AppIntentRecommendation(intent: make(.slash, zeros: true, shortYear: false), description: "10/01/2026"),
            AppIntentRecommendation(intent: make(.dash, zeros: true, shortYear: false), description: "10-01-2026"),
            AppIntentRecommendation(intent: make(.dot, zeros: true, shortYear: false), description: "10.01.2026"),
            AppIntentRecommendation(intent: make(.dot, zeros: true, shortYear: true), description: "10.01.26"),
            AppIntentRecommendation(intent: make(.slash, zeros: false, shortYear: false), description: "10/1/2026"),
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
