import UIKit

final class OneFingerGestureRecognizer: UIGestureRecognizer {
    var onActions: (([PointerAction]) -> Void)?
    var onBegan: ((TimeInterval) -> Void)?
    weak var coordinateView: UIView?
    var mode: InputMode {
        get { input.mode }
        set {
            if newValue != input.mode { cancelInput() }
            input.mode = newValue
        }
    }
    private var input = OneFingerInput()
    private weak var touch: UITouch?
    private var holdTimer: Timer?

    init() {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touch == nil, touches.count == 1, let first = touches.first else {
            cancelInput()
            if state == .possible { state = .failed }
            return
        }
        touch = first
        let time = ProcessInfo.processInfo.systemUptime
        onBegan?(time)
        _ = input.began(at: first.location(in: coordinateView ?? view), time: time)
        let timer = Timer(timeInterval: OneFingerInput.holdDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.deliver(self.input.held(time: ProcessInfo.processInfo.systemUptime))
        }
        holdTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        deliver(input.moved(to: touch.location(in: coordinateView ?? view), time: ProcessInfo.processInfo.systemUptime))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        holdTimer?.invalidate()
        let actions = input.ended(at: touch.location(in: coordinateView ?? view), time: ProcessInfo.processInfo.systemUptime)
        state = .ended
        onActions?(actions)
        self.touch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        cancelInput()
        if state == .possible { state = .failed }
    }

    override func reset() {
        holdTimer?.invalidate()
        touch = nil
        if input.isActive { onActions?(input.cancel()) }
        super.reset()
    }

    func cancelInput() {
        holdTimer?.invalidate()
        let hadTouch = touch != nil
        touch = nil
        onActions?(input.cancel())
        if hadTouch {
            if state == .possible { state = .failed }
            else if state == .began || state == .changed { state = .cancelled }
        }
    }

    private func deliver(_ actions: [PointerAction]) {
        if input.recognized {
            holdTimer?.invalidate()
            state = state == .possible ? .began : .changed
        }
        onActions?(actions)
    }
}
