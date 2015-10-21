// CoTests.swift
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
import Venice

class CoTests: XCTestCase {

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

    func testCo() {
        co(self.worker(count: 3, n: 7))
        co(self.worker(count: 1, n: 11))
        co(self.worker(count: 2, n: 5))
        nap(100 * millisecond)
        XCTAssert(sum == 42)
    }

    func testStackdeallocationWorks() {
        for _ in 0 ..< 20 {
            after(50 * millisecond) {}
        }
        nap(100)
    }

    func testWakeUp() {
        let deadline = now + 100 * millisecond
        wakeUp(deadline)
        let diff = now - deadline
        XCTAssert(diff > -200 && diff < 200)
    }

    func testNap() {
        let channel = Channel<Int64>()
        func delay(n: Int64) {
            nap(n)
            channel <- n
        }
        co(delay(30))
        co(delay(40))
        co(delay(10))
        co(delay(20))
        XCTAssert(<-channel == 10)
        XCTAssert(<-channel == 20)
        XCTAssert(<-channel == 30)
        XCTAssert(<-channel == 40)
    }

    func testPollFileDescriptor() {
        var pollResult: PollResult
        var size: Int
        let fds = UnsafeMutablePointer<Int32>.alloc(2)
        let result = socketpair(AF_UNIX, SOCK_STREAM, 0, fds)
        XCTAssert(result == 0)

        pollResult = pollFileDescriptor(fds[0], events: [.Write])
        XCTAssert(pollResult == .Write)

        pollResult = pollFileDescriptor(fds[0], events: [.Write], deadline: now + 100 * millisecond)
        XCTAssert(pollResult == .Write)

        let deadline = now + 100 * millisecond
        pollResult = pollFileDescriptor(fds[0], events: [.Read], deadline: deadline)
        XCTAssert(pollResult == .Timeout)

        size = send(fds[1], "A", 1, 0)
        XCTAssert(size == 1)
        pollResult = pollFileDescriptor(fds[0], events: [.Write])
        XCTAssert(pollResult == .Write)

        pollResult = pollFileDescriptor(fds[0], events: [.Read, .Write])
        XCTAssert(pollResult == [.Read, .Write])

        var c: Int8 = 0
        size = recv(fds[0], &c, 1, 0)
        XCTAssert(size == 1)
        XCTAssert(c == 65)
    }
}
