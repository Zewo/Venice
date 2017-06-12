#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import XCTest
@testable import Venice

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

        coroutine1.cancel()
        coroutine2.cancel()
        coroutine3.cancel()
    }

    func testCoroutineOnCanceledCoroutine() throws {
        let coroutine = try Coroutine {
            try Coroutine.yield()
            XCTAssertThrowsError(try Coroutine(body: {}), error: VeniceError.canceledCoroutine)
        }

        coroutine.cancel()
    }

    func testThrowOnCoroutine() throws {
        let coroutine = try Coroutine {
            struct NiceError : Error, CustomStringConvertible {
                let description: String
            }

            throw NiceError(description: "NICE™")
        }

        coroutine.cancel()
    }

    func testYiedOnCanceledCoroutine() throws {
        let coroutine = try Coroutine {
            try Coroutine.yield()
            XCTAssertThrowsError(try Coroutine.yield(), error: VeniceError.canceledCoroutine)
        }

        coroutine.cancel()
    }

    func testWakeUp() throws {
        let deadline = 100.milliseconds.fromNow()
        try Coroutine.wakeUp(deadline)
        let difference = Deadline.now().value - deadline.value
        XCTAssert(difference > -100.milliseconds.value && difference < 100.milliseconds.value)
    }

    func testWakeUpOnCanceledCoroutine() throws {
        let coroutine = try Coroutine {
            XCTAssertThrowsError(
                try Coroutine.wakeUp(100.milliseconds.fromNow()),
                error: VeniceError.canceledCoroutine
            )
        }

        coroutine.cancel()
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

        group.cancel()
    }
    
    func testReadWriteFileDescriptor() throws {
        let deadline = 1.second.fromNow()
        let (socket1, socket2) = try createSocketPair()
        
        let socket1Buffer = UnsafeMutableRawBufferPointer.allocate(count: 1)
        let socket2Buffer = UnsafeMutableRawBufferPointer.allocate(count: 1)
        
        defer {
            socket1Buffer.deallocate()
            socket2Buffer.deallocate()
        }
        
        var read: UnsafeRawBufferPointer
        
        socket1Buffer[0] = 42
        socket2Buffer[0] = 0
        try socket1.write(UnsafeRawBufferPointer(socket1Buffer), deadline: deadline)
        read = try socket2.read(socket2Buffer, deadline: deadline)
        XCTAssertEqual(read[0], 42)
        XCTAssertEqual(socket1Buffer[0], 42)
        XCTAssertEqual(socket2Buffer[0], 42)
        
        socket1Buffer[0] = 0
        socket2Buffer[0] = 69
        try socket2.write(UnsafeRawBufferPointer(socket2Buffer), deadline: deadline)
        read = try socket1.read(socket1Buffer, deadline: deadline)
        XCTAssertEqual(read[0], 69)
        XCTAssertEqual(socket1Buffer[0], 69)
        XCTAssertEqual(socket2Buffer[0], 69)
    }

    func testInvalidFileDescriptor() throws {
        XCTAssertThrowsError(try FileDescriptor(-1), error: VeniceError.invalidFileDescriptor)
    }

    func testPollOnCanceledCoroutine() throws {
        let (socket1, _) = try createSocketPair()

        let coroutine = try Coroutine {
            XCTAssertThrowsError(
                try FileDescriptor.poll(socket1.handle, event: .read, deadline: .never),
                error: VeniceError.canceledCoroutine
            )
        }

        coroutine.cancel()
    }

    func testFileDescriptorBlockedInAnotherCoroutine() throws {
        let (socket1, _) = try createSocketPair()

        let coroutine1 = try Coroutine {
            XCTAssertThrowsError(
                try FileDescriptor.poll(socket1.handle, event: .read, deadline: .never),
                error: VeniceError.canceledCoroutine
            )
        }

        let coroutine2 = try Coroutine {
            XCTAssertThrowsError(
                try FileDescriptor.poll(socket1.handle, event: .read, deadline: .never),
                error: VeniceError.fileDescriptorBlockedInAnotherCoroutine
            )
        }

        coroutine1.cancel()
        coroutine2.cancel()
    }
    
    func testDetachFileDescriptor() throws {
        var sockets = [Int32](repeating: 0, count: 2)
        
        #if os(Linux)
            let result = socketpair(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0, &sockets)
        #else
            let result = socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets)
        #endif
        
        XCTAssert(result == 0)
        
        let fileDescriptor = try FileDescriptor(sockets[0])
        let socket = try fileDescriptor.detach()
        XCTAssertEqual(socket, sockets[0])
        XCTAssertEqual(fileDescriptor.handle, -1)
        
        XCTAssertThrowsError(
            try FileDescriptor.poll(fileDescriptor.handle, event: .read, deadline: .never),
            error: VeniceError.invalidFileDescriptor
        )
    }
    
    func testStandardStreams() {
        let input = FileDescriptor.standardInput
        let output = FileDescriptor.standardOutput
        let error = FileDescriptor.standardError
        
        XCTAssertEqual(try input.detach(), STDIN_FILENO)
        XCTAssertEqual(try output.detach(), STDOUT_FILENO)
        XCTAssertEqual(try error.detach(), STDERR_FILENO)
    }

    func testNormalTerminationHandler() {
        var stop = false
        let coroutine = try? Coroutine {
            while !stop {
                try? Coroutine.yield()
            }
        }
        coroutine?.terminationHandler = { (cancelled: Bool) in 
            XCTAssertEqual(cancelled, false, "Wrong cancellation behavior")
        }
        try? Coroutine.wakeUp(1.second.fromNow())
        stop = true
        try? Coroutine.wakeUp(1.second.fromNow())
    }

    func testCancelledTerminationHandler() {
        let coroutine = try? Coroutine {
            var stop = false
            while !stop {
                do {
                    try Coroutine.yield()
                } catch {
                    stop = true
                }
            }
        }
        coroutine?.terminationHandler = { (cancelled: Bool) in
            XCTAssertEqual(cancelled, true, "Wrong cancellation behavior")
        }
        try? Coroutine.wakeUp(1.second.fromNow())
        coroutine?.cancel()
        try? Coroutine.wakeUp(1.second.fromNow())
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
    return try (FileDescriptor(sockets[0]), FileDescriptor(sockets[1]))
}

extension CoroutineTests {
    public static var allTests: [(String, (CoroutineTests) -> () throws -> Void)] {
        return [
            ("testCoroutine", testCoroutine),
            ("testCoroutineOnCanceledCoroutine", testCoroutineOnCanceledCoroutine),
            ("testThrowOnCoroutine", testThrowOnCoroutine),
            ("testYiedOnCanceledCoroutine", testYiedOnCanceledCoroutine),
            ("testWakeUp", testWakeUp),
            ("testWakeUpOnCanceledCoroutine", testWakeUpOnCanceledCoroutine),
            ("testWakeUpWithChannels", testWakeUpWithChannels),
            ("testReadWriteFileDescriptor", testReadWriteFileDescriptor),
            ("testInvalidFileDescriptor", testInvalidFileDescriptor),
            ("testPollOnCanceledCoroutine", testPollOnCanceledCoroutine),
            ("testFileDescriptorBlockedInAnotherCoroutine", testFileDescriptorBlockedInAnotherCoroutine),
            ("testDetachFileDescriptor", testDetachFileDescriptor),
            ("testStandardStreams", testStandardStreams),
            ("testNormalTerminationHandler", testNormalTerminationHandler),
            ("testCancelledTerminationHandler", testCancelledTerminationHandler)
        ]
    }
}
