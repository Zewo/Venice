// TimerTests.swift
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

class TimerTests: XCTestCase {

    func testTimer() {
        let looseness = 150
        let deadline = now + 100 * millisecond
        let timer = Timer(deadline: deadline)
        <-timer.channel
        let fireTime = now
        XCTAssert(fireTime < deadline + looseness && fireTime > deadline - looseness)
    }

    func testTimerStops() {
        let deadline = now + 100 * millisecond
        let timer = Timer(deadline: deadline)
        go {
            <-timer.channel
        }
        XCTAssert(timer.stop() == true)
    }

    func testTimerStopsReturnFalse() {
        let deadline = now + 100 * millisecond
        let timer = Timer(deadline: deadline)
        go {
            <-timer.channel
        }
        wakeUp(deadline + 100 * millisecond)
        XCTAssert(timer.stop() == false)
    }
    
}
