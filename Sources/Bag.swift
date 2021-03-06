//
//  Bag.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/29/16.
//
//

public final class RemovalToken {
    private var identifier: UInt?
    
    private init(identifier: UInt) {
        self.identifier = identifier
    }
}

/// An unordered, non-unique collection of values of type `Element`.
public struct Bag<Element> {
    private var elements: [BagElement<Element>] = []
    private var currentIdentifier: UInt = 0
    
    public init() {
        
    }
    
    /// Inserts the given value in the collection, and returns a token that can
    /// later be passed to removeValueForToken().
    public mutating func insert(value: Element) -> RemovalToken {
        let (nextIdentifier, overflow) = UInt.addWithOverflow(currentIdentifier, 1)
        if overflow {
            reindex()
        }
        
        let token = RemovalToken(identifier: currentIdentifier)
        let element = BagElement(value: value, identifier: currentIdentifier, token: token)
        
        elements.append(element)
        currentIdentifier = nextIdentifier
        
        return token
    }
    
    /// Removes a value, given the token returned from insert().
    ///
    /// If the value has already been removed, nothing happens.
    public mutating func removeValueForToken(token: RemovalToken) {
        if let identifier = token.identifier {
            // Removal is more likely for recent objects than old ones.
            for i in elements.indices.reversed() {
                if elements[i].identifier == identifier {
                    elements.remove(at: i)
                    token.identifier = nil
                    break
                }
            }
        }
    }
    
    /// In the event of an identifier overflow (highly, highly unlikely), this
    /// will reset all current identifiers to reclaim a contiguous set of
    /// available identifiers for the future.
    private mutating func reindex() {
        for i in elements.indices {
            currentIdentifier = UInt(i)
            
            elements[i].identifier = currentIdentifier
            elements[i].token.identifier = currentIdentifier
        }
    }
}

extension Bag: Collection {
    public typealias Index = Array<Element>.Index
    public typealias SubSequence = Array<Element>.SubSequence
    
    public var startIndex: Index {
        return elements.startIndex
    }
    
    public var endIndex: Index {
        return elements.endIndex
    }
    
    public subscript(position: Index) -> Element {
        return elements[position].value
    }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        return elements[bounds].map{ $0.value }[0..<elements.count]
    }

    public func index(after i: Index) -> Index {
        return i + 1
    }
}

private struct BagElement<Value> {
    let value: Value
    var identifier: UInt
    let token: RemovalToken
}

extension BagElement: CustomStringConvertible {
    var description: String {
        return "BagElement(\(value))"
    }
}