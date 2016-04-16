// FallibleReceivingChannel.swift
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

public final class FallibleReceivingChannel<T>: Sequence {
    private let channel: FallibleChannel<T>

    internal init(_ channel: FallibleChannel<T>) {
        self.channel = channel
    }

    public func receive() throws -> T? {
        return try channel.receive()
    }

    public func receiveResult() -> ChannelResult<T>? {
        return channel.receiveResult()
    }

    public func makeIterator() -> FallibleChannelGenerator<T> {
        return FallibleChannelGenerator(channel: self)
    }

    public func close() {
        channel.close()
    }

    internal func registerReceive(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        return channel.registerReceive(clause, index: index)
    }

    internal func getResultFromBuffer() -> ChannelResult<T>? {
        return channel.getResultFromBuffer()
    }
}
