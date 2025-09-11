import SwiftUI

/// Central repository for all design-related constants and tokens
/// Following design system principles for consistent UI across the app
public enum DesignTokens {
    
    // MARK: - Spacing
    public enum Spacing {
        /// 4pt - Minimal spacing for tight layouts
        public static let xs: CGFloat = 4
        
        /// 8pt - Small spacing for related elements
        public static let sm: CGFloat = 8
        
        /// 12pt - Medium-small spacing
        public static let md: CGFloat = 12
        
        /// 16pt - Default spacing between sections
        public static let lg: CGFloat = 16
        
        /// 20pt - Large spacing for major sections
        public static let xl: CGFloat = 20
        
        /// 24pt - Extra large spacing for visual separation
        public static let xxl: CGFloat = 24
        
        /// 32pt - Maximum spacing
        public static let xxxl: CGFloat = 32
    }
    
    // MARK: - Padding
    public enum Padding {
        /// 8pt - Small padding for compact elements
        public static let sm: CGFloat = 8
        
        /// 12pt - Medium padding for buttons and inputs
        public static let md: CGFloat = 12
        
        /// 16pt - Default padding for containers
        public static let lg: CGFloat = 16
        
        /// 20pt - Large padding for spacious layouts
        public static let xl: CGFloat = 20
    }
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        /// 4pt - Subtle rounding
        public static let xs: CGFloat = 4
        
        /// 8pt - Small radius for buttons and inputs
        public static let sm: CGFloat = 8
        
        /// 12pt - Medium radius
        public static let md: CGFloat = 12
        
        /// 16pt - Large radius for cards and modals
        public static let lg: CGFloat = 16
        
        /// 20pt - Extra large radius
        public static let xl: CGFloat = 20
    }
    
    // MARK: - Icon Sizes
    public enum IconSize {
        /// 16pt - Small icons
        public static let sm: CGFloat = 16
        
        /// 20pt - Default icon size
        public static let md: CGFloat = 20
        
        /// 24pt - Large icons
        public static let lg: CGFloat = 24
        
        /// 32pt - Extra large icons
        public static let xl: CGFloat = 32
        
        /// 64pt - Hero icons (e.g., play button)
        public static let hero: CGFloat = 64
    }
    
    // MARK: - Font Sizes
    public enum FontSize {
        /// 12pt - Caption text
        public static let caption: CGFloat = 12
        
        /// 14pt - Small body text
        public static let sm: CGFloat = 14
        
        /// 16pt - Default body text
        public static let body: CGFloat = 16
        
        /// 18pt - Large body text
        public static let lg: CGFloat = 18
        
        /// 20pt - Small heading
        public static let h3: CGFloat = 20
        
        /// 24pt - Medium heading
        public static let h2: CGFloat = 24
        
        /// 32pt - Large heading
        public static let h1: CGFloat = 32
    }
    
    // MARK: - Animation
    public enum Animation {
        /// 0.2s - Fast animations
        public static let fast: Double = 0.2
        
        /// 0.3s - Default animation duration
        public static let normal: Double = 0.3
        
        /// 0.5s - Slow animations
        public static let slow: Double = 0.5
    }
    
    // MARK: - Opacity
    public enum Opacity {
        /// 0.05 - Very subtle
        public static let subtle: Double = 0.05
        
        /// 0.1 - Light
        public static let light: Double = 0.1
        
        /// 0.3 - Disabled state
        public static let disabled: Double = 0.3
        
        /// 0.5 - Medium
        public static let medium: Double = 0.5
        
        /// 0.7 - Strong
        public static let strong: Double = 0.7
        
        /// 0.9 - Almost opaque
        public static let heavy: Double = 0.9
    }
    
    // MARK: - Grid & Layout
    public enum Grid {
        /// Default board size for new games
        public static let defaultBoardSize: Int = 15
        
        /// Minimum board dimension
        public static let minBoardSize: Int = 5
        
        /// Maximum board dimension for UI performance
        public static let maxBoardSize: Int = 50
    }
    
    // MARK: - Pagination
    public enum Pagination {
        /// Number of items from the end of the list to trigger loading more content
        /// This provides smooth infinite scroll by loading before reaching the bottom
        public static let lookaheadTrigger: Int = 5
    }
}