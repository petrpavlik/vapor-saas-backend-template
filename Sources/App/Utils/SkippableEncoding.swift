//
//  File.swift
//  
//
//  Created by Petr Pavlik on 11.03.2024.
//

import Foundation

extension SkippableEncoding : Sendable  where Wrapped : Sendable  {}
extension SkippableEncoding : Hashable  where Wrapped : Hashable  {}
extension SkippableEncoding : Equatable where Wrapped : Equatable {}

@propertyWrapper
public enum SkippableEncoding<Wrapped : Codable> : Codable {
    
    case skipped
    case encoded(Wrapped?)
    
    public init() {
        self = .skipped
    }
    
    public var wrappedValue: Wrapped? {
        get {
            switch self {
                case .skipped:        return nil
                case .encoded(let v): return v
            }
        }
        set {
            self = .encoded(newValue)
        }
    }
    
    public var projectedValue: Self {
        get {self}
        set {self = newValue}
    }
    
    /** Returns `.none` if the value is skipped, `.some(wrappedValue)` if it is not. */
    public var value: Wrapped?? {
        switch self {
            case .skipped:        return nil
            case .encoded(let v): return .some(v)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try .encoded(container.decode(Wrapped?.self))
    }
    
    public func encode(to encoder: Encoder) throws {
        /* The encoding is taken care of in KeyedEncodingContainer. */
        assertionFailure()
        
        switch self {
            case .skipped:
                (/*nop*/)
                
            case .encoded(let v):
                var container = encoder.singleValueContainer()
                try container.encode(v)
        }
    }
    
}

extension KeyedEncodingContainer {
    
    public mutating func encode<Wrapped>(_ value: SkippableEncoding<Wrapped>, forKey key: KeyedEncodingContainer<K>.Key) throws {
        switch value {
            case .skipped: (/*nop*/)
            case .encoded(let v): try encode(v, forKey: key)
        }
    }
    
}

extension UnkeyedEncodingContainer {
    
    mutating func encode<Wrapped>(_ value: SkippableEncoding<Wrapped>) throws {
        switch value {
            case .skipped: (/*nop*/)
            case .encoded(let v): try encode(v)
        }
    }
    
}

extension SingleValueEncodingContainer {
    
    mutating func encode<Wrapped>(_ value: SkippableEncoding<Wrapped>) throws {
        switch value {
            case .skipped: (/*nop*/)
            case .encoded(let v): try encode(v)
        }
    }
    
}

extension KeyedDecodingContainer {
    
    public func decode<Wrapped>(_ type: SkippableEncoding<Wrapped>.Type, forKey key: Key) throws -> SkippableEncoding<Wrapped> {
        /* So IMHO:
         *     if let decoded = try decodeIfPresent(SkippableEncoding<Wrapped>?.self, forKey: key) {
         *        return decoded ?? SkippableEncoding.encoded(nil)
         *     }
         * should definitely work, but it does not (when the key is present but the value nil, we do not get in the if.
         * So instead we try and decode nil directly.
         * If that fails (missing key), we fallback to decoding the SkippableEncoding directly if the key is present. */
        if (try? decodeNil(forKey: key)) == true {
            return SkippableEncoding.encoded(nil)
        }
        return try decodeIfPresent(SkippableEncoding<Wrapped>.self, forKey: key) ?? SkippableEncoding()
    }
    
}
