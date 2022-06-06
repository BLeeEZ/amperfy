import UIKit
import AmperfyKit

class AnimatedGradientLayer {
    
    private let gradientLayer: CAGradientLayer
    var colors: [CGColor] = [UIColor.white.cgColor, UIColor.white.cgColor]
    var startCorner: Corners = .topLeft
    var endCorner: Corners = .bottomRight
    
    var animationDuration: TimeInterval = 2
    var animationStyle: CAMediaTimingFunctionName = .linear
    
    init(view: UIView) {
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.locations = [0, 1]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func adjustTo(size: CGSize) {
        gradientLayer.frame = CGRect(x: gradientLayer.frame.origin.x, y: gradientLayer.frame.origin.y, width: size.width, height: size.height)
    }
    
    func setColors(_ newColors: [CGColor], isAnimated: Bool) {
        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = colors
        colorAnimation.toValue = newColors
        colorAnimation.duration = isAnimated ? animationDuration : TimeInterval(0.0)
        colorAnimation.isRemovedOnCompletion = false
        colorAnimation.fillMode = CAMediaTimingFillMode.forwards
        colorAnimation.timingFunction = CAMediaTimingFunction(name: animationStyle)
        gradientLayer.add(colorAnimation, forKey: "colorsChangeAnimation")
        colors = newColors
    }
    
    func setCorners(startCorner newStartCorner: Corners, endCorner newEndCorner: Corners, isAnimated: Bool) {
        let startPointAnimation = CABasicAnimation(keyPath: "startPoint")
        startPointAnimation.fromValue = startCorner.asPoint()
        startPointAnimation.toValue = newStartCorner.asPoint()
        startPointAnimation.duration = isAnimated ? animationDuration : TimeInterval(0.0)
        startPointAnimation.isRemovedOnCompletion = false
        startPointAnimation.fillMode = CAMediaTimingFillMode.forwards
        startPointAnimation.timingFunction = CAMediaTimingFunction(name: animationStyle)
        gradientLayer.add(startPointAnimation, forKey: "startPointChangeAnimation")
        startCorner = newStartCorner
        
        let endPointAnimation = CABasicAnimation(keyPath: "endPoint")
        endPointAnimation.fromValue = endCorner.asPoint()
        endPointAnimation.toValue = newEndCorner.asPoint()
        endPointAnimation.duration = isAnimated ? animationDuration : TimeInterval(0.0)
        endPointAnimation.isRemovedOnCompletion = false
        endPointAnimation.fillMode = CAMediaTimingFillMode.forwards
        endPointAnimation.timingFunction = CAMediaTimingFunction(name: animationStyle)
        gradientLayer.add(endPointAnimation, forKey: "endPointChangeAnimation")
        endCorner = newEndCorner
    }

}

class PopupAnimatedGradientLayer {

    let gradientLayer: AnimatedGradientLayer
    let colorPalette: [UIColor] = [
        UIColor(hue: 0.0   / 360.0, saturation: 1.0, lightness: 0.5, alpha: 1.0), // red
        UIColor(hue: 30.0  / 360.0, saturation: 1.0, lightness: 0.5, alpha: 1.0), // orange
        UIColor(hue: 60.0  / 360.0, saturation: 1.0, lightness: 0.5, alpha: 1.0), // yellow
        UIColor(hue: 120.0 / 360.0, saturation: 1.0, lightness: 0.5, alpha: 1.0), // green
        UIColor(hue: 180.0 / 360.0, saturation: 1.0, lightness: 0.5, alpha: 1.0), // cyan
        UIColor(hue: 210.0 / 360.0, saturation: 1.0, lightness: 0.5, alpha: 1.0)  // blue
    ]
    let lightnessDarkMode: CGFloat = 0.3
    let lightnessLightMode: CGFloat = 0.7
    var backgroundColorIndex = 0
    var customColor: UIColor?
    private var coloredCornerColor: UIColor {
        if let customColor = customColor {
            return customColor
        } else {
            return colorPalette[backgroundColorIndex]
        }
    }
    
    init(view: UIView) {
        gradientLayer = AnimatedGradientLayer(view: view)
    }
    
    private func getGradientColors(inStyle: UIUserInterfaceStyle) -> [CGColor] {
        if inStyle == .dark {
            return [coloredCornerColor.getWithLightness(of: lightnessDarkMode).cgColor, UIColor.black.cgColor]
        } else {
            return [coloredCornerColor.getWithLightness(of: lightnessLightMode).cgColor, UIColor.white.cgColor]
        }
    }
    
    func changeBackground(withStyleAndRandomColor style: UIUserInterfaceStyle) {
        customColor = nil
        backgroundColorIndex.setOtherRandomValue(in: 0...colorPalette.count-1)
        applyChange(style: style)
    }
    
    func changeBackground(style: UIUserInterfaceStyle, customColor: UIColor) {
        self.customColor = customColor
        applyChange(style: style)
    }
    
    private func applyChange(style: UIUserInterfaceStyle) {
        let firstCorner = gradientLayer.startCorner.rotateRandomly()
        let secondCorner = firstCorner.opposed()
        gradientLayer.setColors(self.getGradientColors(inStyle: style), isAnimated: true)
        gradientLayer.setCorners(startCorner: firstCorner, endCorner: secondCorner, isAnimated: true)
    }
    
    func applyStyleChange(_ newStyle: UIUserInterfaceStyle, isAnimated: Bool) {
        gradientLayer.setColors(self.getGradientColors(inStyle: newStyle), isAnimated: isAnimated)
    }
    
}
