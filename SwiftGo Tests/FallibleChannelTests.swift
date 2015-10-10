// FallibleChannelTests.swift
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

class FallibleChannelTests: XCTestCase {

    func testReceiverWaitsForSender() {
        let channel = FallibleChannel<Int>()
        go {
            yield
            channel <- 333
        }
        let value = try! <-channel
        XCTAssert(value == 333)
    }

    func testSenderWaitsForReceiver() {
        let channel = FallibleChannel<Int>()
        go {
            channel <- 444
        }
        let value = try! <-channel
        XCTAssert(value == 444)
    }

    func testReceivingChannel() {
        let channel = FallibleChannel<Int>()
        func receive(channel: FallibleReceivingChannel<Int>) {
            channel <- 888
        }
        go(receive(channel.receivingChannel))
        let value = try! <-channel
        XCTAssert(value == 888)
    }

    func testSendingChannel() {
        let channel = FallibleChannel<Int>()
        func send(channel: FallibleSendingChannel<Int>) {
            let value = try! <-channel
            XCTAssert(value == 999)
        }
        go{
            channel <- 999
        }
        send(channel.sendingChannel)
    }

    func testTwoSimultaneousSenders() {
        let channel = FallibleChannel<Int>()
        go {
            channel <- 888
        }
        go {
            channel <- 999
        }
        let value1 = try! <-channel
        XCTAssert(value1 == 999) // TODO: check this
        yield
        let value2 = try! <-channel
        XCTAssert(value2 == 999)
    }

    func testChannelIteration() {
        let channel =  FallibleChannel<Int>(bufferSize: 2)
        channel <- 555
        channel <- 555
        channel.close()
        for value in channel {
            XCTAssert(value == 555)
        }
    }

    func testSendingChannelIteration() {
        let channel =  FallibleChannel<Int>(bufferSize: 2)
        channel <- 444
        channel <- 444
        func receive(channel: FallibleSendingChannel<Int>) {
            channel.close()
            for value in channel {
                XCTAssert(value == 444)
            }
        }
        receive(channel.sendingChannel)
    }

    func testTwoSimultaneousReceivers() {
        let channel = FallibleChannel<Int>()
        go {
            let value = try! <-channel
            XCTAssert(value == 333)
        }
        go {
            let value = try! <-channel
            XCTAssert(value == 444)
        }
        channel <- 333
        channel <- 444
    }

    func testTypedChannels() {
        let stringChannel = FallibleChannel<String>()
        go {
            stringChannel <- "yo"
        }
        let string = try! <-stringChannel
        XCTAssert(string == "yo")

        struct Foo { let bar: Int; let baz: Int }

        let fooChannel = FallibleChannel<Foo>()
        go {
            fooChannel <- Foo(bar: 555, baz: 222)
        }
        let foo = try! <-fooChannel
        XCTAssert(foo?.bar == 555 && foo?.baz == 222)
    }

    func testMessageBuffering() {
        let channel = FallibleChannel<Int>(bufferSize: 2)
        channel <- 222
        channel <- 333
        XCTAssert(try! <-channel == 222)
        XCTAssert(try! <-channel == 333)
        channel <- 444
        XCTAssert(try! <-channel == 444)
        channel <- 555
        channel <- 666
        XCTAssert(try! <-channel == 555)
        XCTAssert(try! <-channel == 666)
    }

    func testSimpleChannelClose() {
        let channel1 = FallibleChannel<Int>()
        channel1.close()
        XCTAssert(try! <-channel1 == nil)
        XCTAssert(try! <-channel1 == nil)
        XCTAssert(try! <-channel1 == nil)

        let channel2 = FallibleChannel<Int>(bufferSize: 10)
        channel2.close()
        XCTAssert(try! <-channel2 == nil)
        XCTAssert(try! <-channel2 == nil)
        XCTAssert(try! <-channel2 == nil)

        let channel3 = FallibleChannel<Int>(bufferSize: 10)
        channel3 <- 999
        channel3.close()
        XCTAssert(try! <-channel3 == 999)
        XCTAssert(try! <-channel3 == nil)
        XCTAssert(try! <-channel3 == nil)

        let channel4 = FallibleChannel<Int>(bufferSize: 1)
        channel4 <- 222
        channel4.close()
        XCTAssert(try! <-channel4 == 222)
        XCTAssert(try! <-channel4 == nil)
        XCTAssert(try! <-channel4 == nil)
    }

    func testChannelCloseUnblocks() {
        let channel1 = FallibleChannel<Int>()
        let channel2 = FallibleChannel<Int>()
        go {
            XCTAssert(try! <-channel1 == nil)
            channel2 <- 0
        }
        go {
            XCTAssert(try! <-channel1 == nil)
            channel2 <- 0
        }
        channel1.close()
        XCTAssert(try! <-channel2 == 0)
        XCTAssert(try! <-channel2 == 0)
    }

    func testBlockedSenderAndItemInTheChannel() {
        let channel = FallibleChannel<Int>(bufferSize: 1)
        channel <- 1
        go {
            channel <- 2
        }
        XCTAssert(try! <-channel == 1)
        XCTAssert(try! <-channel == 2)
    }

    func expectedAbort(signo: Int) {

    }

    func testPanicWhenSendingToChannelDeadlocks() {
        let pid = mill_fork()
        XCTAssert(pid >= 0)
        if pid == 0 {
            alarm(1)
            let channel = FallibleChannel<Int>()
            signal(SIGABRT) { _ in
                _exit(0)
            }
            channel <- 42
            XCTFail()
        }
        var exitCode: Int32 = 0
        XCTAssert(waitpid(pid, &exitCode, 0) != 0)
        XCTAssert(exitCode == 0)
    }

    func testPanicWhenReceivingFromChannelDeadlocks() {
        let pid = mill_fork()
        XCTAssert(pid >= 0)
        if pid == 0 {
            alarm(1)
            let channel = FallibleChannel<Int>()
            signal(SIGABRT) { _ in
                _exit(0)
            }
            try! <-channel
            XCTFail()
        }
        var exitCode: Int32 = 0
        XCTAssert(waitpid(pid, &exitCode, 0) != 0)
        XCTAssert(exitCode == 0)
    }

}
