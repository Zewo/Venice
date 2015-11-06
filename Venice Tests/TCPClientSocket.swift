// TCPClientSocketTests.swift
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

class TCPClientSocketTests: XCTestCase {

    func testConnectionRefused() {
        var called = false

        do {
            let ip = try IP(address: "127.0.0.1", port: 5555)
            let _ = try TCPClientSocket(ip: ip)
            XCTAssert(false)
        } catch {
            called = true
        }

        XCTAssert(called)
    }

    func testInitWithFileDescriptor() {
        var called = false

        do {
            let _ = try TCPClientSocket(fileDescriptor: 0)
            called = true
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

    func testSendClosedSocket() {
        var called = false

        func client(port: Int) {
            do {
                let ip = try IP(address: "127.0.0.1", port: port)
                let clientSocket = try TCPClientSocket(ip: ip)
                clientSocket.close()
                try clientSocket.send([])
                XCTAssert(false)
            } catch {
                called = true
            }
        }

        do {
            let port = 5555
            let ip = try IP(port: port)
            let serverSocket = try TCPServerSocket(ip: ip)
            co(client(port))
            try serverSocket.accept()
            nap(1 * millisecond)
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

    func testFlushClosedSocket() {
        var called = false

        func client(port: Int) {
            do {
                let ip = try IP(address: "127.0.0.1", port: port)
                let clientSocket = try TCPClientSocket(ip: ip)
                clientSocket.close()
                try clientSocket.flush()
                XCTAssert(false)
            } catch {
                called = true
            }
        }

        do {
            let port = 5555
            let ip = try IP(port: port)
            let serverSocket = try TCPServerSocket(ip: ip)
            co(client(port))
            try serverSocket.accept()
            nap(1 * millisecond)
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

    func testReceiveClosedSocket() {
        var called = false

        func client(port: Int) {
            do {
                let ip = try IP(address: "127.0.0.1", port: port)
                let clientSocket = try TCPClientSocket(ip: ip)
                clientSocket.close()
                try clientSocket.receive()
                XCTAssert(false)
            } catch {
                called = true
            }
        }

        do {
            let port = 5555
            let ip = try IP(port: port)
            let serverSocket = try TCPServerSocket(ip: ip)
            co(client(port))
            try serverSocket.accept()
            nap(1 * millisecond)
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

    func testReceiveUntilClosedSocket() {
        var called = false

        func client(port: Int) {
            do {
                let ip = try IP(address: "127.0.0.1", port: port)
                let clientSocket = try TCPClientSocket(ip: ip)
                clientSocket.close()
                try clientSocket.receive(untilDelimiter: "")
                XCTAssert(false)
            } catch {
                called = true
            }
        }

        do {
            let port = 5555
            let ip = try IP(port: port)
            let serverSocket = try TCPServerSocket(ip: ip)
            co(client(port))
            try serverSocket.accept()
            nap(1 * millisecond)
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

    func testDetachClosedSocket() {
        var called = false

        func client(port: Int) {
            do {
                let ip = try IP(address: "127.0.0.1", port: port)
                let clientSocket = try TCPClientSocket(ip: ip)
                clientSocket.close()
                try clientSocket.detach()
                XCTAssert(false)
            } catch {
                called = true
            }
        }

        do {
            let port = 5555
            let ip = try IP(port: port)
            let serverSocket = try TCPServerSocket(ip: ip)
            co(client(port))
            try serverSocket.accept()
            nap(1 * millisecond)
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

    func testSendReceive() {
        var called = false

        func client(port: Int) {
            do {
                let ip = try IP(address: "127.0.0.1", port: port)
                let clientSocket = try TCPClientSocket(ip: ip)
                try clientSocket.send([123])
                try clientSocket.flush()
            } catch {
                XCTAssert(false)
            }
        }

        do {
            let port = 5555
            let ip = try IP(port: port)
            let serverSocket = try TCPServerSocket(ip: ip)
            co(client(port))
            let clientSocket = try serverSocket.accept()
            try clientSocket.receive(bufferSize: 1) { data in
                called = true
                XCTAssert(data == [123])
                clientSocket.close()
            }
        } catch {
            XCTAssert(false)
        }

        XCTAssert(called)
    }

}
