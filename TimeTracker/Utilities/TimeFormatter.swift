import Foundation

enum TimeFormatter {
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
    
    static func parse(hours: Int, minutes: Int, seconds: Int = 0) -> Int {
        return hours * 3600 + minutes * 60 + seconds
    }
}
