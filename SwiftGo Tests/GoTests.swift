// GoTests.swift
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

class GoTests: XCTestCase {

    var sum: Int = 0

    override func setUp() {
        preallocateCoroutineStacks(stackCount: 10, stackSize: 25000, channelValueMaxSize: 300)
    }

    func worker(count count: Int, n: Int) {
        for _ in 0 ..< count {
            sum += n
            yield
        }
    }

    func testGo() {
        go(self.worker(count: 3, n: 7))
        go(self.worker(count: 1, n: 11))
        go(self.worker(count: 2, n: 5))
        nap(100 * millisecond)
        XCTAssert(sum == 42)
    }

    func testStackdeallocationWorks() {
        for _ in 0 ..< 20 {
            go(nap(50 * millisecond))
        }
        nap(100)
    }

    func testWakeUp() {
        let deadline = now + 100 * millisecond
        wakeUp(deadline)
        let diff = now - deadline
        print(diff)
        XCTAssert(diff > -150 && diff < 150)
    }

    func testNap() {
        let channel = Channel<Int>()
        func delay(n: Int) {
            nap(n)
            channel <- n
        }
        go(delay(30))
        go(delay(40))
        go(delay(10))
        go(delay(20))
        XCTAssert(<-channel == 10)
        XCTAssert(<-channel == 20)
        XCTAssert(<-channel == 30)
        XCTAssert(<-channel == 40)
    }

}
