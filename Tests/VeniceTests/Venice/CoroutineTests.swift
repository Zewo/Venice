#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import XCTest
import Venice

public class CoroutineTests : XCTestCase {    
    func testCoroutine() throws {
        var sum = 0

        func add(number: Int, count: Int) throws {
            for _ in 0 ..< count {
                sum += number
                try Coroutine.yield()
            }
        }

        let coroutine1 = try Coroutine {
            try add(number: 7, count: 3)
        }

        let coroutine2 = try Coroutine {
            try add(number: 11, count: 1)
        }

        let coroutine3 = try Coroutine {
            try add(number: 5, count: 2)
        }

        try Coroutine.wakeUp(100.milliseconds.fromNow())
        XCTAssertEqual(sum, 42)

        try coroutine1.close()
        try coroutine2.close()
        try coroutine3.close()
    }

    func testCoroutineOnCanceledCoroutine() throws {
        let coroutine = try Coroutine {
            try Coroutine.yield()
            XCTAssertThrowsError(try Coroutine(body: {}), error: VeniceError.canceled)
        }

        try coroutine.close()
    }

    func testThrowOnCoroutine() throws {
        let coroutine = try Coroutine {
            struct NiceError : Error, CustomStringConvertible {
                let description: String
            }

            throw NiceError(description: "NICE™")
        }

        try coroutine.close()
    }

    func testYiedOnCanceledCoroutine() throws {
        let coroutine = try Coroutine {
            try Coroutine.yield()
            XCTAssertThrowsError(try Coroutine.yield(), error: VeniceError.canceled)
        }

        try coroutine.close()
    }

//    func testWakeUp() throws {
//        let deadline = 100.milliseconds.fromNow()
//        try Coroutine.wakeUp(deadline)
//        let difference = Deadline.now().value - deadline.value
//        XCTAssert(difference > -100.milliseconds.value && difference < 100.milliseconds.value)
//    }

    func testWakeUpOnCanceledCoroutine() throws {
        let coroutine = try Coroutine {
            XCTAssertThrowsError(
                try Coroutine.wakeUp(100.milliseconds.fromNow()),
                error: VeniceError.canceled
            )
        }

        try coroutine.close()
    }

    func testWakeUpWithChannels() throws {
        let channel = try Channel<Int>()
        let group = Coroutine.Group()

        func send(_ value: Int, after delay: Duration) throws {
            try Coroutine.wakeUp(delay.fromNow())
            try channel.send(value, deadline: .never)
        }

        try group.addCoroutine(body: { try send(111, after: 30.milliseconds) })
        try group.addCoroutine(body: { try send(222, after: 40.milliseconds) })
        try group.addCoroutine(body: { try send(333, after: 10.milliseconds) })
        try group.addCoroutine(body: { try send(444, after: 20.milliseconds) })

        XCTAssert(try channel.receive(deadline: .never) == 333)
        XCTAssert(try channel.receive(deadline: .never) == 444)
        XCTAssert(try channel.receive(deadline: .never) == 111)
        XCTAssert(try channel.receive(deadline: .never) == 222)

        try group.close()
    }

    func testPollFileDescriptor() throws {
        let (socket1, socket2) = try createSocketPair()

        try socket1.poll(event: .write, deadline: 100.milliseconds.fromNow())
        try socket1.poll(event: .write, deadline: 100.milliseconds.fromNow())

        XCTAssertThrowsError(
            try socket1.poll(event: .read, deadline: 100.milliseconds.fromNow()),
            error: VeniceError.deadlineReached
        )

        var size = send(socket2.handle, "A", 1, 0)
        XCTAssert(size == 1)

        try socket1.poll(event: .write, deadline: 100.milliseconds.fromNow())
        try socket1.poll(event: .read, deadline: 100.milliseconds.fromNow())

        var character: Int8 = 0
        size = recv(socket1.handle, &character, 1, 0)

        XCTAssert(size == 1)
        XCTAssert(character == 65)
    }

    func testInvalidFileDescriptor() throws {
        let fd = FileDescriptor(handle: -1)

        XCTAssertThrowsError(
            try fd.setNonblocking(),
            error: VeniceError.invalidFileDescriptor
        )
    }

    func testPollOnCanceledCoroutine() throws {
        let (socket1, _) = try createSocketPair()

        let coroutine = try Coroutine {
            XCTAssertThrowsError(
                try socket1.poll(event: .read, deadline: .never),
                error: VeniceError.canceled
            )
        }

        try coroutine.close()
    }

    func testFileDescriptorBlockedInAnotherCoroutine() throws {
        let (socket1, _) = try createSocketPair()

        let coroutine1 = try Coroutine {
            XCTAssertThrowsError(
                try socket1.poll(event: .read, deadline: .never),
                error: VeniceError.canceled
            )
        }

        let coroutine2 = try Coroutine {
            XCTAssertThrowsError(
                try socket1.poll(event: .read, deadline: .never),
                error: VeniceError.fileDescriptorBlockedInAnotherCoroutine
            )
        }

        try coroutine1.close()
        try coroutine2.close()
    }

    func testCleanFileDescriptor() throws {
        let fileDescriptor = FileDescriptor(handle: STDIN_FILENO)
        fileDescriptor.clean()
    }
    
    func testDetachFileDescriptor() throws {
        var sockets = [Int32](repeating: 0, count: 2)
        
        #if os(Linux)
            let result = socketpair(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0, &sockets)
        #else
            let result = socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets)
        #endif
        
        XCTAssert(result == 0)
        
        let fileDescriptor = FileDescriptor(handle: sockets[0])
        let standardInput = fileDescriptor.detach()
        XCTAssertEqual(standardInput, sockets[0])
        XCTAssertEqual(fileDescriptor.handle, -1)
        
        XCTAssertThrowsError(
            try fileDescriptor.poll(event: .read, deadline: .never),
            error: VeniceError.invalidFileDescriptor
        )
    }
}

func createSocketPair() throws -> (FileDescriptor, FileDescriptor) {
    var sockets = [Int32](repeating: 0, count: 2)

    #if os(Linux)
        let result = socketpair(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0, &sockets)
    #else
        let result = socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets)
    #endif

    XCTAssert(result == 0)

    return try (FileDescriptor(handle: sockets[0]), FileDescriptor(handle: sockets[1]))
}

extension CoroutineTests {
    public static var allTests: [(String, (CoroutineTests) -> () throws -> Void)] {
        return [
            ("testCoroutine", testCoroutine),
            ("testCoroutineOnCanceledCoroutine", testCoroutineOnCanceledCoroutine),
            ("testThrowOnCoroutine", testThrowOnCoroutine),
            ("testYiedOnCanceledCoroutine", testYiedOnCanceledCoroutine),
//            ("testWakeUp", testWakeUp),
            ("testWakeUpOnCanceledCoroutine", testWakeUpOnCanceledCoroutine),
            ("testWakeUpWithChannels", testWakeUpWithChannels),
            ("testPollFileDescriptor", testPollFileDescriptor),
            ("testInvalidFileDescriptor", testInvalidFileDescriptor),
            ("testPollOnCanceledCoroutine", testPollOnCanceledCoroutine),
            ("testFileDescriptorBlockedInAnotherCoroutine", testFileDescriptorBlockedInAnotherCoroutine),
            ("testCleanFileDescriptor", testCleanFileDescriptor),
        ]
    }
}
