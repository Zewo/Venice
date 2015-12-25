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
import Venice
import CLibvenice

struct Error: ErrorType {}
struct NastyError: ErrorType {}

class FallibleChannelTests: XCTestCase {
    func testReceiverWaitsForSender() {
        let channel = FallibleChannel<Int>()
        co {
            yield
            channel <- 333
        }
        XCTAssert(try! <-channel == 333)
    }

    func testReceiverWaitsForSenderError() {
        let channel = FallibleChannel<Int>()
        co {
            yield
            channel <- Error()
        }
        assertChannel(channel, catchesErrorOfType: Error.self)
    }

    func testSenderWaitsForReceiver() {
        let channel = FallibleChannel<Int>()
        co {
            channel <- 444
        }
        XCTAssert(try! <-channel == 444)
    }

    func testSenderWaitsForReceiverError() {
        let channel = FallibleChannel<Int>()
        co {
            channel <- Error()
        }
        assertChannel(channel, catchesErrorOfType: Error.self)
    }

    func testReceivingChannel() {
        let channel = FallibleChannel<Int>()
        func receive(channel: FallibleSendingChannel<Int>) {
            channel <- 888
        }
        co(receive(channel.sendingChannel))
        XCTAssert(try! <-channel == 888)
    }

    func testReceivingChannelError() {
        let channel = FallibleChannel<Int>()
        func receive(channel: FallibleSendingChannel<Int>) {
            channel <- Error()
        }
        co(receive(channel.sendingChannel))
        assertChannel(channel, catchesErrorOfType: Error.self)
    }

    func testSendingChannel() {
        let channel = FallibleChannel<Int>()
        func send(channel: FallibleReceivingChannel<Int>) {
            XCTAssert(try! <-channel == 999)
        }
        co{
            channel <- 999
        }
        send(channel.receivingChannel)
    }

    func testSendingChannelError() {
        let channel = FallibleChannel<Int>()
        func send(channel: FallibleReceivingChannel<Int>) {
            assertChannel(channel, catchesErrorOfType: Error.self)
        }
        co{
            channel <- Error()
        }
        send(channel.receivingChannel)
    }

    func testTwoSimultaneousSenders() {
        let channel = FallibleChannel<Int>()
        co {
            channel <- 888
        }
        co {
            channel <- 999
        }
        XCTAssert(try! <-channel == 888)
        yield
        XCTAssert(try! <-channel == 999)
    }

    func testTwoSimultaneousSendersError() {
        let channel = FallibleChannel<Int>()
        co {
            channel <- Error()
        }
        co {
            channel <- NastyError()
        }
        assertChannel(channel, catchesErrorOfType: Error.self)
        yield
        assertChannel(channel, catchesErrorOfType: NastyError.self)
    }

    func testTwoSimultaneousReceivers() {
        let channel = FallibleChannel<Int>()
        co {
            XCTAssert(try! <-channel == 333)
        }
        co {
            XCTAssert(try! <-channel == 444)
        }
        channel <- 333
        channel <- 444
    }

    func testTwoSimultaneousReceiversError() {
        let channel = FallibleChannel<Int>()
        co {
            self.assertChannel(channel, catchesErrorOfType: Error.self)
        }
        co {
            self.assertChannel(channel, catchesErrorOfType: NastyError.self)
        }
        channel <- Error()
        channel <- NastyError()
    }

    func testTypedChannels() {
        let stringChannel = FallibleChannel<String>()
        co {
            stringChannel <- "yo"
        }
        XCTAssert(try! <-stringChannel == "yo")

        struct Foo { let bar: Int; let baz: Int }

        let fooChannel = FallibleChannel<Foo>()
        co {
            fooChannel <- Foo(bar: 555, baz: 222)
        }
        let foo = try! <-fooChannel
        XCTAssert(foo?.bar == 555 && foo?.baz == 222)
    }

    func testTypedChannelsError() {
        let stringChannel = FallibleChannel<String>()
        co {
            stringChannel <- Error()
        }
        assertChannel(stringChannel, catchesErrorOfType: Error.self)

        struct Foo { let bar: Int; let baz: Int }

        let fooChannel = FallibleChannel<Foo>()
        co {
            fooChannel <- NastyError()
        }
        assertChannel(fooChannel, catchesErrorOfType: NastyError.self)
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

    func testMessageBufferingError() {
        let channel = FallibleChannel<Int>(bufferSize: 2)
        channel <- Error()
        channel <- NastyError()
        assertChannel(channel, catchesErrorOfType: Error.self)
        assertChannel(channel, catchesErrorOfType: NastyError.self)
        channel <- Error()
        assertChannel(channel, catchesErrorOfType: Error.self)
        channel <- Error()
        channel <- NastyError()
        assertChannel(channel, catchesErrorOfType: Error.self)
        assertChannel(channel, catchesErrorOfType: NastyError.self)
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


    func testSimpleChannelCloseError() {
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
        channel3 <- Error()
        channel3.close()
        assertChannel(channel3, catchesErrorOfType: Error.self)
        XCTAssert(try! <-channel3 == nil)
        XCTAssert(try! <-channel3 == nil)

        let channel4 = FallibleChannel<Int>(bufferSize: 1)
        channel4 <- NastyError()
        channel4.close()
        assertChannel(channel4, catchesErrorOfType: NastyError.self)
        XCTAssert(try! <-channel4 == nil)
        XCTAssert(try! <-channel4 == nil)
    }

    func testChannelCloseUnblocks() {
        let channel1 = FallibleChannel<Int>()
        let channel2 = FallibleChannel<Int>()
        co {
            XCTAssert(try! <-channel1 == nil)
            channel2 <- 0
        }
        co {
            XCTAssert(try! <-channel1 == nil)
            channel2 <- 0
        }
        channel1.close()
        XCTAssert(try! <-channel2 == 0)
        XCTAssert(try! <-channel2 == 0)
    }

    func testChannelCloseUnblocksError() {
        let channel1 = FallibleChannel<Int>()
        let channel2 = FallibleChannel<Int>()
        co {
            XCTAssert(try! <-channel1 == nil)
            channel2 <- Error()
        }
        co {
            XCTAssert(try! <-channel1 == nil)
            channel2 <- NastyError()
        }
        channel1.close()
        assertChannel(channel2, catchesErrorOfType: Error.self)
        assertChannel(channel2, catchesErrorOfType: NastyError.self)
    }

    func testBlockedSenderAndItemInTheChannel() {
        let channel = FallibleChannel<Int>(bufferSize: 1)
        channel <- 1
        co {
            channel <- 2
        }
        XCTAssert(try! <-channel == 1)
        XCTAssert(try! <-channel == 2)
    }

    func testBlockedSenderAndItemInTheError() {
        let channel = FallibleChannel<Int>(bufferSize: 1)
        channel <- Error()
        co {
            channel <- NastyError()
        }
        assertChannel(channel, catchesErrorOfType: Error.self)
        assertChannel(channel, catchesErrorOfType: NastyError.self)
    }

//    func testPanicWhenSendingToChannelDeadlocks() {
//        let pid = mill_fork()
//        XCTAssert(pid >= 0)
//        if pid == 0 {
//            alarm(1)
//            let channel = FallibleChannel<Int>()
//            signal(SIGABRT) { _ in
//                _exit(0)
//            }
//            channel <- 42
//            XCTFail()
//        }
//        var exitCode: Int32 = 0
//        XCTAssert(waitpid(pid, &exitCode, 0) != 0)
//        XCTAssert(exitCode == 0)
//    }
//
//    func testPanicWhenSendingToChannelDeadlocksError() {
//        let pid = mill_fork()
//        XCTAssert(pid >= 0)
//        if pid == 0 {
//            alarm(1)
//            let channel = FallibleChannel<Int>()
//            signal(SIGABRT) { _ in
//                _exit(0)
//            }
//            channel <- Error()
//            XCTFail()
//        }
//        var exitCode: Int32 = 0
//        XCTAssert(waitpid(pid, &exitCode, 0) != 0)
//        XCTAssert(exitCode == 0)
//    }
//
//    func testPanicWhenReceivingFromChannelDeadlocks() {
//        let pid = mill_fork()
//        XCTAssert(pid >= 0)
//        if pid == 0 {
//            alarm(1)
//            let channel = FallibleChannel<Int>()
//            signal(SIGABRT) { _ in
//                _exit(0)
//            }
//            try! <-channel
//            XCTFail()
//        }
//        var exitCode: Int32 = 0
//        XCTAssert(waitpid(pid, &exitCode, 0) != 0)
//        XCTAssert(exitCode == 0)
//    }

    func testChannelIteration() {
        let channel =  FallibleChannel<Int>(bufferSize: 2)
        channel <- 555
        channel <- 555
        channel.close()
        for result in channel {
            var value = 0
            result.success { v in
                value = v
            }
            result.failure { _ in
                XCTAssert(false)
            }
            XCTAssert(value == 555)
        }
    }

    func testChannelIterationError() {
        let channel =  FallibleChannel<Int>(bufferSize: 2)
        channel <- Error()
        channel <- Error()
        channel.close()
        for result in channel {
            var error: ErrorType? = nil
            result.failure { e in
                error = e
            }
            result.success { _ in
                XCTAssert(false)
            }
            XCTAssert(error is Error)
        }
    }

    func testSendingChannelIteration() {
        let channel =  FallibleChannel<Int>(bufferSize: 2)
        channel <- 444
        channel <- 444
        func receive(channel: FallibleReceivingChannel<Int>) {
            channel.close()
            for result in channel {
                var value = 0
                result.success { v in
                    value = v
                }
                XCTAssert(value == 444)
            }
        }
        receive(channel.receivingChannel)
    }

    func testSendingChannelIterationError() {
        let channel =  FallibleChannel<Int>(bufferSize: 2)
        channel <- Error()
        channel <- Error()
        func receive(channel: FallibleReceivingChannel<Int>) {
            channel.close()
            for result in channel {
                var error: ErrorType? = nil
                result.failure { e in
                    error = e
                }
                XCTAssert(error is Error)
            }
        }
        receive(channel.receivingChannel)
    }

    func testReceiveResult() {
        let channel = FallibleChannel<Int>(bufferSize: 1)
        co {
            channel.sendingChannel <- ChannelResult<Int>.Value(333)
        }
        XCTAssert(try! <-channel == 333)
    }

}

extension FallibleChannelTests {

    private func assertChannel<T: FallibleReceivable, E>(channel: T, catchesErrorOfType type: E.Type) {
        var thrown = false
        do {
            try !<-channel
        } catch _ as E {
            thrown = true
        } catch {}
        XCTAssert(thrown)
    }

}
