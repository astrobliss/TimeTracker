import Foundation

enum TimeFormatter {
    // MARK: - Cached DateFormatters
    
    /// "h a" format (e.g. "9 AM")
    static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f
    }()
    
    /// Short time style (e.g. "9:41 AM")
    static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    /// Full date style (e.g. "Monday, February 9, 2026")
    static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()
    
    /// Medium date style (e.g. "Feb 9, 2026")
    static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    /// "MMMM yyyy" format (e.g. "February 2026")
    static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    
    /// "EEE" format (e.g. "Mon")
    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    // MARK: - Formatting
    
    static func format(seconds: Int, showSign: Bool = false) -> String {
        let absSeconds = abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        let secs = absSeconds % 60
        
        var result: String
        if hours > 0 {
            result = String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            result = String(format: "%d:%02d", minutes, secs)
        }
        
        if showSign && seconds < 0 {
            result = "-" + result
        }
        
        return result
    }
    
    static func formatHoursMinutes(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // MARK: - Parsing
    
    static func parse(hours: Int, minutes: Int, seconds: Int = 0) -> Int {
        return hours * 3600 + minutes * 60 + seconds
    }
}
