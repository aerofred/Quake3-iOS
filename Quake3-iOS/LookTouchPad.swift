import UIKit

/// Hold and drag to look around; keeps tracking even if the finger leaves the pad.
final class LookTouchPad: UIView {

    var onLookDelta: ((CGFloat, CGFloat) -> Void)?

    private var lastPoint: CGPoint?
    private let titleLabel = UILabel()
    private let baseImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        alpha = 0.5

        baseImageView.image = UIImage(named: "JoyStickBase")
        baseImageView.contentMode = .scaleToFill
        addSubview(baseImageView)

        titleLabel.text = "LOOK"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 11)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseImageView.frame = bounds
        titleLabel.frame = bounds
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastPoint = touch.location(in: trackingView)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: trackingView)
        if let last = lastPoint {
            let dx = location.x - last.x
            let dy = location.y - last.y
            if abs(dx) >= 0.25 || abs(dy) >= 0.25 {
                onLookDelta?(dx, dy)
            }
        }
        lastPoint = location
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPoint = nil
    }

    private var trackingView: UIView {
        superview ?? self
    }
}
