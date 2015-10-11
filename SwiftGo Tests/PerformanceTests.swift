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

class PerformanceTests: XCTestCase {

    func testSyncPerformanceSwiftGo() {
        self.measureBlock {
            let numberOfSyncs = 10000
            let channel = Channel<Void>()
            for _ in 0 ..< numberOfSyncs {
                go {
                    channel <- Void()
                }
                <-channel
            }
        }
    }

    func testSyncPerformanceGCD() {
        self.measureBlock {
            let numberOfSyncs = 10000
            let semaphore = dispatch_semaphore_create(0)
            let queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
            for _ in 0 ..< numberOfSyncs {
                dispatch_async(queue) {
                    dispatch_semaphore_signal(semaphore)
                }
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            }
        }
    }

    func testManyCoroutines() {
        self.measureBlock {
            let numberOfCoroutines = 10000
            for _ in 0 ..< numberOfCoroutines { go {} }
        }
    }

    func testManyThreads() {
        self.measureBlock {
            let numberOfThreads = 10000
            let queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
            for _ in 0 ..< numberOfThreads { dispatch_async(queue) {} }
        }
    }

    func testThousandWhispers() {
        self.measureBlock {
            func whisper(left: ReceivingChannel<Int>, _ right: SendingChannel<Int>) {
                left <- 1 + !<-right
            }

            let numberOfWhispers = 10000

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

    func testManyContextSwitches() {
        self.measureBlock {
            let numberOfContextSwitches = 10000
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

    func testSendReceiveManyMessages() {
        self.measureBlock {
            let numberOfMessages = 10000
            let channel = Channel<Int>(bufferSize: numberOfMessages)
            for _ in 0 ..< numberOfMessages {
                channel <- 0
            }
            for _ in 0 ..< numberOfMessages {
                <-channel
            }
        }
    }

    func testManyRoundTrips() {
        self.measureBlock {
            let numberOfRoundTrips = 10000
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
