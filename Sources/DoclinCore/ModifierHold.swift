/// A right-modifier hold cannot start or resume after a chord until released.
public struct ModifierHold {
    public enum Action { case none, arm, release, cancel }
    private var down = false
    private var blocked = false
    private var active = false
    public var isActive: Bool { active }
    public init() {}
    public mutating func update(down next: Bool, chord: Bool) -> Action {
        if !next {
            let wasActive = active
            down = false; blocked = false; active = false
            return wasActive ? .release : .none
        }
        let fresh = !down
        down = true
        if chord {
            blocked = true
            let wasActive = active; active = false
            return wasActive ? .cancel : .none
        }
        return fresh && !blocked ? .arm : .none
    }
    public mutating func activate() -> Bool {
        guard down, !blocked, !active else { return false }
        active = true; return true
    }
}
