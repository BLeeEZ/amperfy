import Foundation

struct ClockTime {
    
    var seconds: Int = 0
    var minutes: Int = 0
    var hours: Int = 0
    private var sign: Int = 1

    init(timeInSeconds: Int) {
        if timeInSeconds < 0 {
            sign = -1
        }
        let signFreeSeconds = timeInSeconds * sign
        seconds = (signFreeSeconds % 3600) % 60
        minutes = (signFreeSeconds % 3600) / 60
        hours = signFreeSeconds / 3600
    }

    func asShortString() -> String {
        var shortString = ""
        if sign < 0 {
            shortString = "-"
        }
        
        if hours > 0 {
            shortString.append( String(format: "%d:%02d:%02d", hours, minutes, seconds) )
        } else {
            shortString.append( String(format: "%d:%02d", minutes, seconds) )
        }
        return shortString
    }

}
