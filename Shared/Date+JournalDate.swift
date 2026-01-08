import Foundation

extension Date {
    /// Returns the "journal date" for this Date.
    /// The journal day starts at 4 AM instead of midnight.
    /// So 1:00 AM on January 8th is treated as January 7th for journal purposes.
    var journalDate: Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)

        // If it's before 4 AM, treat it as the previous day
        if hour < 4 {
            return calendar.date(byAdding: .day, value: -1, to: self) ?? self
        }
        return self
    }
}
