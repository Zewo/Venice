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

public enum TCPError: ErrorType {
    case Unknown(description: String)
    case ConnectionResetByPeer(description: String, data: [Int8])
    case NoBufferSpaceAvailabe(description: String, data: [Int8])
    case OperationTimedOut(description: String, data: [Int8])
    case ClosedSocket(description: String)

    static func lastErrorWithData(data: [Int8], bytesProcessed: Int, receive: Bool) -> TCPError {
        let description = String.fromCString(strerror(errno))!
        let d: [Int8]
        if receive {
            d = processedDataFromSource(data, bytesProcessed: bytesProcessed)
        } else {
            d = remainingDataFromSource(data, bytesProcessed: bytesProcessed)
        }
        switch errno {
        case ECONNRESET:
            return .ConnectionResetByPeer(description: description, data: d)
        case ENOBUFS:
            return .NoBufferSpaceAvailabe(description: description, data: d)
        case ETIMEDOUT:
            return .OperationTimedOut(description: description, data: d)
        default:
            return .Unknown(description: description)
        }
    }

    static var lastError: TCPError {
        let description = String.fromCString(strerror(errno))!
        // TODO: Switch on errno
        return .Unknown(description: description)
    }

    static var closedSocketError: TCPError {
        return TCPError.ClosedSocket(description: "Closed socket")
    }
}

extension TCPError: CustomStringConvertible {
    public var description: String {
        switch self {
        case Unknown(let description):
            return description
        case ConnectionResetByPeer(let description, _):
            return description
        case NoBufferSpaceAvailabe(let description, _):
            return description
        case OperationTimedOut(let description, _):
            return description
        case ClosedSocket(let description):
            return description
        }
    }
}