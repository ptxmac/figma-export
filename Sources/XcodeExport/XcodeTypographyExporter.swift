import Foundation
import FigmaExportCore
import Stencil

final public class XcodeTypographyExporter {
    private let output: XcodeTypographyOutput

    public init(output: XcodeTypographyOutput) {
        self.output = output
    }

    public func export(textStyles: [TextStyle]) throws -> [FileContents] {
        var files: [FileContents] = []

        // UIKit UIFont extension
        if let fontExtensionURL = output.urls.fonts.fontExtensionURL {
            files.append(contentsOf: try exportFonts(
                textStyles: textStyles,
                fontExtensionURL: fontExtensionURL,
                addObjcAttribute: output.addObjcAttribute
            ))
        }

        // SwiftUI Font extension
        if let swiftUIFontExtensionURL = output.urls.fonts.swiftUIFontExtensionURL {
            files.append(contentsOf: try exportFonts(
                textStyles: textStyles,
                swiftUIFontExtensionURL: swiftUIFontExtensionURL
            ))
        }

        // UIKit Labels
        if output.generateLabels, let labelsDirectory = output.urls.labels.labelsDirectory  {
            // Label.swift
            // LabelStyle.swift
            files.append(contentsOf: try exportLabels(
                textStyles: textStyles,
                labelsDirectory: labelsDirectory,
                separateStyles: output.urls.labels.labelStyleExtensionsURL != nil
            ))
            
            // LabelStyle extensions
            if let labelStyleExtensionsURL = output.urls.labels.labelStyleExtensionsURL {
                files.append(contentsOf: try exportLabelStylesExtensions(
                    textStyles: textStyles,
                    labelStyleExtensionURL: labelStyleExtensionsURL
                ))
            }
        }

        return files
    }
    
    private func exportFonts(textStyles: [TextStyle], fontExtensionURL: URL, addObjcAttribute: Bool) throws -> [FileContents] {
        let strings: [String] = textStyles.map {
            let dynamicType: String = $0.fontStyle != nil ? ", textStyle: .\($0.fontStyle!.textStyleName), scaled: true" : ""
            return """
                \(addObjcAttribute ? "@objc ": "")static func \($0.name)() -> UIFont {
                    customFont("\($0.fontName)", size: \($0.fontSize)\(dynamicType))
                }
            """
        }
        let contents = """
        \(header)
        
        import UIKit

        public extension UIFont {
        
        \(strings.joined(separator: "\n\n"))
        
            private static func customFont(
                _ name: String,
                size: CGFloat,
                textStyle: UIFont.TextStyle? = nil,
                scaled: Bool = false) -> UIFont {

                guard let font = UIFont(name: name, size: size) else {
                    print("Warning: Font \\(name) not found.")
                    return UIFont.systemFont(ofSize: size, weight: .regular)
                }
                
                if scaled, let textStyle = textStyle {
                    let metrics = UIFontMetrics(forTextStyle: textStyle)
                    return metrics.scaledFont(for: font)
                } else {
                    return font
                }
            }
        }
        
        """
        
        let data = contents.data(using: .utf8)!
        
        let fileURL = URL(string: fontExtensionURL.lastPathComponent)!
        let directoryURL = fontExtensionURL.deletingLastPathComponent()
        
        let destination = Destination(directory: directoryURL, file: fileURL)
        return [FileContents(destination: destination, data: data)]
    }
    
    private func exportFonts(textStyles: [TextStyle], swiftUIFontExtensionURL: URL) throws -> [FileContents] {
        let strings: [String] = textStyles.map {
            
            var dynamicType: String?
            if $0.fontStyle != nil {
                dynamicType = ", relativeTo: .\($0.fontStyle!.textStyleName)"
            }
            
            if let dynamicType = dynamicType {
                return """
                    static func \($0.name)() -> Font {
                        if #available(iOS 14.0, *) {
                            return Font.custom("\($0.fontName)", size: \($0.fontSize)\(dynamicType))
                        } else {
                            return Font.custom("\($0.fontName)", size: \($0.fontSize))
                        }
                    }
                """
            } else {
                return """
                    static func \($0.name)() -> Font {
                        Font.custom("\($0.fontName)", size: \($0.fontSize))
                    }
                """
            }
        }
        
        let contents = """
        \(header)
        
        import SwiftUI

        public extension Font {
            
        \(strings.joined(separator: "\n"))
        }
        
        """

        let data = contents.data(using: .utf8)!
        
        let fileURL = URL(string: swiftUIFontExtensionURL.lastPathComponent)!
        let directoryURL = swiftUIFontExtensionURL.deletingLastPathComponent()
        
        let destination = Destination(directory: directoryURL, file: fileURL)
        return [FileContents(destination: destination, data: data)]
    }
    
    private func exportLabelStylesExtensions(textStyles: [TextStyle], labelStyleExtensionURL: URL) throws -> [FileContents] {
        let dict = textStyles.map { style -> [String: Any] in
            let type: String = style.fontStyle?.textStyleName ?? ""
            return [
                "className": style.name.first!.uppercased() + style.name.dropFirst(),
                "varName": style.name,
                "size": style.fontSize,
                "supportsDynamicType": style.fontStyle != nil,
                "type": type,
                "tracking": style.letterSpacing.floatingPointFixed,
                "lineHeight": style.lineHeight ?? 0,
                "textCase": style.textCase.rawValue
            ]}
        let contents = try labelStyleExtensionSwiftContents.render(["styles": dict])
        
        let fileName = labelStyleExtensionURL.lastPathComponent
        let directoryURL = labelStyleExtensionURL.deletingLastPathComponent()
        let labelStylesSwiftExtension = try makeFileContents(data: contents, directoryURL: directoryURL, fileName: fileName)
        
        return [labelStylesSwiftExtension]
    }
    
    private func exportLabels(textStyles: [TextStyle], labelsDirectory: URL, separateStyles: Bool) throws -> [FileContents] {
        let dict = textStyles.map { style -> [String: Any] in
            let type: String = style.fontStyle?.textStyleName ?? ""
            return [
                "className": style.name.first!.uppercased() + style.name.dropFirst(),
                "varName": style.name,
                "size": style.fontSize,
                "supportsDynamicType": style.fontStyle != nil,
                "type": type,
                "tracking": style.letterSpacing.floatingPointFixed,
                "lineHeight": style.lineHeight ?? 0,
                "textCase": style.textCase.rawValue
            ]}
        let contents = try TEMPLATE_Label_swift.render([
            "styles": dict,
            "separateStyles": separateStyles
        ])
        
        let labelSwift = try makeFileContents(data: contents, directoryURL: labelsDirectory, fileName: "Label.swift")
        let labelStyleSwift = try makeFileContents(data: labelStyleSwiftContents, directoryURL: labelsDirectory, fileName: "LabelStyle.swift")
        
        return [labelSwift, labelStyleSwift]
    }
    
    private func makeFileContents(data: String, directoryURL: URL, fileName: String) throws -> FileContents {
        let data = data.data(using: .utf8)!
        let fileURL = URL(string: fileName)!
        let destination = Destination(directory: directoryURL, file: fileURL)
        return FileContents(destination: destination, data: data)
    }
}

private let TEMPLATE_Label_swift = Template(templateString: """
\(header)

import UIKit

public class Label: UILabel {

    var style: LabelStyle? { nil }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateText()
        }
    }

    public convenience init(text: String?, textColor: UIColor) {
        self.init()
        self.text = text
        self.textColor = textColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
        updateText()
    }

    private func commonInit() {
        font = style?.font
        adjustsFontForContentSizeCategory = true
    }

    private func updateText() {
        text = super.text
    }

    public override var text: String? {
        get {
            guard style?.attributes != nil else {
                return super.text
            }

            return attributedText?.string
        }
        set {
            guard let style = style else {
                super.text = newValue
                return
            }

            guard let newText = newValue else {
                attributedText = nil
                super.text = nil
                return
            }

            attributedText = style.attributedString(from: newText, alignment: textAlignment, lineBreakMode: lineBreakMode)
        }
    }
}
{% for style in styles %}
public final class {{ style.className }}Label: Label {

    override var style: LabelStyle? {
        {% if separateStyles %}.{{ style.varName }}(){% else %}LabelStyle(
            font: UIFont.{{ style.varName }}(){% if style.supportsDynamicType %},
            fontMetrics: UIFontMetrics(forTextStyle: .{{ style.type }}){% endif %}{% if style.lineHeight != 0 %},
            lineHeight: {{ style.lineHeight }}{% endif %}{% if style.tracking != 0 %},
            tracking: {{ style.tracking }}{% endif %}{% if style.textCase != \"original\" %},
            textCase: .{{ style.textCase }}{% endif %}
        ){% endif %}
    }
}
{% endfor %}
""")

private let labelStyleExtensionSwiftContents = Template(templateString: """
\(header)

import UIKit

public extension LabelStyle {
    {% for style in styles %}
    static func {{ style.varName }}() -> LabelStyle {
        LabelStyle(
            font: UIFont.{{ style.varName }}(){% if style.supportsDynamicType %},
            fontMetrics: UIFontMetrics(forTextStyle: .{{ style.type }}){% endif %}{% if style.lineHeight != 0 %},
            lineHeight: {{ style.lineHeight }}{% endif %}{% if style.tracking != 0 %},
            tracking: {{ style.tracking }}{% endif %}{% if style.textCase != \"original\" %},
            textCase: .{{ style.textCase }}{% endif %}
        )
    }
    {% endfor %}
}
""")

private let labelStyleSwiftContents = """
\(header)

import UIKit

public struct LabelStyle {

    enum TextCase {
        case uppercased
        case lowercased
        case original
    }

    let font: UIFont
    let fontMetrics: UIFontMetrics?
    let lineHeight: CGFloat?
    let tracking: CGFloat
    let textCase: TextCase
    
    init(font: UIFont, fontMetrics: UIFontMetrics? = nil, lineHeight: CGFloat? = nil, tracking: CGFloat = 0, textCase: TextCase = .original) {
        self.font = font
        self.fontMetrics = fontMetrics
        self.lineHeight = lineHeight
        self.tracking = tracking
        self.textCase = textCase
    }
    
    public func attributes(
        for alignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) -> [NSAttributedString.Key: Any] {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = lineBreakMode
        
        var baselineOffset: CGFloat = .zero
        
        if let lineHeight = lineHeight {
            let scaledLineHeight: CGFloat = fontMetrics?.scaledValue(for: lineHeight) ?? lineHeight
            paragraphStyle.minimumLineHeight = scaledLineHeight
            paragraphStyle.maximumLineHeight = scaledLineHeight
            
            baselineOffset = (scaledLineHeight - font.lineHeight) / 4.0
        }
        
        return [
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.kern: tracking,
            NSAttributedString.Key.baselineOffset: baselineOffset,
            NSAttributedString.Key.font: font
        ]
    }

    public func attributedString(
        from string: String,
        alignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) -> NSAttributedString {
        let attributes = attributes(for: alignment, lineBreakMode: lineBreakMode)
        return NSAttributedString(string: convertText(string), attributes: attributes)
    }

    private func convertText(_ text: String) -> String {
        switch textCase {
        case .uppercased:
            return text.uppercased()
        case .lowercased:
            return text.lowercased()
        default:
            return text
        }
    }
}

"""
