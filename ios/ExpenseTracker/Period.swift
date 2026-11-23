import SwiftUI

/// The range of days the Activity and Insights tabs show. Both ends are whole days, see `within`.
struct Period: Equatable {
    var from: Date
    var to: Date

    static func month(containing date: Date, calendar: Calendar = .current) -> Period {
        guard let month = calendar.dateInterval(of: .month, for: date) else {
            return Period(from: date, to: date)
        }
        return Period(from: month.start, to: month.end.addingTimeInterval(-1))
    }

    func isWholeMonth(calendar: Calendar = .current) -> Bool {
        let month = Period.month(containing: from, calendar: calendar)
        return calendar.isDate(from, inSameDayAs: month.from) && calendar.isDate(to, inSameDayAs: month.to)
    }

    /// Moves along when the day changes, but only while showing the month that was current. A custom
    /// range, or a month stepped to on purpose, stays as it is.
    func following(from previousDay: Date, to newDay: Date, calendar: Calendar = .current) -> Period {
        let wasCurrentMonth = isWholeMonth(calendar: calendar)
            && calendar.isDate(from, equalTo: previousDay, toGranularity: .month)
        return wasCurrentMonth ? Period.month(containing: newDay, calendar: calendar) : self
    }

    /// Always a whole month, so stepping away from a custom range lands on a month next to its start.
    func shifted(byMonths months: Int, calendar: Calendar = .current) -> Period {
        let date = calendar.date(byAdding: .month, value: months, to: from) ?? from
        return Period.month(containing: date, calendar: calendar)
    }

    var title: String {
        if isWholeMonth() {
            return from.formatted(.dateTime.month(.wide).year())
        }
        let sameYear = Calendar.current.isDate(from, equalTo: to, toGranularity: .year)
        let start = sameYear
            ? from.formatted(.dateTime.day().month(.abbreviated))
            : from.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(start) – \(to.formatted(.dateTime.day().month(.abbreviated).year()))"
    }
}

struct PeriodBar: View {
    @Binding var period: Period
    @State private var isPickingRange = false

    var body: some View {
        HStack {
            step("Previous month", systemImage: "chevron.left", months: -1)
            Button {
                isPickingRange = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityHidden(true)
                    Text(period.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Color.card, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.hairline) }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .foregroundStyle(.primary)
            .accessibilityHint("Choose a date range")
            step("Next month", systemImage: "chevron.right", months: 1)
        }
        .padding(.horizontal, 8)
        .background(Color.paper)
        .sheet(isPresented: $isPickingRange) {
            PeriodPicker(period: $period)
                .ledgerSheet()
                .presentationDetents([.medium])
        }
    }

    private func step(_ title: String, systemImage: String, months: Int) -> some View {
        Button(title, systemImage: systemImage) {
            period = period.shifted(byMonths: months)
        }
        .labelStyle(.iconOnly)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.ink)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

private struct PeriodPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var period: Period

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $period.from, in: ...period.to, displayedComponents: .date)
                    DatePicker("To", selection: $period.to, in: period.from..., displayedComponents: .date)
                }
                .ledgerRows()
                Section {
                    Button("This month") {
                        period = .month(containing: .now)
                        dismiss()
                    }
                }
                .ledgerRows()
            }
            .ledgerPage()
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
