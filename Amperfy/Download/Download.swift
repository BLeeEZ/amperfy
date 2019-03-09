import Foundation

class Download {
    
    var url: URL

    var task: URLSessionDownloadTask?
    var isDownloading = false
    var error: DownloadError?
    var resumeData: Data?

    var progress: Float = 0
    var totalSize: String = ""
    
    init(url: URL) {
        self.url = url
    }
    
}
