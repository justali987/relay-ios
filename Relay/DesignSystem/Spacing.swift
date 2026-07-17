import CoreGraphics

/// Spacing and corner-radius tokens. Keeping these centralized is what lets every screen share one
/// rhythm instead of screen-local magic numbers.
enum RelaySpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum RelayRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 22
    /// Remote-screen primary controls (D-pad, power) use a larger radius for a softer, more
    /// tactile feel without reading as childish.
    static let control: CGFloat = 28
}

/// Minimum interactive target per Apple's HIG and this project's accessibility bar. Primary remote
/// controls (D-pad, volume, power) should exceed this, not just meet it.
enum RelayHitTarget {
    static let minimum: CGFloat = 44
    static let primaryControl: CGFloat = 64
}
