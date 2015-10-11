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

    func testNonBlockingSender() {
        let channel = Channel<Int>()
        go {
            let value = <-channel
            XCTAssert(value == 777)
        }
        sel { when in
            when.send(777, to: channel) {}
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

    func testReceiveRandomChannelSelection() {
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

    func testSendRandomChannelSelection() {
        let channel = Channel<Int>()
        go {
            while true {
                sel { when in
                    when.send(666, to: channel) {}
                    when.send(777, to: channel) {}
                }
            }
        }
        var first = 0
        var second = 0
        for _ in 0 ..< 100 {
            let value = <-channel
            if value == 666 {
                ++first
            } else if value == 777 {
                ++second
            } else {
                XCTAssert(false)
            }

        }
        XCTAssert(first > 1 && second > 1)
    }

    func testOtherwise() {
        let channel = Channel<Int>()
        var test = 0
        sel { when in
            when.receiveFrom(channel) { value in
                XCTAssert(false)
            }
            when.otherwise {
                test = 1
            }
        }
        XCTAssert(test == 1)
        test = 0
        sel { when in
            when.otherwise {
                test = 1
            }
        }
        XCTAssert(test == 1)
    }

    func testTwoSimultaneousSenders() {
        let channel = Channel<Int>()
        go {
            channel <- 888
        }
        go {
            channel <- 999
        }
        var value = 0
        sel { when in
            when.receiveFrom(channel) { v in
                value = v
            }
        }
        XCTAssert(value == 888)
        value = 0
        sel { when in
            when.receiveFrom(channel) { v in
                value = v
            }
        }
        XCTAssert(value == 999)
    }

    func testTwoSimultaneousReceivers() {
        let channel = Channel<Int>()
        go {
            XCTAssert(<-channel == 333)
        }
        go {
            XCTAssert(<-channel == 444)
        }
        sel { when in
            when.send(333, to: channel) {}
        }
        sel { when in
            when.send(444, to: channel) {}
        }
    }

    func testSelectWithSelect() {
        let channel = Channel<Int>()
        go {
            sel { when in
                when.send(111, to: channel) {}
            }
        }
        sel { when in
            when.receiveFrom(channel) { value in
                XCTAssert(value == 111)
            }
        }
    }

    func testSelectWithBufferedChannels() {
        let channel = Channel<Int>(bufferSize: 1)
        sel { when in
            when.send(999, to: channel) {}
        }
        sel { when in
            when.receiveFrom(channel) { value in
                XCTAssert(value == 999)
            }
        }
    }

    func testReceiveSelectFromClosedChannel() {
        let channel = Channel<Int>()
        channel.close()
        sel { when in
            when.receiveFrom(channel) { value in
                XCTAssert(false)
            }
        }
    }

    func testRandomReceiveSelectionWhenNothingImmediatelyAvailable() {
        let channel = Channel<Int>()
        go {
            while true {
                nap(1 * millisecond)
                channel <- 333
            }
        }
        var first = 0
        var second = 0
        var third = 0
        for _ in 0 ..< 100 {
            sel { when in
                when.receiveFrom(channel) { value in
                    ++first
                }
                when.receiveFrom(channel) { value in
                    ++second
                }
                when.receiveFrom(channel) { value in
                    ++third
                }
            }
        }
        XCTAssert(first > 1 && second > 1 && third > 1)
    }

    func testRandomSendSelectionWhenNothingImmediatelyAvailable() {
        let channel = Channel<Int>()
        go {
            while true {
                sel { when in
                    when.send(1, to: channel) {}
                    when.send(2, to: channel) {}
                    when.send(3, to: channel) {}
                }
            }
        }
        var first = 0
        var second = 0
        var third = 0
        for _ in 0 ..< 100 {
            nap(1 * millisecond)
            let value = !<-channel
            switch value {
            case 1: ++first
            case 2: ++second
            case 3: ++third
            default: XCTAssert(false)
            }

        }
        XCTAssert(first > 1 && second > 1 && third > 1)
    }

    func testReceivingFromSendingChannel() {
        let channel = Channel<Int>()
        go {
            channel <- 555
        }
        sel { when in
            when.receiveFrom(channel.sendingChannel) { value in
                XCTAssert(value == 555)
            }
        }
    }

    func testReceivingFromFallibleChannel() {
        let channel = FallibleChannel<Int>()
        go {
            channel <- 555
        }
        sel { when in
            when.receiveFrom(channel) { result in
                var value = 0
                result.success { v in
                    value = v
                }
                XCTAssert(value == 555)
            }
        }
    }

    func testReceivingErrorFromFallibleChannel() {
        let channel = FallibleChannel<Int>()
        go {
            channel <- Error()
        }
        sel { when in
            when.receiveFrom(channel) { result in
                var error: ErrorType? = nil
                result.failure { e in
                    error = e
                }
                XCTAssert(error is Error)
            }
        }
    }

    func testReceivingFromFallibleSendingChannel() {
        let channel = FallibleChannel<Int>()
        go {
            channel <- 555
        }
        sel { when in
            when.receiveFrom(channel.sendingChannel) { result in
                var value = 0
                result.success { v in
                    value = v
                }
                XCTAssert(value == 555)
            }
        }
    }

    func testReceivingErrorFromFallibleSendingChannel() {
        let channel = FallibleChannel<Int>()
        go {
            channel <- Error()
        }
        sel { when in
            when.receiveFrom(channel.sendingChannel) { result in
                var error: ErrorType? = nil
                result.failure { e in
                    error = e
                }
                XCTAssert(error is Error)
            }
        }
    }

    func testSendingToReceivingChannel() {
        let channel = Channel<Int>()
        go {
            let value = <-channel
            XCTAssert(value == 777)
        }
        sel { when in
            when.send(777, to: channel.receivingChannel) {}
        }
    }

    func testSendingToFallibleChannel() {
        let channel = FallibleChannel<Int>()
        go {
            let value = try! <-channel
            XCTAssert(value == 777)
        }
        sel { when in
            when.send(777, to: channel) {}
        }
    }

    func testThrowingErrorIntoFallibleChannel() {
        let channel = FallibleChannel<Int>()
        go {
            self.assertChannel(channel, catchesErrorOfType: Error.self)
        }
        sel { when in
            when.throwError(Error(), into: channel) {}
        }
    }

    func testSendingToFallibleReceivingChannel() {
        let channel = FallibleChannel<Int>()
        go {
            let value = try! <-channel
            XCTAssert(value == 777)
        }
        sel { when in
            when.send(777, to: channel.receivingChannel) {}
        }
    }

    func testThrowingErrorIntoFallibleReceivingChannel() {
        let channel = FallibleChannel<Int>()
        go {
            self.assertChannel(channel, catchesErrorOfType: Error.self)
        }
        sel { when in
            when.throwError(Error(), into: channel.receivingChannel) {}
        }
    }

    func testTimeout() {
        var timedout = false
        sel { when in
            when.timeout(now + 10 * millisecond) {
                timedout = true
            }
        }
        XCTAssert(timedout)
    }

}

extension SelectTests {

    private func assertChannel<T : FallibleSendable, E>(channel: T, catchesErrorOfType type: E.Type) {
        var thrown = false
        do {
            try <-channel
        } catch _ as E {
            thrown = true
        } catch {}
        XCTAssert(thrown)
    }
    
}
