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

import Libmill

public protocol Sendable {
    typealias T
    func send() -> T?
}

class _SendableBoxBase<T> : Sendable {
    func send() -> T? { fatalError() }
}

class _SendableBox<R: Sendable> : _SendableBoxBase<R.T> {
    let base: R

    init(_ base: R) {
        self.base = base
    }

    override func send() -> R.T? {
        return base.send()
    }
}

public final class SendingChannel<T> : Sendable, SequenceType {
    private let box: _SendableBoxBase<T>

    init<R: Sendable where R.T == T>(_ base: R) {
        self.box = _SendableBox(base)
    }

    public func send() -> T? {
        return box.send()
    }

    public func generate() -> ChannelGenerator<T> {
        return ChannelGenerator(channel: self)
    }
}

public protocol Receivable {
    typealias T
    func receive(value: T)
}

class _ReceivableBoxBase<T> : Receivable {
    func receive(value: T) { fatalError() }
}

class _ReceivableBox<W: Receivable> : _ReceivableBoxBase<W.T> {
    let base: W

    init(_ base: W) {
        self.base = base
    }

    override func receive(value: W.T) {
        return base.receive(value)
    }
}

public final class ReceivingChannel<T> : Receivable {
    private let box: _ReceivableBoxBase<T>

    init<W: Receivable where W.T == T>(_ base: W) {
        self.box = _ReceivableBox(base)
    }

    public func receive(value: T) {
        return box.receive(value)
    }
}

public struct ChannelGenerator<T> : GeneratorType {
    let channel: SendingChannel<T>

    public mutating func next() -> T? {
        return channel.send()
    }
}

public final class Channel<T> : SequenceType, Sendable, Receivable {
    let channel: chan
    public let bufferSize: Int
    private var valuesInBuffer: Int = 0
    public var closed: Bool = false
    private var lastValue: T?

    public convenience init() {
        self.init(bufferSize: 0)
    }

    public init(bufferSize: Int) {
        self.channel = go_make_channel(strideof(T), bufferSize)
        self.bufferSize = bufferSize
    }

    deinit {
        go_free_channel(channel)
    }

    /// Reference that can only send values.
    public lazy var sendingChannel: SendingChannel<T> = SendingChannel(self)

    /// Reference that can only receive values.
    public lazy var receivingChannel: ReceivingChannel<T> = ReceivingChannel(self)

    /// Creates a generator.
    public func generate() -> ChannelGenerator<T> {
        return ChannelGenerator(channel: sendingChannel)
    }

    /// Closes the channel. When a channel is closed it cannot receive values anymore.
    public func close() {
        closed = true

        if var value = lastValue {
            go_close_channel(channel, &value, strideof(T))
        }
    }

    /// Receives a value.
    public func receive(var value: T) {
        lastValue = value
        go_send_to_channel(channel, &value, strideof(T))
        
        if bufferSize <= 0 || valuesInBuffer < bufferSize {
            valuesInBuffer++
        }
    }

    /// Sends a value.
    public func send() -> T? {
        if closed && valuesInBuffer <= 0 {
            return nil
        } else {
            let pointer = go_receive_from_channel(channel, strideof(T))
            valuesInBuffer--
            let value = UnsafeMutablePointer<T>(pointer).memory
            lastValue = value
            return value
        }
    }
}

infix operator <- {}

public func <-<W: Receivable>(channel: W, value: W.T) {
    channel.receive(value)
}

prefix operator <- {}

public prefix func <-<R: Sendable>(channel: R) -> R.T? {
    return channel.send()
}

public func fanIn<T>(channels: SendingChannel<T>...) -> SendingChannel<T> {
    let fanInChannel = Channel<T>()
    for channel in channels { go { for element in channel { fanInChannel <- element } } }
    return fanInChannel.sendingChannel
}