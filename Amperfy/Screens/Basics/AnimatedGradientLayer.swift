import UIKit

class AnimatedGradientLayer: CAGradientLayer {
    var oldColors: [CGColor]?
    var oldStartPoint: CGPoint?
    var oldEndPoint: CGPoint?
    var oldStartCorner: Corners?
    var oldEndCorner: Corners?
    
    func setColors(_ newColors: [CGColor],
                   animated: Bool = true,
                   withDuration duration: TimeInterval = 0,
                   timingFunctionName name: CAMediaTimingFunctionName? = nil) {
        if !animated {
            self.colors = newColors
            oldColors = newColors
            return
        }
        
        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = oldColors
        colorAnimation.toValue = newColors
        colorAnimation.duration = duration
        colorAnimation.isRemovedOnCompletion = false
        colorAnimation.fillMode = CAMediaTimingFillMode.forwards
        colorAnimation.timingFunction = CAMediaTimingFunction(name: name ?? .linear)
        add(colorAnimation, forKey: "colorsChangeAnimation")
        oldColors = newColors
    }
    
    func setColors(_ newColors: [CGColor],
                   newStartPoint: CGPoint,
                   newEndPoint: CGPoint,
                   animated: Bool = true,
                   withDuration duration: TimeInterval = 0,
                   timingFunctionName name: CAMediaTimingFunctionName? = nil) {
        setColors(newColors, animated: animated, withDuration: duration, timingFunctionName: name)
        
        if !animated {
            self.startPoint = newStartPoint
            self.endPoint = newEndPoint
            return
        }
        
        let startPointAnimation = CABasicAnimation(keyPath: "startPoint")
        startPointAnimation.fromValue = oldStartPoint
        startPointAnimation.toValue = newStartPoint
        startPointAnimation.duration = duration
        startPointAnimation.isRemovedOnCompletion = false
        startPointAnimation.fillMode = CAMediaTimingFillMode.forwards
        startPointAnimation.timingFunction = CAMediaTimingFunction(name: name ?? .linear)
        add(startPointAnimation, forKey: "startPointChangeAnimation")
        oldStartPoint = newStartPoint
        
        let endPointAnimation = CABasicAnimation(keyPath: "endPoint")
        endPointAnimation.fromValue = oldEndPoint
        endPointAnimation.toValue = newEndPoint
        endPointAnimation.duration = duration
        endPointAnimation.isRemovedOnCompletion = false
        endPointAnimation.fillMode = CAMediaTimingFillMode.forwards
        endPointAnimation.timingFunction = CAMediaTimingFunction(name: name ?? .linear)
        add(endPointAnimation, forKey: "endPointChangeAnimation")
        oldEndPoint = newEndPoint
    }
    
    func setColors(_ newColors: [CGColor],
                   newStartCorner: Corners,
                   newEndCorner: Corners,
                   animated: Bool = true,
                   withDuration duration: TimeInterval = 0,
                   timingFunctionName name: CAMediaTimingFunctionName? = nil) {
        oldStartCorner = newStartCorner
        oldEndCorner = newEndCorner
        
        setColors(newColors, newStartPoint: newStartCorner.asPoint(), newEndPoint: newEndCorner.asPoint(), animated: animated, withDuration: duration, timingFunctionName: name)
    }
}
