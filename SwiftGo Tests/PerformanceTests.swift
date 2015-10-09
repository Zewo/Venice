// PerformanceTests.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
import SwiftGo

let thousand = 1000
let million = 1000000

class PerformanceTests: XCTestCase {

    func testCoroutinePerformanceSwiftGo() {
        self.measureMetrics(XCTestCase.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let channel = Channel<Void>()
            self.startMeasuring()
            go {
                self.stopMeasuring()
                channel <- Void()
            }
            <-channel
        }
    }
    
    func testThreadPerformanceGCD() {
        self.measureMetrics(XCTestCase.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let semaphore = dispatch_semaphore_create(0)
            let queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
            self.startMeasuring()
            dispatch_async(queue) {
                self.stopMeasuring()
                dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }
    }
    
    func testSyncPerformanceSwiftGo() {
        self.measureBlock {
            let channel = Channel<Void>()
            go {
                channel <- Void()
            }
            <-channel
        }
    }
    
    func testSyncPerformanceGCD() {
        self.measureBlock {
            let semaphore = dispatch_semaphore_create(0)
            let queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
            dispatch_async(queue) {
                dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }
    }

    func testMillionCoroutines() {
        self.measureBlock {
            let numberOfCoroutines = million
            for _ in 0 ..< numberOfCoroutines { go {} }
        }
    }

    func testThousandWhispers() {
        self.measureBlock {
            func whisper(left: ReceivingChannel<Int>, _ right: SendingChannel<Int>) {
                left <- 1 + !<-right
            }

            let numberOfWhispers = thousand

            let leftmost = Channel<Int>()
            var right = leftmost
            var left = leftmost

            for _ in 0 ..< numberOfWhispers {
                right = Channel<Int>()
                go(whisper(left.receivingChannel, right.sendingChannel))
                left = right
            }
            
            go(right <- 1)
            XCTAssert(!<-leftmost == numberOfWhispers + 1)
        }
    }

    func testMillionContextSwitches() {
        self.measureBlock {
            let numberOfContextSwitches = million
            let count = numberOfContextSwitches / 2
            go {
                for _ in 0 ..< count {
                    yield
                }
            }
            for _ in 0 ..< count {
                yield
            }
        }
    }

    func testSendReceiveMillionMessages() {
        self.measureBlock {
            let numberOfMessages = million
            let channel = Channel<Int>(bufferSize: numberOfMessages)
            for _ in 0 ..< numberOfMessages {
                channel <- 0
            }
            for _ in 0 ..< numberOfMessages {
                <-channel
            }
        }
    }

    func testMillionRoundTrips() {
        self.measureBlock {
            let numberOfRoundTrips = million
            let input = Channel<Int>()
            let output = Channel<Int>()
            let initiaValue = 1969
            var value = initiaValue
            go {
                while true {
                    let value = !<-output
                    input <- value
                }
            }
            for _ in 0 ..< numberOfRoundTrips {
                output <- value
                value = !<-input
            }
            XCTAssert(value == initiaValue)
        }
    }
    
}
