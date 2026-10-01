//
//  ContentView.swift
//  LCD Date Watch App
//
//  A retro LCD date display. The main event is the complication
//  (see the LCDDateWidgets folder); this screen shows today's date and
//  how to put it on a watch face.
//

import Foundation
import SwiftUI

struct ContentView: View {
    /// Tap the date to switch between month first (10/01) and day first (01/10).
    @AppStorage("dayFirst") private var dayFirst = false
    private let lcdGreen = Color(red: 0.376, green: 1.0, blue: 0.573)
    private let lcdDim = Color(red: 0.376, green: 1.0, blue: 0.573).opacity(0.12)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TimelineView(.everyMinute) { context in
                    lcd(for: context.date)
                }
                .onTapGesture { dayFirst.toggle() }

                VStack(alignment: .leading, spacing: 6) {
                    Text("ADD TO WATCH FACE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(lcdGreen)
                    Text("1. Touch and hold your watch face.\n2. Tap Edit, then swipe to Complications.\n3. Tap a slot and choose LCD Date.\n4. Pick a style: month first like 10/01/2026, or day first like 01/10/2026, with slashes, dashes or dots.\n\nTip: tap the date above to switch the order here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
    }

    private func lcd(for date: Date) -> some View {
        // Regular month/day/year calendar in the watch's current time zone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.autoupdatingCurrent
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let month = String(format: "%02d", parts.month ?? 1)
        let day = String(format: "%02d", parts.day ?? 1)
        let year = String(parts.year ?? 2000)

        return VStack(spacing: 2) {
            Text(weekday(date))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(lcdGreen.opacity(0.7))
            ZStack {
                // Faint "88/88" behind the digits, like an unlit LCD segment
                Text("88/88")
                    .foregroundStyle(lcdDim)
                Text(dayFirst ? "\(day)/\(month)" : "\(month)/\(day)")
                    .foregroundStyle(lcdGreen)
                    .shadow(color: lcdGreen.opacity(0.6), radius: 6)
            }
            .font(.system(size: 44, weight: .bold, design: .monospaced))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            Text(year)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(lcdGreen.opacity(0.85))
            Text(dayFirst ? "DAY / MONTH" : "MONTH / DAY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(lcdGreen.opacity(0.45))
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.04, green: 0.09, blue: 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(lcdGreen.opacity(0.3), lineWidth: 1.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date.formatted(date: .complete, time: .omitted)))
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale.autoupdatingCurrent
        f.timeZone = TimeZone.autoupdatingCurrent
        f.dateFormat = "EEEE"
        return f.string(from: date).uppercased()
    }
}

#Preview {
    ContentView()
}
