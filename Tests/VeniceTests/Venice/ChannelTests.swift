import XCTest
import Venice

struct Fou {
    let bar: Int
    let baz: Int
}

public class ChannelTests : XCTestCase {
    func testSendOnCloseChannel() throws {
        let channel = Channel<Void>()
        channel.close()

        XCTAssertThrowsError({ try channel.send(deadline: .never) }, error: VeniceError.closedChannel)
    }

    func testSendTimeout() throws {
        let channel = Channel<Int>()

        XCTAssertThrowsError({ try channel.send(111, deadline: .immediately) }, error: VeniceError.deadlineReached)

        Coroutine.run {
            do {
                try channel.send(222, deadline: .never)
            } catch {
                XCTFail("\(error)")
            }
        }

        XCTAssertEqual(try channel.receive(deadline: .never), 222)
    }

    func testDoubleSendTimeout() throws {
        let channel = Channel<Int>()

        Coroutine.run {
            XCTAssertThrowsError(
                { try channel.send(111, deadline: 50.milliseconds.fromNow()) },
                error: VeniceError.deadlineReached
            )
        }

        Coroutine.run {
            XCTAssertThrowsError(
                { try channel.send(222, deadline: 50.milliseconds.fromNow()) },
                error: VeniceError.deadlineReached
            )
        }

        Coroutine.wakeUp(at: 100.milliseconds.fromNow())

        Coroutine.run {
            XCTAssertThrowsNoError({ try channel.send(333, deadline: .never) })
        }



        print("will receive")
        XCTAssertEqual(try channel.receive(deadline: .never), 333)
        print("did receive")
    }

    func testReceiveOnCloseChannel() throws {
        let channel = Channel<Void>()
        channel.close()
        XCTAssertThrowsError({ try channel.receive(deadline: .never) }, error: VeniceError.closedChannel)
    }

    func testReceiveTimeout() throws {
        let channel = Channel<Int>()

        XCTAssertThrowsError(
            { try channel.receive(deadline: .immediately) },
            error: VeniceError.deadlineReached
        )

        Coroutine.run {
            XCTAssertEqual(try? channel.receive(deadline: .never), 222)
        }

        try channel.send(222, deadline: .never)
    }

    func testReceiverWaitsForSender() throws {
        let channel = Channel<Int>()

        Coroutine.run {
            XCTAssertEqual(try? channel.receive(deadline: .never), 333)
        }

        try channel.send(333, deadline: .never)
    }

    func testSenderWaitsForReceiver() throws {
        let channel = Channel<Int>()

        Coroutine.run {
            XCTAssertThrowsNoError({ try channel.send(444, deadline: .never) })
        }

        XCTAssertEqual(try channel.receive(deadline: .never), 444)
    }

    func testSendingChannel() throws {
        let channel = Channel<Int>()

        func send(to channel: Channel<Int>.Sending) throws {
            try channel.send(111, deadline: .never)
        }

        Coroutine.run {
            XCTAssertThrowsNoError({ try send(to: channel.sending) })
        }

        XCTAssertEqual(try channel.receive(deadline: .never), 111)
    }

    func testSendErrorToSendingChannel() throws {
        let channel = Channel<Int>()

        func send(to channel: Channel<Int>.Sending) throws {
            try channel.send(VeniceError.unexpectedError, deadline: .never)
        }

        Coroutine.run {
            XCTAssertThrowsNoError({ try send(to: channel.sending) })
        }

        XCTAssertThrowsError({ try channel.receive(deadline: .never) }, error: VeniceError.unexpectedError)
    }

    func testCloseOnClosedSendingChannel() throws {
        let channel = Channel<Void>()
        let sending = channel.sending
        channel.close()
        sending.close()
    }

    func testReceivingChannel() throws {
        let channel = Channel<Int>()

        func receive(_ channel: Channel<Int>.Receiving) {
            XCTAssertEqual(try channel.receive(deadline: .never), 999)
        }

        Coroutine.run {
            XCTAssertThrowsNoError({ try channel.send(999, deadline: .never) })
        }

        receive(channel.receiving)
    }

    func testCloseOnClosedReceivingChannel() throws {
        let channel = Channel<Void>()
        let receiving = channel.receiving
        channel.close()
        receiving.close()
    }

    func testTwoSimultaneousSenders() throws {
        let channel = Channel<Int>()

        Coroutine.run {
            XCTAssertThrowsNoError({ try channel.send(888, deadline: .never) })
        }

        Coroutine.run {
            XCTAssertThrowsNoError({ try channel.send(999, deadline: .never) })
        }

        XCTAssertEqual(try channel.receive(deadline: .never), 888)
        XCTAssertEqual(try channel.receive(deadline: .never), 999)
    }

    func testTwoSimultaneousReceivers() throws {
        let channel = Channel<Int>()

        Coroutine.run {
            XCTAssertEqual(try? channel.receive(deadline: .never), 333)
        }

        Coroutine.run {
            XCTAssertEqual(try? channel.receive(deadline: .never), 444)
        }

        try channel.send(333, deadline: .never)
        try channel.send(444, deadline: .never)
    }

    func testTypedChannels() throws {
        let stringChannel = Channel<String>()

        Coroutine.run {
            XCTAssertThrowsNoError({ try stringChannel.send("yo", deadline: .never) })
        }

        XCTAssertEqual(try stringChannel.receive(deadline: .never), "yo")

        let fooChannel = Channel<Fou>()

        Coroutine.run {
            XCTAssertThrowsNoError({ try fooChannel.send(Fou(bar: 555, baz: 222), deadline: .never) })
        }

        let foo = try fooChannel.receive(deadline: .never)
        XCTAssertEqual(foo.bar, 555)
        XCTAssertEqual(foo.baz, 222)
    }

    func testCloseChannelUnblocks() throws {
        let channel1 = Channel<Int>()
        let channel2 = Channel<Int>()

        Coroutine.run {
            XCTAssertThrowsError(
                { try channel1.receive(deadline: .never) },
                error: VeniceError.closedChannel
            )

            XCTAssertThrowsNoError({ try channel2.send(0, deadline: .never) })
        }

        Coroutine.run {
            XCTAssertThrowsError(
                { try channel1.receive(deadline: .never) },
                error: VeniceError.closedChannel
            )

            XCTAssertThrowsNoError({ try channel2.send(0, deadline: .never) })
        }

        channel1.close()

        XCTAssertEqual(try channel2.receive(deadline: .never), 0)
        XCTAssertEqual(try channel2.receive(deadline: .never), 0)
    }

    func testOneThousandWhispers() throws {
        self.measure {
            let numberOfWhispers = 1_000
            let deadline = Deadline.never

            let leftmost = Channel<Int>()

            var right = leftmost
            var left = leftmost

            for _ in 0 ..< numberOfWhispers {
                right = Channel<Int>()

                Coroutine.run { [l = left, r = right] in
                    do {
                        try l.send(r.receive(deadline: deadline) + 1, deadline: deadline)
                    } catch {
                        XCTFail("Expected no error, got: \(error)")
                    }
                }

                left = right
            }

            Coroutine.run {
                XCTAssertThrowsNoError({ try right.send(1, deadline: deadline) })
            }

            XCTAssertThrowsNoError({ XCTAssertEqual(try leftmost.receive(deadline: deadline), numberOfWhispers + 1) })
        }
    }
}

extension ChannelTests {
    public static var allTests: [(String, (ChannelTests) -> () throws -> Void)] {
        return [
            ("testSendOnCloseChannel", testSendOnCloseChannel),
            ("testSendTimeout", testSendTimeout),
            ("testReceiveOnCloseChannel", testReceiveOnCloseChannel),
            ("testReceiveTimeout", testReceiveTimeout),
            ("testReceiverWaitsForSender", testReceiverWaitsForSender),
            ("testSenderWaitsForReceiver", testSenderWaitsForReceiver),
            ("testSendingChannel", testSendingChannel),
            ("testCloseOnClosedSendingChannel", testCloseOnClosedSendingChannel),
            ("testReceivingChannel", testReceivingChannel),
            ("testTwoSimultaneousSenders", testTwoSimultaneousSenders),
            ("testTwoSimultaneousReceivers", testTwoSimultaneousReceivers),
            ("testTypedChannels", testTypedChannels),
            ("testCloseChannelUnblocks", testCloseChannelUnblocks),
            ("testOneThousandWhispers", testOneThousandWhispers),
        ]
    }
}
