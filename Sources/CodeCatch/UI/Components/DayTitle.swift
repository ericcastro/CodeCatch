import Foundation

extension Date {
    /// A list's day heading: Today, Yesterday, or "Monday 27 Sep".
    var dayTitle: String {
        let calendar = Calendar.current
        return calendar.isDateInToday(self)
            ? "Today"
            : calendar.isDateInYesterday(self)
                ? "Yesterday"
                : formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
