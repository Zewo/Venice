// TCPError.swift
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

import libmill

public final class TCPListeningSocket {
    let socket: tcpsock

    var port: Int {
        return Int(tcpport(self.socket))
    }

    public private(set) var closed = false

    public init(ip: IP, backlog: Int = 10) throws {
        self.socket = tcplisten(ip.address, Int32(backlog))

        if errno != 0 {
            let description = TCPError.lastSystemErrorDescription
            throw TCPError(description: description)
        }
    }

    public func accept(deadline: Deadline = NoDeadline) throws -> TCPClientSocket {
        if closed {
            throw TCPError(description: "Closed socket")
        }

        let socket = tcpaccept(self.socket, deadline)

        if errno != 0 {
            let description = TCPError.lastSystemErrorDescription
            throw TCPError(description: description)
        }

        return TCPClientSocket(socket: socket)
    }

    public func close() {
        self.closed = true
        tcpclose(self.socket)
    }
}

extension TCPListeningSocket {
    public func acceptClients(accepted: TCPClientSocket -> Void) throws {
        var sequentialErrorsCount = 0

        while !self.closed {
            do {
                let clientSocket = try self.accept()
                sequentialErrorsCount = 0
                co(accepted(clientSocket))
            } catch {
                ++sequentialErrorsCount
                if sequentialErrorsCount >= 10 {
                    throw error
                }
            }
        }
    }
}
