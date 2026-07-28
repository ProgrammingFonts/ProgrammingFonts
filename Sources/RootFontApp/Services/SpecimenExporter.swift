import AppKit
import Foundation

enum SpecimenExporter: Sendable {
    struct Content {
        let familyName: String
        let displayName: String
        let postScriptName: String
        let previewText: String
        let size: CGFloat
        let font: NSFont
    }

    private static let canvasSize = NSSize(width: 900, height: 420)

    static func pngData(
        familyName: String,
        displayName: String,
        postScriptName: String,
        previewText: String,
        size: CGFloat,
        font: NSFont
    ) -> Data? {
        let image = renderImage(content: Content(
            familyName: familyName,
            displayName: displayName,
            postScriptName: postScriptName,
            previewText: previewText,
            size: size,
            font: font
        ))
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }

    static func pdfData(
        familyName: String,
        displayName: String,
        postScriptName: String,
        previewText: String,
        size: CGFloat,
        font: NSFont
    ) -> Data? {
        let content = Content(
            familyName: familyName,
            displayName: displayName,
            postScriptName: postScriptName,
            previewText: previewText,
            size: size,
            font: font
        )
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: canvasSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: 0, y: canvasSize.height)
        context.scaleBy(x: 1, y: -1)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(content: content, in: NSRect(origin: .zero, size: canvasSize))
        NSGraphicsContext.restoreGraphicsState()

        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private static func renderImage(content: Content) -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(content: content, in: NSRect(origin: .zero, size: canvasSize))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        return image
    }

    private static func draw(content: Content, in rect: NSRect) {
        NSColor.white.setFill()
        rect.fill()

        let titleFont = NSFont.systemFont(ofSize: 28, weight: .bold)
        let subtitleFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        let metaFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black,
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: NSColor.gray,
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: content.font,
            .foregroundColor: NSColor.black,
        ]
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        content.familyName.draw(at: NSPoint(x: 48, y: rect.height - 72), withAttributes: titleAttrs)
        content.displayName.draw(at: NSPoint(x: 48, y: rect.height - 98), withAttributes: subtitleAttrs)
        content.previewText.draw(
            in: NSRect(x: 48, y: 120, width: rect.width - 96, height: 180),
            withAttributes: bodyAttrs
        )
        "\(content.postScriptName) · \(Int(content.size)) pt · rootfont".draw(
            at: NSPoint(x: 48, y: 48),
            withAttributes: metaAttrs
        )
    }
}
