//
//  LiquidFloatingActionButton.swift
//  Pods
//
//  Created by Takuma Yoshida on 2015/08/25.
//
//

import Foundation
import QuartzCore

// LiquidFloatingButton DataSource methods
@objc public protocol LiquidFloatingActionButtonDataSource {
	func imageForButton() -> UIImageView
    func numberOfCells(liquidFloatingActionButton: LiquidFloatingActionButton) -> Int
    func cellForIndex(index: Int) -> LiquidFloatingCell
}

@objc public protocol LiquidFloatingActionButtonDelegate {
    // selected method
	optional func liquidFloatingActionButton(liquidFloatingActionButton: LiquidFloatingActionButton, didSelectItemAtIndex index: Int)
	optional func liquidFloatingActionButtonDidStartOpenAnimation(liquidFloatingActionButton: LiquidFloatingActionButton)
	optional func liquidFloatingActionButtonDidStartCloseAnimation(liquidFloatingActionButton: LiquidFloatingActionButton)
	optional func liquidFloatingActionButtonDidEndCloseAnimation(liquidFloatingActionButton: LiquidFloatingActionButton)
}

@objc public enum LiquidFloatingActionButtonAnimateStyle : Int {
    case Up
    case Right
    case Left
    case Down
}

@IBDesignable
public class LiquidFloatingActionButton : UIView {

    private let internalRadiusRatio: CGFloat = 20.0 / 56.0
    public var cellRadiusRatio: CGFloat      = 0.38
    public var animateStyle: LiquidFloatingActionButtonAnimateStyle = .Up {
        didSet {
            baseView.animateStyle = animateStyle
        }
    }
	public var openAnimationDuration = 1.0 {
		didSet {
			baseView.openDuration = CGFloat(openAnimationDuration) - baseView.openDelay * CGFloat(dataSource!.numberOfCells(self))
		}
	}
	public var closeAnimationDuration = 1.0 {
		didSet {
			baseView.closeDuration = CGFloat(closeAnimationDuration)
		}
	}
    public var enableShadow = true {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public weak var delegate:   LiquidFloatingActionButtonDelegate?
	public weak var dataSource: LiquidFloatingActionButtonDataSource? {
		didSet {
			buttonView?.removeFromSuperview()
			buttonView = dataSource?.imageForButton()
			if let buttonView = buttonView {
				liquidView.addSubview(buttonView)
			}
		}
	}

    public var responsible = true
    public var isClosed: Bool {
        get {
            return buttonRotation == 0
        }
	}

    @IBInspectable public var buttonColor: UIColor = UIColor(red: 82 / 255.0, green: 112 / 255.0, blue: 235 / 255.0, alpha: 1.0)
	
	@IBInspectable public var iconColor: UIColor = UIColor(red: 82 / 255.0, green: 112 / 255.0, blue: 235 / 255.0, alpha: 1.0) {
		didSet {
			baseView.color = iconColor
		}
	}

    private let circleLayer = CAShapeLayer()

    public private(set) var touching = false
    private var buttonRotation: CGFloat = 0

    private var baseView = CircleLiquidBaseView()
    private let liquidView = UIView()
	private var buttonView: UIImageView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func insertCell(cell: LiquidFloatingCell) {
        cell.color  = self.iconColor
        cell.radius = self.frame.width * cellRadiusRatio
        cell.center = self.center.minus(self.frame.origin)
        cell.actionButton = self
        insertSubview(cell, aboveSubview: baseView)
    }
    
    private func cellArray() -> [LiquidFloatingCell] {
        var result: [LiquidFloatingCell] = []
        if let source = dataSource {
            for i in 0..<source.numberOfCells(self) {
                result.append(source.cellForIndex(i))
            }
        }
        return result
    }

    // open all cells
	public func open() {
		self.delegate?.liquidFloatingActionButtonDidStartOpenAnimation?(self);
		
		self.baseView.hidden = false
        // rotate button
        self.buttonRotation = CGFloat(-M_PI * 0.5) // 90 degrees

        let cells = cellArray()
        for cell in cells {
            insertCell(cell)
        }

		self.rotateButton(openAnimationDuration)
        self.baseView.open(cells)
		
        setNeedsDisplay()
    }

    // close all cells
    public func close() {
        // rotate button
        self.buttonRotation = 0
		
		self.rotateButton(closeAnimationDuration)
        self.baseView.close(cellArray())
        setNeedsDisplay()
		
		self.delegate?.liquidFloatingActionButtonDidStartCloseAnimation?(self);
    }
	
	private func rotateButton(duration: NSTimeInterval) {
		UIView.beginAnimations(nil, context: nil)
		UIView.setAnimationDuration(duration)
		liquidView.transform = CGAffineTransformMakeRotation(self.buttonRotation)
		UIView.commitAnimations()
	}
	
	func didStop() {
		if isClosed {
			delegate?.liquidFloatingActionButtonDidEndCloseAnimation?(self)
		}
	}

    // MARK: draw icon
    public override func drawRect(rect: CGRect) {
        drawCircle()
        drawShadow()
    }
    
    private func drawCircle() {
        self.circleLayer.frame = CGRect(origin: CGPointZero, size: self.frame.size)
        self.circleLayer.cornerRadius = self.frame.width * 0.5
        self.circleLayer.masksToBounds = true
        if touching && responsible {
            self.circleLayer.backgroundColor = self.buttonColor.white(0.5).CGColor
        } else {
            self.circleLayer.backgroundColor = self.buttonColor.CGColor
        }
    }
	
    private func drawShadow() {
        if enableShadow {
            circleLayer.appendShadow()
        }
    }

    // MARK: Events
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.touching = true
        setNeedsDisplay()
    }
    
    public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.touching = false
        setNeedsDisplay()
        didTapped()
    }
    
    public override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        self.touching = false
        setNeedsDisplay()
    }
    
    public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
		if isClosed == false {
			for cell in cellArray() {
				let pointForTargetView = cell.convertPoint(point, fromView: self)
				
				var biggerBounds = cell.bounds
				let size = biggerBounds.size.width
				biggerBounds.origin.x -= size / 2
				biggerBounds.origin.y -= size / 2
				biggerBounds.size.width += size
				biggerBounds.size.height += size
				
				if (CGRectContainsPoint(cell.bounds, pointForTargetView)) {
					if cell.userInteractionEnabled {
						return cell
					}
				}
			}
		}
		
        return super.hitTest(point, withEvent: event)
    }
    
    // MARK: private methods
    private func setup() {
        self.backgroundColor = UIColor.clearColor()
        self.clipsToBounds = false

        baseView.setup(self)
        addSubview(baseView)
		
		baseView.openDelay = 0.02
		
        
        liquidView.frame = baseView.frame
        liquidView.userInteractionEnabled = false
        addSubview(liquidView)
        
        liquidView.layer.addSublayer(circleLayer)
    }

    private func didTapped() {
        if isClosed {
            open()
        } else {
			close()
        }
    }
    
    public func didTappedCell(target: LiquidFloatingCell) {
        if let source = dataSource {
            let cells = cellArray()
            for i in 0..<cells.count {
                let cell = cells[i]
                if target === cell {
                    delegate?.liquidFloatingActionButton?(self, didSelectItemAtIndex: i)
                }
            }
        }
    }

}

class ActionBarBaseView : UIView {
    var opening = false
    func setup(actionButton: LiquidFloatingActionButton) {
    }
    
    func translateY(layer: CALayer, duration: CFTimeInterval, f: (CABasicAnimation) -> ()) {
        let translate = CABasicAnimation(keyPath: "transform.translation.y")
        f(translate)
        translate.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        translate.removedOnCompletion = false
        translate.fillMode = kCAFillModeForwards
        translate.duration = duration
        layer.addAnimation(translate, forKey: "transYAnim")
    }
}

class CircleLiquidBaseView : ActionBarBaseView {

    var openDuration: CGFloat  = 0.3
    var closeDuration: CGFloat = 0.2
	var openDelay: CGFloat = 0.05
    let viscosity: CGFloat     = 0.65
    var animateStyle: LiquidFloatingActionButtonAnimateStyle = .Up
    var color: UIColor = UIColor(red: 82 / 255.0, green: 112 / 255.0, blue: 235 / 255.0, alpha: 1.0) {
        didSet {
            engine?.color = color
            bigEngine?.color = color
        }
    }

    var baseLiquid: LiquittableCircle?
    var engine:     SimpleCircleLiquidEngine?
    var bigEngine:  SimpleCircleLiquidEngine?
    var enableShadow = true

    private var openingCells: [LiquidFloatingCell] = []
    private var keyDuration: CGFloat = 0
    private var displayLink: CADisplayLink?
	private weak var actionButton: LiquidFloatingActionButton?

    override func setup(actionButton: LiquidFloatingActionButton) {
		self.actionButton = actionButton
        self.frame = actionButton.frame
        self.center = actionButton.center.minus(actionButton.frame.origin)
        self.animateStyle = actionButton.animateStyle
        let radius = min(self.frame.width, self.frame.height) * 0.5
        self.engine = SimpleCircleLiquidEngine(radiusThresh: radius * 0.73, angleThresh: 0.45)
        engine?.viscosity = viscosity
        self.bigEngine = SimpleCircleLiquidEngine(radiusThresh: radius, angleThresh: 0.55)
        bigEngine?.viscosity = viscosity
        self.engine?.color = actionButton.iconColor
        self.bigEngine?.color = actionButton.iconColor

        baseLiquid = LiquittableCircle(center: self.center.minus(self.frame.origin), radius: radius, color: actionButton.iconColor)
        baseLiquid?.clipsToBounds = false
        baseLiquid?.layer.masksToBounds = false
        
        clipsToBounds = false
        layer.masksToBounds = false
        addSubview(baseLiquid!)
    }

    func open(cells: [LiquidFloatingCell]) {
        stop()
        let distance: CGFloat = self.frame.height * 1.25
        displayLink = CADisplayLink(target: self, selector: Selector("didDisplayRefresh:"))
        displayLink?.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        opening = true
        for cell in cells {
            cell.layer.removeAllAnimations()
            cell.layer.eraseShadow()
            openingCells.append(cell)
        }
    }
    
    func close(cells: [LiquidFloatingCell]) {
        stop()
        let distance: CGFloat = self.frame.height * 1.25
        opening = false
        displayLink = CADisplayLink(target: self, selector: Selector("didDisplayRefresh:"))
        displayLink?.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        for cell in cells {
            cell.layer.removeAllAnimations()
            cell.layer.eraseShadow()
            openingCells.append(cell)
            cell.userInteractionEnabled = false
        }
    }

    func didFinishUpdate() {
        if opening {
            for cell in openingCells {
                cell.userInteractionEnabled = true
            }
		} else {
			self.hidden = true
            for cell in openingCells {
                cell.removeFromSuperview()
            }
        }
    }

    func update(delay: CGFloat, duration: CGFloat, f: (LiquidFloatingCell, Int, CGFloat) -> ()) {
        if openingCells.isEmpty {
            return
        }

        let maxDuration = duration + CGFloat(openingCells.count) * CGFloat(delay)
        let t = keyDuration
        let allRatio = easeInEaseOut(t / maxDuration)

        if allRatio >= 1.0 {
            didFinishUpdate()
			stop()
			
			actionButton?.didStop()
			
            return
        }

        engine?.clear()
        bigEngine?.clear()
        for i in 0..<openingCells.count {
            let liquidCell = openingCells[i]
            let cellDelay = CGFloat(delay) * CGFloat(i)
            let ratio = easeInEaseOut((t - cellDelay) / duration)
            f(liquidCell, i, ratio)
        }

        if let firstCell = openingCells.first {
            bigEngine?.push(baseLiquid!, other: firstCell)
        }
        for i in 1..<openingCells.count {
            let prev = openingCells[i - 1]
            let cell = openingCells[i]
            engine?.push(prev, other: cell)
        }
        engine?.draw(baseLiquid!)
        bigEngine?.draw(baseLiquid!)
    }
    
    func updateOpen() {
        update(openDelay, duration: openDuration) { cell, i, ratio in
            let posRatio = ratio > CGFloat(i) / CGFloat(self.openingCells.count) ? ratio : 0
            let distance = (CGFloat(i + 1) * cell.frame.height * 1.5) * posRatio
            cell.center = self.center.plus(self.differencePoint(distance))
            cell.update(posRatio, open: true)
        }
    }
    
    func updateClose() {
        update(0, duration: closeDuration) { cell, i, ratio in
            let distance = (CGFloat(i + 1) * cell.frame.height * 1.5) * (1 - ratio)
            cell.center = self.center.plus(self.differencePoint(distance))
            cell.update(ratio, open: false)
        }
    }
    
    func differencePoint(distance: CGFloat) -> CGPoint {
        switch animateStyle {
        case .Up:
            return CGPoint(x: 0, y: -distance)
        case .Right:
            return CGPoint(x: distance, y: 0)
        case .Left:
            return CGPoint(x: -distance, y: 0)
        case .Down:
            return CGPoint(x: 0, y: distance)
        }
    }
    
    func stop() {
        for cell in openingCells {
            if enableShadow {
                cell.layer.appendShadow()
            }
        }
        openingCells = []
        keyDuration = 0
        displayLink?.invalidate()
    }
    
    func easeInEaseOut(t: CGFloat) -> CGFloat {
        if t >= 1.0 {
            return 1.0
        }
        if t < 0 {
            return 0
        }
        var t2 = t * 2
        return -1 * t * (t - 2)
    }
    
    func didDisplayRefresh(displayLink: CADisplayLink) {
        if opening {
            keyDuration += CGFloat(displayLink.duration)
            updateOpen()
        } else {
            keyDuration += CGFloat(displayLink.duration)
            updateClose()
        }
    }

}

public class LiquidFloatingCell : LiquittableCircle {
    
    let internalRatio: CGFloat = 0.75

    public var responsible = true
    public var imageView = UIImageView()
    weak var actionButton: LiquidFloatingActionButton?

    // for implement responsible color
    private var originalColor: UIColor
	
	private var label: UILabel?
    
    public override var frame: CGRect {
        didSet {
            resizeSubviews()
        }
    }

    init(center: CGPoint, radius: CGFloat, color: UIColor, icon: UIImage) {
        self.originalColor = color
        super.init(center: center, radius: radius, color: color)
        setup(icon)
    }

    init(center: CGPoint, radius: CGFloat, color: UIColor, view: UIView) {
        self.originalColor = color
        super.init(center: center, radius: radius, color: color)
        setupView(view)
    }
    
	public init(icon: UIImage, label: UILabel) {
        self.originalColor = UIColor.clearColor()
        super.init()
		
		self.label = label
        setup(icon, label)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
	func setup(image: UIImage, _ label: UILabel? = nil) {
        imageView.image = image.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        imageView.tintColor = .whiteColor()
        setupView(imageView)
		
		if let label = label {
			label.sizeToFit()
			label.frame.origin.x = -label.frame.size.width - 8
			label.textColor = .whiteColor()
			label.alpha = 0
			addSubview(label)
		}
    }
    
    func setupView(view: UIView) {
        userInteractionEnabled = false
        addSubview(view)
        resizeSubviews()
    }
	
	private func resizeSubviews() {
		if let imageSize = imageView.image?.size {
			imageView.frame.size = imageSize
			imageView.frame.origin.x = (frame.width - imageSize.width) / 2
			imageView.frame.origin.y = (frame.height - imageSize.height) / 2
		}
		if let label = label where label.frame.size.height < self.frame.size.height {
			label.frame.size.height = self.frame.size.height
		}
    }
    
    func update(key: CGFloat, open: Bool) {
        for subview in self.subviews {
            if let view = subview as? UIView {
                let ratio = max(2 * (key * key - 0.5), 0)
                view.alpha = open ? ratio : -ratio
            }
        }
    }
    
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if responsible {
            originalColor = color
            color = originalColor.white(0.5)
            setNeedsDisplay()
        }
    }
    
    public override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        if responsible {
            color = originalColor
            setNeedsDisplay()
        }
    }
    
    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        color = originalColor
        actionButton?.didTappedCell(self)
    }

}