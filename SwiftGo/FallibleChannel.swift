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

import Libmill

public protocol FallibleSendable {
    typealias T
    func send() throws -> T?
}

class _FallibleSendableBoxBase<T> : FallibleSendable {
    func send() throws -> T? { fatalError() }
}

class _FallibleSendableBox<R: FallibleSendable> : _FallibleSendableBoxBase<R.T> {
    let base: R

    init(_ base: R) {
        self.base = base
    }

    override func send() throws -> R.T? {
        return try base.send()
    }
}

public final class FallibleSendingChannel<T> : FallibleSendable, SequenceType {
    private let box: _FallibleSendableBoxBase<T>

    init<R: FallibleSendable where R.T == T>(_ base: R) {
        self.box = _FallibleSendableBox(base)
    }

    public func send() throws -> T? {
        return try box.send()
    }

    public func generate() -> FallibleChannelGenerator<T> {
        return FallibleChannelGenerator(channel: self)
    }
}

public protocol FallibleReceivable {
    typealias T
    func receive(value: T)
    func receiveError(error: ErrorType)
}

class _FallibleReceivableBoxBase<T> : FallibleReceivable {
    func receive(value: T) { fatalError() }
    func receiveError(error: ErrorType) { fatalError() }
}

class _FallibleReceivableBox<W: FallibleReceivable> : _FallibleReceivableBoxBase<W.T> {
    let base: W

    init(_ base: W) {
        self.base = base
    }

    override func receive(value: W.T) {
        return base.receive(value)
    }

    override func receiveError(error: ErrorType) {
        return base.receiveError(error)
    }
}

public final class FallibleReceivingChannel<T> : FallibleReceivable {
    private let box: _FallibleReceivableBoxBase<T>

    init<W: FallibleReceivable where W.T == T>(_ base: W) {
        self.box = _FallibleReceivableBox(base)
    }

    public func receive(value: T) {
        return box.receive(value)
    }

    public func receiveError(error: ErrorType) {
        return box.receiveError(error)
    }
}

public struct FallibleChannelGenerator<T> : GeneratorType {
    let channel: FallibleSendingChannel<T>

    public mutating func next() -> T? {
        return (try? channel.send()) ?? nil
    }
}

enum ChannelValue<T> {
    case Value(T)
    case Error(ErrorType)
}

var fallibleChannelCounter: Int = 0

public final class FallibleChannel<T> : SequenceType, FallibleSendable, FallibleReceivable, Hashable {
    let channel: chan
    public let bufferSize: Int
    private var valuesInBuffer: Int = 0
    public var closed: Bool = false
    private var lastValue: ChannelValue<T>?
    public let hashValue: Int

    public convenience init() {
        self.init(bufferSize: 0)
    }

    public init(bufferSize: Int) {
        self.channel = go_make_channel(strideof(ChannelValue<T>), bufferSize)
        self.bufferSize = bufferSize
        self.hashValue = fallibleChannelCounter++
    }

    deinit {
        go_free_channel(channel)
    }

    /// Reference that can only send values.
    public lazy var sendingChannel: FallibleSendingChannel<T> = FallibleSendingChannel(self)

    /// Reference that can only receive values.
    public lazy var receivingChannel: FallibleReceivingChannel<T> = FallibleReceivingChannel(self)

    /// Creates a generator.
    public func generate() -> FallibleChannelGenerator<T> {
        return FallibleChannelGenerator(channel: sendingChannel)
    }

    /// Closes the channel. When a channel is closed it cannot receive values anymore.
    public func close() {
        closed = true

        if var value = lastValue {
            go_close_channel(channel, &value, strideof(ChannelValue<T>))
        }
    }

    /// Receives a value.
    public func receive(value: T) {
        lastValue = ChannelValue.Value(value)
        go_send_to_channel(channel, &lastValue, strideof(ChannelValue<T>))
        
        if bufferSize <= 0 || valuesInBuffer < bufferSize {
            valuesInBuffer++
        }
    }

    /// Receives an error.
    public func receiveError(error: ErrorType) {
        lastValue = ChannelValue.Error(error)
        go_send_to_channel(channel, &lastValue, strideof(ChannelValue<T>))

        if bufferSize <= 0 || valuesInBuffer < bufferSize {
            valuesInBuffer++
        }
    }

    /// Sends a value.
    public func send() throws -> T? {
        if closed && valuesInBuffer <= 0 {
            return nil
        } else {
            let pointer = go_receive_from_channel(channel, strideof(ChannelValue<T>))
            valuesInBuffer--
            let value = UnsafeMutablePointer<ChannelValue<T>>(pointer).memory
            lastValue = value
            switch lastValue! {
            case .Value(let value): return value
            case .Error(let error): throw error
            }
        }
    }
}

public func ==<T>(lhs: FallibleChannel<T>, rhs: FallibleChannel<T>) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

public func <-<W: FallibleReceivable>(channel: W, value: W.T) {
    channel.receive(value)
}

public func <-<W: FallibleReceivable>(channel: W?, value: W.T) {
    channel?.receive(value)
}

public func <-<W: FallibleReceivable>(channel: W, error: ErrorType) {
    channel.receiveError(error)
}

public prefix func <-<R: FallibleSendable>(channel: R) throws -> R.T? {
    return try channel.send()
}

public prefix func !<-<R: FallibleSendable>(channel: R) throws -> R.T! {
    return try channel.send()!
}

func fanIn<T>(channels: FallibleSendingChannel<T>...) -> FallibleSendingChannel<T> {
    let fanInChannel = FallibleChannel<T>()
    for channel in channels { go { for element in channel { fanInChannel <- element } } }
    return fanInChannel.sendingChannel
}