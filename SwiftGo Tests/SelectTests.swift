// SelectTests.swift
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
import Libmill

class SelectTests: XCTestCase {

    func testNonBlockingReceiver() {
        let channel = Channel<Int>()
        go {
            channel <- 555
        }
        sel { when in
            when.receiveFrom(channel) { value in
                XCTAssert(value == 555)
            }
        }
    }

    func testBlockingReceiver() {
        let channel = Channel<Int>()
        go {
            yield
            channel <- 666
        }
        sel { when in
            when.receiveFrom(channel) { value in
                XCTAssert(value == 666)
            }
        }
    }

    func testBlockingSender() {
        let channel = Channel<Int>()
        go {
            yield
            XCTAssert(<-channel == 888)
        }
        sel { when in
            when.send(888, to: channel) {}
        }
    }

    func testTwoChannels() {
        let channel1 = Channel<Int>()
        let channel2 = Channel<Int>()
        go {
            channel1 <- 555
        }
        sel { when in
            when.receiveFrom(channel1) { value in
                XCTAssert(value == 555)
            }
            when.receiveFrom(channel2) { value in
                XCTAssert(false)
            }
        }
        go {
            yield
            channel2 <- 666
        }
        sel { when in
            when.receiveFrom(channel1) { value in
                XCTAssert(false)
            }
            when.receiveFrom(channel2) { value in
                XCTAssert(value == 666)
            }
        }
    }

    func testRandomChannelSelection() {
        let channel1 = Channel<Int>()
        let channel2 = Channel<Int>()
        go {
            while true {
                channel1 <- 111
                yield
            }
        }
        go {
            while true {
                channel2 <- 222
                yield
            }
        }
        var first = 0
        var second = 0
        for _ in 0 ..< 100 {
            sel { when in
                when.receiveFrom(channel1) { value in
                    XCTAssert(value == 111)
                    ++first
                }
                when.receiveFrom(channel2) { value in
                    XCTAssert(value == 222)
                    ++second
                }
            }
            yield
        }
        XCTAssert(first > 1 && second > 1)
    }
    
}
