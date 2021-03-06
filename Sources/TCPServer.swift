//
//  TCPServer.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 4/30/16.
//
//

import Dispatch

public final class TCPServer {
    
    public let loop: RunLoop
    private let fd: SocketFileDescriptor
    private let listeningSource: dispatch_source_t
    
    public convenience init(loop: RunLoop) {
        self.init(loop: loop, fd: SocketFileDescriptor(socketType: SocketType.stream, addressFamily: AddressFamily.inet))
    }
    
    public init(loop: RunLoop, fd: SocketFileDescriptor) {
        self.loop = loop
        self.fd = fd
        self.listeningSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(fd.rawValue), 0, dispatch_get_main_queue())
        
        // Close the socket when the source is canceled.
        dispatch_source_set_cancel_handler(listeningSource) {
            // Close the socket
            self.fd.close()
        }
        
        // Set SO_REUSEADDR
        var reuseAddr = 1
        let error = setsockopt(self.fd.rawValue, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(strideof(Int)))
        if error != 0 {
            try! { throw Error(rawValue: error) }()
        }
    }
    
    public func bind(host: String, port: Port) throws {
        var addrInfoPointer = UnsafeMutablePointer<addrinfo>(nil)
        
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: fd.addressFamily.rawValue,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        let ret = getaddrinfo(host, String(port), &hints, &addrInfoPointer)
        if ret != 0 {
            throw AddressFamilyError(rawValue: ret)
        }
        
        let addressInfo = addrInfoPointer!.pointee
        
        let bindRet = system_bind(fd.rawValue, addressInfo.ai_addr, socklen_t(sizeof(sockaddr)))
        freeaddrinfo(addrInfoPointer)
        
        if bindRet != 0 {
            throw Error(rawValue: errno)
        }
    }
    
    public func listen(backlog: Int = 32) -> ColdSignal<TCPSocket, Error> {
        return ColdSignal { observer in
            let ret = system_listen(self.fd.rawValue, Int32(backlog))
            if ret != 0 {
                observer.sendFailed(Error(rawValue: errno))
            }
            log.debug("Listening on \(self.fd)...")
            dispatch_source_set_event_handler(self.listeningSource) {
                
                log.debug("Connecting...")
                
                var socketAddress = sockaddr()
                var sockLen = socklen_t(SOCK_MAXADDRLEN)
                
                // Accept connections
                let numPendingConnections = dispatch_source_get_data(self.listeningSource)
                for _ in 0..<numPendingConnections {
                    let ret = system_accept(self.fd.rawValue, &socketAddress, &sockLen)
                    if ret == StandardFileDescriptor.invalid.rawValue {
                        observer.sendFailed(Error(rawValue: ret))
                    }
                    let clientFileDescriptor = SocketFileDescriptor(
                        rawValue: ret,
                        socketType: SocketType.stream,
                        addressFamily: self.fd.addressFamily,
                        blocking: false
                    )
                    
                    // Create the client connection socket and start reading
                    let clientConnection = TCPSocket(loop: self.loop, fd: clientFileDescriptor)
                    observer.sendNext(clientConnection)
                }
            }
            dispatch_resume(self.listeningSource)
            return ActionDisposable {
                dispatch_source_cancel(self.listeningSource)
            }
        }
    }
}
