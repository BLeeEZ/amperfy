import UIKit

enum Corners: Int {
    case topRight
    case bottomRight
    case bottomLeft
    case topLeft
    
    func asPoint() -> CGPoint {
        return convertToPoint(corner: self)
    }
    
    private func convertToPoint(corner: Corners) -> CGPoint {
        switch self {
        case .topRight:
            return CGPoint(x: 1.0, y: 0.0)
        case .bottomRight:
            return CGPoint(x: 1.0, y: 1.0)
        case .bottomLeft:
            return CGPoint(x: 0.0, y: 1.0)
        case .topLeft:
            return CGPoint(x: 0.0, y: 0.0)
        }
    }
    
    func opposed() -> Corners {
        switch self {
        case .topRight:
            return .bottomLeft
        case .bottomRight:
            return .topLeft
        case .bottomLeft:
            return .topRight
        case .topLeft:
            return .bottomRight
        }
    }
    
    func rotateRandomly() -> Corners {
        if Bool.random() {
            return rotateClockwise()
        } else {
            return rotateCounterclockwise()
        }
    }
    
    func rotateClockwise() -> Corners {
        let raw = self.rawValue
        let rotatedRaw = (raw + 1) % (Corners.topLeft.rawValue+1)
        return Corners(rawValue: rotatedRaw)!
    }
    
    func rotateCounterclockwise() -> Corners {
        let raw = self.rawValue
        if raw == 0 {
            return .topLeft
        }
        return Corners(rawValue: raw - 1)!
    }
    
    static func randomElement() -> Corners {
        let randomRawValue = Int.random(in: Corners.topRight.rawValue...Corners.topLeft.rawValue)
        return Corners(rawValue: randomRawValue)!
    }
}
