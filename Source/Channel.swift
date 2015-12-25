// Channel.swift
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

public struct ChannelGenerator<T>: GeneratorType {
    let channel: ReceivingChannel<T>

    public mutating func next() -> T? {
        return channel.receive()
    }
}

public final class Channel<T>: SequenceType, Sendable, Receivable {
    private let channel: chan
    public var closed: Bool = false
    private var buffer: [T] = []
    public let bufferSize: Int

    public convenience init() {
        self.init(bufferSize: 0)
    }

    public init(bufferSize: Int) {
        self.bufferSize = bufferSize
        self.channel = mill_chmake(bufferSize, "Channel init")
    }

    deinit {
        mill_chclose(channel, "Channel deinit")
    }

    /// Reference that can only send values.
    public lazy var sendingChannel: SendingChannel<T> = SendingChannel(self)

    /// Reference that can only receive values.
    public lazy var receivingChannel: ReceivingChannel<T> = ReceivingChannel(self)

    /// Creates a generator.
    public func generate() -> ChannelGenerator<T> {
        return ChannelGenerator(channel: receivingChannel)
    }

    /// Closes the channel. When a channel is closed it cannot receive values anymore.
    public func close() {
        if !closed {
            closed = true
            mill_chdone(channel, "Channel close")
        }
    }

    /// Send a value to the channel.
    public func send(value: T) {
        if !closed {
            buffer.append(value)
            mill_chs(channel, "Channel send")
        }
    }

    /// Send a value from select.
    func send(value: T, clause: UnsafeMutablePointer<Void>, index: Int) {
        if !closed {
            buffer.append(value)
            mill_choose_out(clause, channel, Int32(index))
        }
    }

    /// Receives a value from the channel.
    public func receive() -> T? {
        if closed && buffer.count <= 0 {
            return nil
        }
        mill_chr(channel, "Channel receive")
        return getValueFromBuffer()
    }

    func registerReceive(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel, Int32(index))
    }
    
    func getValueFromBuffer() -> T? {
        if closed && buffer.count <= 0 {
            return nil
        }
        return buffer.removeFirst()
    }
}