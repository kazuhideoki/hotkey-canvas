// Background: Canvas nodes can include image content rendered above text and inserted from Finder.
// Responsibility: Provide image insertion flow, height measurement, and image-aware node rendering helpers.
import AppKit
import Domain
import SwiftUI
import UniformTypeIdentifiers

extension CanvasView {
    /// Caches decoded images by file path to avoid repeated disk I/O during SwiftUI recomposition.
    static let nodeImageCache = NodeImageCache()

    func insertImageFromFinder() {
        guard let focusedNodeID = viewModel.focusedNodeID else {
            return
        }
        guard let focusedNode = viewModel.nodes.first(where: { $0.id == focusedNodeID }) else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Insert Image"
        panel.prompt = "Insert"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK else {
            return
        }
        guard let selectedURL = panel.url else {
            return
        }
        guard let imageSize = imageSize(atFilePath: selectedURL.path) else {
            return
        }

        let nodeHeight = measuredNodeHeightAfterReplacingImage(
            in: focusedNode,
            imageSize: imageSize
        )
        Task {
            await viewModel.insertNodeImage(
                nodeID: focusedNodeID,
                imagePath: selectedURL.path,
                nodeHeight: nodeHeight
            )
        }
    }

    func imageSize(atFilePath filePath: String) -> CGSize? {
        guard let size = Self.nodeImageCache.image(atFilePath: filePath)?.size else {
            return nil
        }
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            return nil
        }
        return size
    }

    func measuredNodeHeightAfterReplacingImage(in node: CanvasNode, imageSize newImageSize: CGSize) -> Double {
        let hasText = (node.text ?? "").isEmpty == false
        let currentImageHeight: Double =
            if let currentImagePath = primaryImagePath(in: node),
                let currentImageSize = imageSize(atFilePath: currentImagePath)
            {
                measuredImageDisplayHeight(imageSize: currentImageSize, nodeWidth: node.bounds.width)
            } else {
                0
            }
        let currentSpacing = currentImageHeight > 0 && hasText ? Double(nodeTextStyle.imageTextSpacing) : 0
        let textOnlyHeight = Double(
            measuredNodeLayout(
                text: node.text ?? "",
                nodeWidth: node.bounds.width
            ).nodeHeight
        )
        let baseHeight = Self.replacementBaseNodeHeight(
            currentNodeHeight: node.bounds.height,
            currentImageHeight: currentImageHeight,
            currentImageSpacing: currentSpacing,
            textOnlyHeight: textOnlyHeight,
            hadExistingImagePath: primaryImagePath(in: node) != nil
        )

        let insertedImageHeight = measuredImageDisplayHeight(
            imageSize: newImageSize,
            nodeWidth: node.bounds.width
        )
        let insertedSpacing = hasText ? Double(nodeTextStyle.imageTextSpacing) : 0
        return max(baseHeight + insertedImageHeight + insertedSpacing, 1)
    }

    static func replacementBaseNodeHeight(
        currentNodeHeight: Double,
        currentImageHeight: Double,
        currentImageSpacing: Double,
        textOnlyHeight: Double,
        hadExistingImagePath: Bool
    ) -> Double {
        if hadExistingImagePath && currentImageHeight == 0 {
            return max(textOnlyHeight, 1)
        }
        return max(currentNodeHeight - currentImageHeight - currentImageSpacing, 1)
    }

    func measuredImageDisplayHeight(imageSize: CGSize, nodeWidth: Double) -> Double {
        let displayWidth = measuredImageDisplayWidth(imageSize: imageSize, nodeWidth: nodeWidth)
        let scale = displayWidth / imageSize.width
        return max(Double(imageSize.height * scale), 1)
    }

    func measuredImageDisplayWidth(imageSize: CGSize, nodeWidth: Double) -> Double {
        Self.measuredImageDisplayWidth(
            imageSize: imageSize,
            nodeWidth: nodeWidth,
            outerPadding: Double(nodeTextStyle.outerPadding)
        )
    }

    static func measuredImageDisplayWidth(imageSize: CGSize, nodeWidth: Double) -> Double {
        measuredImageDisplayWidth(
            imageSize: imageSize,
            nodeWidth: nodeWidth,
            outerPadding: Double(NodeTextStyle.outerPadding)
        )
    }

    static func measuredImageDisplayWidth(
        imageSize: CGSize,
        nodeWidth: Double,
        outerPadding: Double
    ) -> Double {
        let contentWidth = max(nodeWidth - (outerPadding * 2), 1)
        return min(contentWidth, imageSize.width)
    }

    func measuredNodeHeightForEditing(
        text: String,
        measuredTextHeight: Double,
        node: CanvasNode
    ) -> Double {
        guard primaryImagePath(in: node) != nil else {
            return measuredTextHeight
        }
        let hasText = text.isEmpty == false
        let imageLayout = measuredImageLayoutForNode(node, hasText: hasText)
        return Self.imageAwareEditingNodeHeight(
            measuredTextHeight: measuredTextHeight,
            imageHeight: imageLayout.height,
            imageSpacing: imageLayout.spacing
        )
    }

    func measuredImageLayoutForNode(_ node: CanvasNode, hasText: Bool) -> (height: Double, spacing: Double) {
        guard
            let imagePath = primaryImagePath(in: node),
            let imageSize = imageSize(atFilePath: imagePath)
        else {
            return (height: 0, spacing: 0)
        }
        let height = measuredImageDisplayHeight(imageSize: imageSize, nodeWidth: node.bounds.width)
        let spacing = hasText ? Double(nodeTextStyle.imageTextSpacing) : 0
        return (height: height, spacing: spacing)
    }

    static func imageAwareEditingNodeHeight(
        measuredTextHeight: Double,
        imageHeight: Double,
        imageSpacing: Double
    ) -> Double {
        max(measuredTextHeight + imageHeight + imageSpacing, 1)
    }

    @ViewBuilder
    func nonEditingNodeContent(node: CanvasNode, zoomScale: Double) -> some View {
        let contentAlignment = nodeTextContentAlignment(for: node.id)
        if let imagePath = primaryImagePath(in: node), let image = Self.nodeImageCache.image(atFilePath: imagePath) {
            let scale = CGFloat(zoomScale)
            let scaledPadding = nodeTextStyle.outerPadding * scale
            let contentWidth = max((CGFloat(node.bounds.width) * scale) - (scaledPadding * 2), 1)
            let hasText = (node.text ?? "").isEmpty == false
            let unscaledImageDisplayWidth = measuredImageDisplayWidth(
                imageSize: image.size,
                nodeWidth: node.bounds.width
            )
            let imageDisplayWidth = max(CGFloat(unscaledImageDisplayWidth) * scale, 1)
            VStack(
                alignment: contentAlignment.horizontalAlignment,
                spacing: hasText ? nodeTextStyle.imageTextSpacing * scale : 0
            ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: min(imageDisplayWidth, contentWidth),
                        alignment: contentAlignment.frameAlignment
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: nodeTextStyle.imageCornerRadius * scale)
                    )
                if hasText {
                    nonEditingNodeTextBody(
                        node: node,
                        zoomScale: zoomScale,
                        contentAlignment: contentAlignment
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment.frameAlignment)
            .padding(scaledPadding)
        } else {
            nonEditingNodeText(node: node, zoomScale: zoomScale)
        }
    }

    @ViewBuilder
    func nonEditingNodeTextBody(
        node: CanvasNode,
        zoomScale: Double,
        contentAlignment: NodeTextContentAlignment
    ) -> some View {
        let shouldRenderSearchHighlight = hasSearchMatches(in: node)
        if Self.shouldRenderMarkdownText(
            markdownStyleEnabled: node.markdownStyleEnabled,
            hasSearchMatches: shouldRenderSearchHighlight
        ) {
            let text = node.text ?? ""
            NodeMarkdownDisplay(
                text: text,
                nodeWidth: node.bounds.width,
                zoomScale: zoomScale,
                appliesOuterPadding: false,
                style: nodeTextStyle,
                contentAlignment: contentAlignment
            )
        } else {
            nonEditingPlainNodeTextBody(
                attributedText: highlightedNodeText(for: node),
                nodeWidth: node.bounds.width,
                zoomScale: zoomScale,
                contentAlignment: contentAlignment
            )
        }
    }

    @ViewBuilder
    private func nonEditingPlainNodeTextBody(
        attributedText: AttributedString,
        nodeWidth: Double,
        zoomScale: Double,
        contentAlignment: NodeTextContentAlignment
    ) -> some View {
        let scale = CGFloat(zoomScale)
        let contentWidth = max(
            (CGFloat(nodeWidth) * scale) - (nodeTextStyle.outerPadding * scale * 2),
            1
        )
        Text(attributedText)
            .font(.system(size: nodeTextStyle.fontSize * scale, weight: nodeTextStyle.displayFontWeight))
            .lineLimit(nil)
            .multilineTextAlignment(contentAlignment.textAlignment)
            .frame(width: contentWidth, alignment: contentAlignment.frameAlignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func shouldRenderMarkdownText(markdownStyleEnabled: Bool, hasSearchMatches: Bool) -> Bool {
        markdownStyleEnabled && !hasSearchMatches
    }
}

/// In-memory cache for decoded node images keyed by absolute file path.
final class NodeImageCache {
    private let storage = NSCache<NSString, NodeImageCacheEntry>()

    func image(atFilePath filePath: String) -> NSImage? {
        let cacheKey = filePath as NSString
        guard let fileSignature = Self.signature(atFilePath: filePath) else {
            storage.removeObject(forKey: cacheKey)
            return nil
        }
        if let cachedEntry = storage.object(forKey: cacheKey),
            cachedEntry.fileSignature == fileSignature
        {
            return cachedEntry.image
        }
        guard let image = NSImage(contentsOfFile: filePath) else {
            storage.removeObject(forKey: cacheKey)
            return nil
        }
        storage.setObject(
            NodeImageCacheEntry(
                image: image,
                fileSignature: fileSignature
            ),
            forKey: cacheKey
        )
        return image
    }

    private static func signature(atFilePath filePath: String) -> NodeImageFileSignature? {
        let fileURL = URL(fileURLWithPath: filePath)
        guard
            let resourceValues = try? fileURL.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
            ]),
            let modifiedAt = resourceValues.contentModificationDate,
            let fileSize = resourceValues.fileSize
        else {
            return nil
        }
        return NodeImageFileSignature(
            modifiedAt: modifiedAt,
            fileSize: fileSize
        )
    }
}

private struct NodeImageFileSignature: Equatable {
    let modifiedAt: Date
    let fileSize: Int
}

private final class NodeImageCacheEntry {
    let image: NSImage
    let fileSignature: NodeImageFileSignature

    init(image: NSImage, fileSignature: NodeImageFileSignature) {
        self.image = image
        self.fileSignature = fileSignature
    }
}
func primaryImagePath(in node: CanvasNode) -> String? {
    node.primaryImageAttachmentFilePath
}
