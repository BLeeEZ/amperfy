import Foundation

public struct ClockTime {
    
    public var seconds: Int = 0
    public var minutes: Int = 0
    public var hours: Int = 0
    private var sign: Int = 1

    public init(timeInSeconds: Int) {
        if timeInSeconds < 0 {
            sign = -1
        }
        let signFreeSeconds = timeInSeconds * sign
        seconds = (signFreeSeconds % 3600) % 60
        minutes = (signFreeSeconds % 3600) / 60
        hours = signFreeSeconds / 3600
    }

    public func asShortString() -> String {
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
