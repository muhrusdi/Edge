//
//  RunLoop.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/2/16.
//
//

import Dispatch

public struct RunLoop {
    
    let dispatchGroup = dispatch_group_create()
    
    public init() {
        
    }
    
    public static func runAll(ignoreSigPipe: Bool = true) {
        if ignoreSigPipe {
            signal(SIGPIPE, SIG_IGN)
        }
        dispatch_main()
    }
    
}