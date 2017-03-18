//
//  AvenuesTests.swift
//  Avenues
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Avenues. All rights reserved.
//

import Foundation
import XCTest
import Avenues

class AvenuesTests: XCTestCase {
    
    func testAvenue() {
        
    }
    
}

#if os(Linux)
extension AvenuesTests {
    static var allTests : [(String, (AvenuesTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
#endif
