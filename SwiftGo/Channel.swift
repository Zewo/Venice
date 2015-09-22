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

public struct ChannelGenerator<T> : GeneratorType {
    let channel: SendingChannel<T>

    public mutating func next() -> T? {
        return channel.send()
    }
}

public final class Channel<T> : SequenceType, Sendable, Receivable {
    let channel: chan
    public let bufferSize: Int
    var valuesInBuffer: Int = 0
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
        if closed {
            go_panic("close of closed channel")
        }
        
        closed = true

        if var value = lastValue {
            go_close_channel(channel, &value, strideof(T))
        }
    }

    /// Receives a value.
    public func receive(var value: T) {
        if closed {
            go_panic("send on closed channel")
        }
        lastValue = value
        go_send_to_channel(channel, &value, strideof(T))

        if bufferSize <= 0 || valuesInBuffer < bufferSize {
            valuesInBuffer++
        }
    }

    /// Sends a value.
    public func send() -> T? {
        let pointer = go_receive_from_channel(channel, strideof(T))
        return valueFromPointer(pointer)
    }
    
    func valueFromPointer(pointer: UnsafeMutablePointer<Void>) -> T? {
        if closed && valuesInBuffer <= 0 {
            return nil
        } else {
            valuesInBuffer--
            let value = UnsafeMutablePointer<T>(pointer).memory
            lastValue = value
            return value
        }
    }
}

public func fanIn<T>(channels: Channel<T>...) -> SendingChannel<T> {
    let fanInChannel = Channel<T>()
    for channel in channels { go { for element in channel { fanInChannel <- element } } }
    return fanInChannel.sendingChannel
}