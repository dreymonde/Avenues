//
//  AvenuesTests.swift
//  Avenues
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Avenues. All rights reserved.
//

import Foundation
import XCTest
@testable import Avenues

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
        let avenue = SymmetricalAvenue<Int, String>(storage: storage,
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
        let avenue = SymmetricalAvenue<Int, String>(storage: .dictionaryBased(),
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
        let avenue = SymmetricalAvenue<Int, String>(storage: .dictionaryBased(),
                                         processor: processor,
                                         callbackMode: .mainQueue)
        avenue.onError = { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        avenue.prepareItem(at: 2)
        waitForExpectations(timeout: 5.0)
    }
    
    func testForce() {
        var dict: [Int : String] = [5: "10"]
        let storage = Storage<Int, String>(get: { dict[$0] }, set: { dict[$1] = $0 }, clear: { dict = [:] })
        let expectation = self.expectation(description: "On start")
        var force = false
        let processor = Processor<Int, String>(start: { _ in force ? expectation.fulfill() : XCTFail() },
                                  cancel: emptyFunc,
                                  getState: { _ in return .undefined },
                                  cancelAll: emptyFunc)
        let avenue = SymmetricalAvenue(storage: storage,
                            processor: processor,
                            callbackMode: .privateQueue)
        avenue.prepareItem(at: 5, force: false)
        force = true
        avenue.prepareItem(at: 5, force: true)
        waitForExpectations(timeout: 5.0)
    }
    
    func testInFlight() {
        let proc = Processor<Int, String>(start: { _ in XCTFail() },
                                          cancel: emptyFunc,
                                          getState: { _ in return .running },
                                          cancelAll: emptyFunc)
        let avenue = SymmetricalAvenue(storage: .dictionaryBased(),
                            processor: proc,
                            callbackMode: .privateQueue)
        XCTAssertEqual(avenue.processingState(ofItemAt: 5), .running)
        avenue.test_syncPrepareItem(at: 5, storingTo: 5, force: false)
    }
    
    func testCancel() {
        let expectation = self.expectation(description: "On cancel")
        let proc = Processor<Int, String>(start: emptyFunc,
                                          cancel: { _ in expectation.fulfill() },
                                          getState: { _ in .undefined },
                                          cancelAll: emptyFunc)
        let avenue = SymmetricalAvenue(storage: .dictionaryBased(),
                            processor: proc,
                            callbackMode: .privateQueue)
        avenue.cancelProcessing(ofItemAt: 5)
        waitForExpectations(timeout: 5.0)
    }
    
    class AutoIntStr : AutoProcessorProtocol {
        
        typealias Key = Int
        typealias Value = String
        
        func start(key: Int, completion: @escaping (ProcessorResult<String>) -> ()) {
            DispatchQueue.global(qos: .background).async {
                completion(.success(key.description))
            }
        }
        
        func cancel(key: Int) -> Bool {
            return false
        }
        
        func cancelAll() {
            // not supported
        }
        
    }
    
    func testAuto() {
        let expectation = self.expectation(description: "On change")
        let autoProc = AutoIntStr()
        let storage = Storage<Int, String>.dictionaryBased()
        let avenue = Avenue(storage: storage, processor: autoProc.processor())
        avenue.onStateChange = { index in
            let value = avenue.item(at: 5)
            XCTAssertEqual(value, "5")
            XCTAssertEqual(avenue.processingState(ofItemAt: 5), .completed)
            expectation.fulfill()
        }
        XCTAssertEqual(avenue.processingState(ofItemAt: 5), .none)
        avenue.prepareItem(at: 5)
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
