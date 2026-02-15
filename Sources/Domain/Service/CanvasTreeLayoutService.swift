import Foundation

// Background: Parent-child editing requires deterministic full-tree relayout after structure or size changes.
// Responsibility: Define the public domain service entry point for tree relayout.
/// Pure domain service that recalculates parent-child tree positions.
public enum CanvasTreeLayoutService {}
