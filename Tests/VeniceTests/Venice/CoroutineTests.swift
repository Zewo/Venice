#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import XCTest
@testable import Venice
import CLibdill

public class CoroutineTests : XCTestCase {
    func testCoroutine() throws {
        var sum = 0

        func add(number: Int, count: Int) {
            for _ in 0 ..< count {
                sum += number
                Coroutine.yield()
            }
        }

        Coroutine.run {
            add(number: 7, count: 3)
        }

        Coroutine.run {
            add(number: 11, count: 1)
        }

        Coroutine.run {
            add(number: 5, count: 2)
        }

        Coroutine.wakeUp(at: 100.milliseconds.fromNow())
        XCTAssertEqual(sum, 42)
    }

    func testWakeUp() throws {
        let deadline = 100.milliseconds.fromNow()
        Coroutine.wakeUp(at: deadline)
        let difference = Deadline.now().value - deadline.value
        XCTAssert(difference > -100.milliseconds.value && difference < 100.milliseconds.value)
    }

    func testWakeUpWithChannels() throws {
        let channel = Channel<Int>()

        func send(_ value: Int, after delay: Duration) throws {
            Coroutine.wakeUp(at: delay.fromNow())
            try channel.send(value, deadline: .never)
        }

        let runs = [(111, 30), (222, 40), (333, 10), (444, 20)]
        for run in runs {
            Coroutine.run {
                XCTAssertThrowsNoError({ try send(run.0, after: run.1.milliseconds) })
            }
        }

        XCTAssert(try channel.receive(deadline: .never) == 333)
        XCTAssert(try channel.receive(deadline: .never) == 444)
        XCTAssert(try channel.receive(deadline: .never) == 111)
        XCTAssert(try channel.receive(deadline: .never) == 222)
    }

    func testSleep() throws {
        let duration = 100.milliseconds
        let expected = duration.fromNow()
        Coroutine.sleep(for: duration)
        let difference = Deadline.now().value - expected.value

        XCTAssert(difference > -100 && difference < 100)
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
        XCTAssertThrowsError({ try FileDescriptor(-1) }, error: VeniceError.invalidFileDescriptor)
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
            { try FileDescriptor.poll(fileDescriptor.handle, event: .read, deadline: .never) },
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

    func testReadUsingEmptyBuffer() throws {
        let socketPair = try createSocketPair()
        let buf = UnsafeMutableRawBufferPointer.allocate(count: 0)
        let ret = try socketPair.0.read(buf, deadline: 1.second.fromNow())
        XCTAssert(ret.isEmpty)
    }

    func testReadFromEmptyFildes() throws {
        let socketPair = try createSocketPair()
        let buf = UnsafeMutableRawBufferPointer.allocate(count: Int(BUFSIZ))
        XCTAssertThrowsError(
            { try socketPair.0.read(buf, deadline: 1.second.fromNow()) },
            error: VeniceError.deadlineReached
        )
    }

    func testCleanInvalidHandle() {
        FileDescriptor.clean(-1)
    }

    func testInvalidWrite() {
        let handle = open("/dev/null", O_RDONLY)
        let fildes = try! FileDescriptor(handle)
        let mutableBuf = UnsafeMutableRawBufferPointer.allocate(count: 1)
        mutableBuf[0] = 42
        let buf = UnsafeRawBufferPointer(mutableBuf)
        XCTAssertThrowsError(
            { try fildes.write(buf, deadline: 1.second.fromNow()) },
            error: VeniceError.writeFailed
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
    return try (FileDescriptor(sockets[0]), FileDescriptor(sockets[1]))
}

extension CoroutineTests {
    public static var allTests: [(String, (CoroutineTests) -> () throws -> Void)] {
        return [
            ("testCoroutine", testCoroutine),
            ("testWakeUp", testWakeUp),
            ("testWakeUpWithChannels", testWakeUpWithChannels),
            ("testReadWriteFileDescriptor", testReadWriteFileDescriptor),
            ("testInvalidFileDescriptor", testInvalidFileDescriptor),
            ("testDetachFileDescriptor", testDetachFileDescriptor),
            ("testStandardStreams", testStandardStreams),
            ("testReadUsingEmptyBuffer", testReadUsingEmptyBuffer),
            ("testReadFromEmptyFildes", testReadFromEmptyFildes),
            ("testCleanInvalidHandle", testCleanInvalidHandle),
            ("testInvalidWrite", testInvalidWrite)
        ]
    }
}
