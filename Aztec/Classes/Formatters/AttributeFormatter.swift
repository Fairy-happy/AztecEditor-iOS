import UIKit

/// A type that provides support for toggling compound attributes in an
/// attributed string.
///
/// When you want to represent an attribute that does not have a 1-1
/// correspondence with a standard attribute, it is useful to have a virtual
/// attribute. Toggling this attribute would also toggle the attributes for its
/// defined style.
///
protocol AttributeFormatter {
    /// Checks if the attribute is present in a dictionary of attributes.
    ///
    func present(inAttributes attributes: [String: AnyObject]) -> Bool

    /// Apply the compound attributes to the provided attributes dictionary
    ///
    /// - Parameter attributes: the original attributes to apply to
    /// - Returns: the resulting attributes dictionary
    ///
    func apply(toAttributes attributes: [String: Any]) -> [String: Any]

    /// Remove the compound attributes from the provided list.
    ///
    /// - Parameter attributes: the original attributes to remove from
    /// - Returns: the resulting attributes dictionary
    ///
    func remove(fromAttributes attributes: [String: Any]) -> [String: Any]

    /// The range to apply the attributes to.
    ///
    /// By default, this returns the passed `range`, but implementations of this
    /// protocol might want to extend the range to apply the attribute to a
    /// different range (e.g. a paragraph)
    ///
    func applicationRange(forRange range: NSRange, inString string: NSAttributedString) -> NSRange

    /// Toggles an attribute in the specified range of a text storage.
    ///
    /// The application range might be different than the passed range, as
    /// explained in `applicationRange(for:in:)`
    ///
    func toggleAttribute(in text: NSMutableAttributedString, at range: NSRange)
}

extension AttributeFormatter {
    /// Checks if the attribute is present in a text view at the specified index.
    ///
    func present(in storage: NSTextStorage, at index: Int) -> Bool {
        let safeIndex = max(min(index, storage.length - 1), 0)
        let attributes = storage.attributes(at: safeIndex, effectiveRange: nil) as [String : AnyObject]
        return present(inAttributes: attributes)
    }
}

// MARK: - Default implementations

extension AttributeFormatter {
    func applicationRange(forRange range: NSRange, inString string: NSAttributedString) -> NSRange {
        return range
    }

    /// The string to be used when adding attributes to an empty line.
    ///
    var placeholderForAttributedEmptyLine: String {
        return "\u{200B}"
    }
}

// MARK: - Private methods

private extension AttributeFormatter {

    func toggleAttribute(in string: NSMutableAttributedString, at range: NSRange) {
        if attribute(inString: string, at: range.location) {
            removeAttributes(fromString: string, at: range)
        } else {
            applyAttributes(toString: string, at: range)
        }
    }

    func applyAttributes(toString string: NSMutableAttributedString, atRange range: NSRange) {
        let currentAttributes = string.attributes(at: range.location, effectiveRange: nil)
        let attributes = apply(toAttributes: currentAttributes)
        string.addAttributes(attributes, range: range)
    }

    func removeAttributes(fromString string: NSMutableAttributedString, atRange range: NSRange) {
        let currentAttributes = string.attributes(at: range.location, effectiveRange: nil)
        let attributes = remove(fromAttributes: currentAttributes)
        string.addAttributes(attributes, range: range)
    }

    func attribute(inString string: NSAttributedString, at index: Int) -> Bool {
        let attributes = string.attributes(at: index, effectiveRange: nil)
        return present(inAttributes: attributes as [String : AnyObject])
    }

    func insertEmptyAttribute(inString string: NSMutableAttributedString, at index: Int) {
        let attributes = apply(toAttributes: [:])
        let attributedSpace = NSAttributedString(string: placeholderForAttributedEmptyLine, attributes: attributes)
        string.insert(attributedSpace, at: index)
    }
}

// MARK: - Attribute Formater types

protocol CharacterAttributeFormatter: AttributeFormatter {
}

protocol ParagraphAttributeFormatter: AttributeFormatter {
}

extension ParagraphAttributeFormatter {
    func applicationRange(forRange range: NSRange, inString string: NSAttributedString) -> NSRange {
        return string.paragraphRange(for: range)
    }

    func toggleAttribute(in text: NSMutableAttributedString, at range: NSRange) {
        let applicationRange = self.applicationRange(for: range, in: text)

        if applicationRange.length == 0 || text.length == 0 {
            insertEmptyAttribute(inString: text, at: applicationRange.location)
        }

        if attribute(inString: text, at: range.location) {
            removeAttributes(fromString: text, at: applicationRange)
        } else {
            applyAttributes(toString: text, at: applicationRange)
        }
    }
}
