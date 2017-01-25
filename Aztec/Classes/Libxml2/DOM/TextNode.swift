import Foundation

extension Libxml2 {
    /// Text nodes.  Cannot have child nodes (for now, not sure if we will need them).
    ///
    class TextNode: Node, EditableNode, LeafNode {

        fileprivate var contents: String

        // MARK: - CustomReflectable
        
        override public var customMirror: Mirror {
            get {
                return Mirror(self, children: ["type": "text", "name": name, "text": contents, "parent": parent.debugDescription], ancestorRepresentation: .suppressed)
            }
        }
        
        // MARK: - Initializers
        
        init(text: String, editContext: EditContext? = nil) {
            contents = text

            super.init(name: "text", editContext: editContext)
        }

        /// Node length.
        ///
        override func length() -> Int {
            return contents.characters.count
        }
        
        // MARK: - Editing: Atomic Operations
        
        /// Appends the specified string.  The input data is assumed to be sanitized, which means
        /// this method does not perform verifications or cleanups on it.
        ///
        /// - Parameters:
        ///     - string: the string to append to the node.
        ///
        private func append(sanitizedString string: String) {
            registerUndoForAppend(appendedLength: string.characters.count)
            contents.append(string)
        }
        
        /// Prepends the specified string.  The input data is assumed to be sanitized, which means
        /// this method does not perform verifications or cleanups on it.
        ///
        /// - Parameters:
        ///     - string: the string to prepend to the node.
        ///
        private func prepend(sanitizedString string: String) {
            registerUndoForPrepend(prependedLength: string.characters.count)
            contents = "\(string)\(contents)"
        }

        // MARK: - EditableNode

        func append(_ string: String) {
            
            let components = string.components(separatedBy: String(.newline))
            
            if components.count == 1 {
                append(sanitizedString: string)
            } else {
                
                guard let parent = parent else {
                    assertionFailure("This method cannot process newlines if the node's parent isn't set.")
                    return
                }

                var insertionIndex = parent.indexOf(childNode: self)

                for (componentIndex, component) in components.enumerated() {
                    if componentIndex == 0 {
                        append(sanitizedString: component)
                        
                        insertionIndex = insertionIndex + 1
                    } else {
                        let breakNode = ElementNode.break()
                        let textNode = TextNode(text: component, editContext: editContext)
                        
                        parent.insert(breakNode, at: insertionIndex)
                        parent.insert(textNode, at: insertionIndex + 1)
                        
                        insertionIndex = insertionIndex + 2
                    }
                }
            }
        }

        func deleteCharacters(inRange range: NSRange) {

            guard let range = contents.rangeFromNSRange(range) else {
                fatalError("The specified range is out of bounds.")
            }
            
            deleteCharacters(inRange: range)
        }
        
        func deleteCharacters(inRange range: Range<String.Index>) {
            
            registerUndoForDeleteCharacters(inRange: range)
            contents.removeSubrange(range)
        }
        
        func prepend(_ string: String) {
            registerUndoForPrepend(prependedLength: string.characters.count)
            contents = "\(string)\(contents)"
        }

        func replaceCharacters(inRange range: NSRange, withString string: String, inheritStyle: Bool) {

            guard let range = contents.rangeFromNSRange(range) else {
                fatalError("The specified range is out of bounds.")
            }

            registerUndoForReplaceCharacters(in: range, withString: string)
            contents.replaceSubrange(range, with: string)
        }

        func split(atLocation location: Int) {
            
            guard location != 0 && location != length() else {
                // Nothing to split, move along...
                
                return
            }
            
            guard location > 0 && location < length() else {
                fatalError("Out of bounds!")
            }
            
            let index = text().characters.index(text().startIndex, offsetBy: location)
            
            guard let parent = parent,
                let nodeIndex = parent.children.index(of: self) else {
                    
                    fatalError("This scenario should not be possible. Review the logic.")
            }
            
            let postRange = index ..< text().endIndex
            
            if postRange.lowerBound != postRange.upperBound {
                let newNode = TextNode(text: text().substring(with: postRange), editContext: editContext)
                
                deleteCharacters(inRange: postRange)
                parent.insert(newNode, at: nodeIndex + 1)
            }
        }
        
        func split(forRange range: NSRange) {

            guard let swiftRange = contents.rangeFromNSRange(range) else {
                fatalError("This scenario should not be possible. Review the logic.")
            }

            guard let parent = parent,
                let nodeIndex = parent.children.index(of: self) else {

                fatalError("This scenario should not be possible. Review the logic.")
            }

            let preRange = contents.startIndex ..< swiftRange.lowerBound
            let postRange = swiftRange.upperBound ..< contents.endIndex

            if !postRange.isEmpty {
                let newNode = TextNode(text: contents.substring(with: postRange), editContext: editContext)

                deleteCharacters(inRange: postRange)
                parent.insert(newNode, at: nodeIndex + 1)
            }
            
            if !preRange.isEmpty {
                let newNode = TextNode(text: contents.substring(with: preRange), editContext: editContext)

                deleteCharacters(inRange: preRange)
                parent.insert(newNode, at: nodeIndex)
            }
        }


        /// Wraps the specified range inside a node with the specified name.
        ///
        /// - Parameters:
        ///     - targetRange: the range that must be wrapped.
        ///     - elementDescriptor: the descriptor for the element to wrap the range in.
        ///
        func wrap(range targetRange: NSRange, inElement elementDescriptor: ElementNodeDescriptor) {

            guard !NSEqualRanges(targetRange, NSRange(location: 0, length: length())) else {
                wrap(inElement: elementDescriptor)
                return
            }

            split(forRange: targetRange)
            wrap(inElement: elementDescriptor)
        }
        
        // MARK: - LeadNode
        
        override func text() -> String {
            return contents
        }
        
        // MARK: - Undo support
        
        private func registerUndoForAppend(appendedLength: Int) {
            
            guard let editContext = editContext else {
                return
            }
            
            editContext.undoManager.registerUndo(withTarget: self) { target in
                let endIndex = target.contents.endIndex
                let range = target.contents.index(endIndex, offsetBy: -appendedLength)..<endIndex
                
                target.contents.removeSubrange(range)
            }
        }
        
        private func registerUndoForDeleteCharacters(inRange subrange: Range<String.Index>) {
            
            guard let editContext = editContext else {
                return
            }
            
            let index = subrange.lowerBound
            let removedContent = contents.substring(with: subrange).characters
            
            editContext.undoManager.registerUndo(withTarget: self) { target in
                target.contents.insert(contentsOf: removedContent, at: index)
            }
        }
        
        private func registerUndoForPrepend(prependedLength: Int) {
            
            guard let editContext = editContext else {
                return
            }
            
            editContext.undoManager.registerUndo(withTarget: self) { target in
                let startIndex = target.contents.startIndex
                let range = startIndex ..< target.contents.index(startIndex, offsetBy: prependedLength)
                
                target.contents.removeSubrange(range)
            }
        }
        
        private func registerUndoForReplaceCharacters(in range: Range<String.Index>, withString string: String) {
            
            guard let editContext = editContext else {
                return
            }
            
            let index = range.lowerBound
            let originalString = contents.substring(with: range)
            
            editContext.undoManager.registerUndo(withTarget: self) { target in
                let newStringRange = index ..< target.contents.index(index, offsetBy: string.characters.count)
                
                target.contents.replaceSubrange(newStringRange, with: originalString)
            }
        }
    }
}
