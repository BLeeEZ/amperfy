import Foundation

public enum DownloadError: Error {
    
    case urlInvalid
    case noConnectivity
    case alreadyDownloaded
    case fetchFailed
    case emptyFile
    case apiErrorResponse
    case canceled
    
    public var description : String {
        switch self {
        case .urlInvalid: return "Invalid URL"
        case .noConnectivity: return "No Connectivity"
        case .alreadyDownloaded: return "Already Downloaded"
        case .fetchFailed: return "Fetch Failed"
        case .emptyFile: return "File is empty"
        case .apiErrorResponse: return "API Error"
        case .canceled: return "Cancled"
        }
    }
    
    var rawValue : Int {
        switch self {
        case .urlInvalid: return 1
        case .noConnectivity: return 2
        case .alreadyDownloaded: return 3
        case .fetchFailed: return 4
        case .emptyFile: return 5
        case .apiErrorResponse: return 6
        case .canceled: return 7
        }
    }
    
    public static func create(rawValue: Int) -> DownloadError? {
        switch rawValue {
        case 1: return .urlInvalid
        case 2: return .noConnectivity
        case 3: return .alreadyDownloaded
        case 4: return .fetchFailed
        case 5: return .emptyFile
        case 6: return .apiErrorResponse
        case 7: return .canceled
        default:
            return nil
        }
    }
}
