//
//  IOStream.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/1/16.
//
//

import Foundation
import Result

public protocol IOStream {
    
    var fd: FileDescriptor {
        get
    }
    
    var loop: RunLoop {
        get
    }
    
    var channel: dispatch_io_t { get }
    
    func read(minBytes: Int, onRead: (result: Result<UnsafeBufferPointer<Int8>, Error>) -> ())
    
    func write(buffer: UnsafeBufferPointer<Int8>, onWrite: ((result: Result<Void, Error>) -> ())?)
    
}

public extension IOStream {
    
    public func read(minBytes: Int = 1, onRead: (result: Result<UnsafeBufferPointer<Int8>, Error>) -> ()) {
        dispatch_io_set_low_water(channel, minBytes);
        dispatch_io_read(channel, off_t(), size_t(INT_MAX), dispatch_get_main_queue()) { done, data, error in
            if error != 0 {
                onRead(result: Result(error: Error(rawValue: error)))
                return
            }
            var p = UnsafePointer<Void>(nil)
            var size: size_t = 0
            _ = dispatch_data_create_map(data, &p, &size)
            let buffer = UnsafeBufferPointer<Int8>(start: UnsafePointer<Int8>(p), count: size)
            onRead(result: Result(value: buffer))
        }
    }
    
    public func write(buffer: UnsafeBufferPointer<Int8>, onWrite: ((result: Result<Void, Error>) -> ())? = nil) {
        let dispatchData = dispatch_data_create(buffer.baseAddress, buffer.count, dispatch_get_main_queue(), nil)
        dispatch_io_write(channel, off_t(), dispatchData, dispatch_get_main_queue()) { done, data, error in
            if error != 0 {
                onWrite?(result: Result(error: Error(rawValue: error)))
            } else {
                onWrite?(result: Result(value: ()))
            }
        }
    }
}
