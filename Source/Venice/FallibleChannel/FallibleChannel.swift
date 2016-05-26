// FallibleChannel.swift
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

import CLibvenice

public struct FallibleChannelGenerator<T>: IteratorProtocol {
    internal let channel: FallibleReceivingChannel<T>

    public mutating func next() -> ChannelResult<T>? {
        return channel.receiveResult()
    }
}

public enum ChannelResult<T> {
    case value(T)
    case error(ErrorProtocol)

    public func success(_ closure: @noescape (T) -> Void) {
        switch self {
        case .value(let value): closure(value)
        default: break
        }
    }

    public func failure(_ closure: @noescape (ErrorProtocol) -> Void) {
        switch self {
        case .error(let error): closure(error)
        default: break
        }
    }
}

public final class FallibleChannel<T>: Sequence {
    private let channel: chan
    public var closed: Bool = false
    private var buffer: [ChannelResult<T>] = []
    public let  bufferSize: Int

    public convenience init() {
        self.init(bufferSize: 0)
    }

    public init(bufferSize: Int) {
        self.bufferSize = bufferSize
        self.channel = mill_chmake(bufferSize, "FallibleChannel init")
    }

    deinit {
        mill_chclose(channel, "FallibleChannel deinit")
    }

    /// Reference that can only send values.
    public lazy var sendingChannel: FallibleSendingChannel<T> = FallibleSendingChannel(self)

    /// Reference that can only receive values.
    public lazy var receivingChannel: FallibleReceivingChannel<T> = FallibleReceivingChannel(self)

    /// Creates a generator.
    public func makeIterator() -> FallibleChannelGenerator<T> {
        return FallibleChannelGenerator(channel: receivingChannel)
    }

    /// Closes the channel. When a channel is closed it cannot receive values anymore.
    public func close() {
        guard !closed else { return }

        closed = true
        mill_chdone(channel, "Channel close")
    }

    /// Send a result to the channel.
    public func send(_ result: ChannelResult<T>) {
        if !closed {
            buffer.append(result)
            mill_chs(channel, "FallibleChannel sendResult")
        }
    }

    /// Send a value to the channel.
    public func send(_ value: T) {
        if !closed {
            let result = ChannelResult<T>.value(value)
            buffer.append(result)
            mill_chs(channel, "FallibleChannel send")
        }
    }

    internal func send(_ value: T, clause: UnsafeMutablePointer<Void>, index: Int) {
        if !closed {
            let result = ChannelResult<T>.value(value)
            buffer.append(result)
            mill_choose_out(clause, channel, Int32(index))
        }
    }

    /// Send an error to the channel.
    public func send(_ error: ErrorProtocol) {
        if !closed {
            let result = ChannelResult<T>.error(error)
            buffer.append(result)
            mill_chs(channel, "FallibleChannel send")
        }
    }

    internal func send(_ error: ErrorProtocol, clause: UnsafeMutablePointer<Void>, index: Int) {
        if !closed {
            let result = ChannelResult<T>.error(error)
            buffer.append(result)
            mill_choose_out(clause, channel, Int32(index))
        }
    }

    /// Receive a value from channel.
    public func receive() throws -> T? {
        if closed && buffer.count <= 0 {
            return nil
        }
        mill_chr(channel, "FallibleChannel receive")
        if let value = getResultFromBuffer() {
            switch value {
            case .value(let v): return v
            case .error(let e): throw e
            }
        } else {
            return nil
        }
    }

    /// Receive a result from channel.
    public func receiveResult() -> ChannelResult<T>? {
        if closed && buffer.count <= 0 {
            return nil
        }
        mill_chr(channel, "FallibleChannel receiveResult")
        return getResultFromBuffer()
    }

    internal func registerReceive(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel, Int32(index))
    }

    internal func getResultFromBuffer() -> ChannelResult<T>? {
        if closed && buffer.count <= 0 {
            return nil
        }
        return buffer.removeFirst()
    }
}
