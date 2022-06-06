import Foundation

class PlayerNotificationAdapter {
    
    let notificationHandler: EventNotificationHandler
    
    init(notificationHandler: EventNotificationHandler) {
        self.notificationHandler = notificationHandler
    }
    
}

extension PlayerNotificationAdapter: MusicPlayable {
    func didStartPlaying() {
        notificationHandler.post(name: .playerPlay, object: self, userInfo: nil)
    }
    func didPause() {
        notificationHandler.post(name: .playerPause, object: self, userInfo: nil)
    }
    func didStopPlaying() {
        notificationHandler.post(name: .playerStop, object: self, userInfo: nil)
    }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
