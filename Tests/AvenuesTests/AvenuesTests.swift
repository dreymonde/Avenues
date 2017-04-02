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

class FakeProc<Key : Hashable> : Avenues.ProcessorProtocol {
    
    func start(key: Key, completion: @escaping (ProcessorResult<String>) -> ()) {
        DispatchQueue.global(qos: .background).async(execute: {
            completion(.success("Got that"))
        })
    }
    
    func cancel(key: Key) {
        //
    }
    
    func processingState(key: Key) -> ProcessingState {
        return .none
    }
    
    func cancelAll() {
        //
    }
    
    func processor() -> Processor<Key, String> {
        return Processor(self)
    }
    
}

extension String : Error { }

class AvenuesTests: XCTestCase {
    
    override func setUp() {
        Avenues.Log.isEnabled = true
    }
    
    func testFetch() {
        let expectation = self.expectation(description: "Avenue")
        let storage = Storage<Int, String>.dictionaryBased()
        let avenue = Avenue<Int, String>(storage: storage,
                                         processor: FakeProc<Int>().processor(),
                                         callbackMode: .privateQueue)
        avenue.onStateChange = { [unowned avenue] index in
            let item = avenue.item(at: index)
            XCTAssertEqual(item, "Got that")
            expectation.fulfill()
        }
        avenue.prepareItem(at: 1)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMainQueueStateChange() {
        let expectation = self.expectation(description: "Avenue main queue callback")
        let avenue = Avenue<Int, String>(storage: .dictionaryBased(),
                                         processor: FakeProc<Int>().processor(),
                                         callbackMode: .mainQueue)
        avenue.onStateChange = { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        avenue.prepareItem(at: 2)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMainQueueError() {
        let expectation = self.expectation(description: "Avenue main queue callback")
        let processor = Processor<Int, String>(start: { (number, callback) in
            callback(.failure("Sorry, buddy"))
        }, cancel: emptyFunc, getState: { _ in .undefined }, cancelAll: emptyFunc)
        let avenue = Avenue<Int, String>(storage: .dictionaryBased(),
                                         processor: processor,
                                         callbackMode: .mainQueue)
        avenue.onError = { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        avenue.prepareItem(at: 2)
        waitForExpectations(timeout: 5.0)
    }
    
}

func emptyFunc<Input>(_ input: Input) -> Void {
    
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
