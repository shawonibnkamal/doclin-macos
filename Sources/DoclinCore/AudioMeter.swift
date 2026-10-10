import Foundation

public enum AudioMeter {
    /// Speech needs a logarithmic display: linear amplitude hides quieter voices.
    public static func level(decibels: Float) -> Float {
        guard decibels.isFinite else { return 0 }
        return min(1, max(0, (decibels + 60) / 48))
    }

    public static func level(rms: Float) -> Float {
        guard rms.isFinite, rms > 0 else { return 0 }
        return level(decibels: 20 * log10(rms))
    }
}
