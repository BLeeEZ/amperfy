import NotificationBanner

class AmperfyBannerColors: BannerColorsProtocol {

    internal func color(for style: BannerStyle) -> UIColor {
        switch style {
        case .danger: return .red
        case .info:  return .defaultBlue
        case .customView: return .defaultBlue
        case .success: return .green
        case .warning: return .yellow
        }
    }

}

extension BannerStyle {
    
    static func from(logType: LogEntryType) -> BannerStyle {
        switch logType {
        case .apiError:
            return .danger
        case .error:
            return .danger
        case .info:
            return .info
        case .debug:
            return .info
        }
    }
    
}
