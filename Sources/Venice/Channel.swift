#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

/// A channel is a synchronization primitive.
///
/// ## Example:
///
/// ```swift
/// let channel = Channel<Int>()
///
/// let coroutine = try Coroutine {
///     try channel.send(42, deadline: 1.second.fromNow())
/// }
///
/// let theAnswer = try channel.receive(deadline: 1.second.fromNow())
/// ```

public final class Channel<Type> {
    private let handle: Int32

    /// Creates a channel
    ///
    /// - Warning:
    ///   A channel is a synchronization primitive, not a container.
    ///   It doesn't store any items.
    public init() {
        let result = chmake(MemoryLayout<UnsafeMutableRawPointer>.size)

        guard result != -1 else {
            switch errno {
            case ENOMEM:
                fatalError("Out of memory while creating channel.")
            default:
                fatalError("Unexpected error \(errno) while creating channel.")
            }
        }

        self.handle = result
    }

    deinit {
        hclose(self.handle)
    }
    
    /// Reference to the channel which can only send.
    public lazy var sending: Sending = Sending(self)
    
    /// Reference to the channel which can only receive.
    public lazy var receiving: Receiving = Receiving(self)
    
    /// Whether or not this channel is closed
    public private(set) var isClosed: Bool = false

    /// Sends a value to the channel.
    public func send(_ value: Type, deadline: Deadline) throws {
        try self.send(.value(value), deadline: deadline)
    }

    /// Sends an error to the channel.
    public func send(_ error: Error, deadline: Deadline) throws {
        try self.send(.error(error), deadline: deadline)
    }

    private func send(_ value: Result<Type>, deadline: Deadline) throws {
        guard !self.isClosed else {
            throw VeniceError.closedChannel
        }

        let boxed = Box(value)
        var pointer = Unmanaged.passRetained(boxed).toOpaque()
        let result = chsend(self.handle, &pointer, MemoryLayout<UnsafeMutableRawPointer>.size, deadline.value)

        guard result == 0 else {
            _ = Unmanaged<Box<Result<Type>>>.fromOpaque(pointer).release()
            switch errno {
            case EPIPE:
                throw VeniceError.closedChannel
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }
    }

    /// Receives a value from channel.
    @discardableResult public func receive(deadline: Deadline) throws -> Type {
        guard !self.isClosed else {
            throw VeniceError.closedChannel
        }

        var pointer: UnsafeMutableRawPointer? = nil

        let result = chrecv(self.handle, &pointer, MemoryLayout<UnsafeMutableRawPointer>.size, deadline.value)

        guard result == 0 else {
            switch errno {
            case EPIPE:
                throw VeniceError.closedChannel
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }

        let boxed = Unmanaged<Box<Result<Type>>>.fromOpaque(pointer!).takeRetainedValue()

        return try boxed.value.dematerialize()
    }
    
    /// This function is used to inform the channel that no more `send` or `receive` should be
    /// performed on the channel.
    ///
    /// - Warning:
    /// After `close` is called on a channel, any attempts to `send` or `receive`
    /// will result in a `VeniceError.closedChannel` error.
    public func close() {
        guard !self.isClosed else {
            return
        }
        self.isClosed = true
        hdone(self.handle, 0)
    }
    
    /// Send-only reference to an existing channel.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// let channel = Channel<Int>()
    ///
    /// func send(to channel: Channel<Int>.Sending) throws {
    ///     try channel.send(42, deadline: 1.second.fromNow())
    /// }
    ///
    /// try send(to: channel.sending)
    /// ```
    public final class Sending {
        fileprivate let channel: Channel<Type>

        public var isClosed: Bool {
            return self.channel.isClosed
        }
        
        fileprivate init(_ channel: Channel<Type>) {
            self.channel = channel
        }
        
        /// :nodoc:
        public func send(_ value: Type, deadline: Deadline) throws {
            try self.channel.send(value, deadline: deadline)
        }
        
        /// :nodoc:
        public func send(_ error: Error, deadline: Deadline) throws {
            try self.channel.send(error, deadline: deadline)
        }
        
        /// :nodoc:
        public func close() {
            self.channel.close()
        }
    }
    
    /// Receive-only reference to an existing channel.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// let channel = Channel<Int>()
    ///
    /// func receive(from channel: Channel<Int>.Receiving) throws {
    ///     let value = try channel.receive(deadline: 1.second.fromNow())
    /// }
    ///
    /// try receive(from: channel.receiving)
    /// ```
    public final class Receiving {
        fileprivate let channel: Channel<Type>

        public var isClosed: Bool {
            return self.channel.isClosed
        }
        
        fileprivate init(_ channel: Channel<Type>) {
            self.channel = channel
        }
        
        /// :nodoc:
        @discardableResult public func receive(deadline: Deadline) throws -> Type {
            return try self.channel.receive(deadline: deadline)
        }
        
        /// :nodoc:
        public func close() {
            self.channel.close()
        }
    }
}

extension Channel where Type == Void {
    /// :nodoc:
    public func send(deadline: Deadline) throws {
        try self.send((), deadline: deadline)
    }
}

extension Channel.Sending where Type == Void {
    /// :nodoc:
    public func send(deadline: Deadline) throws {
        try self.send((), deadline: deadline)
    }
}

fileprivate class Box<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

fileprivate enum Result<Type> {
    case value(Type)
    case error(Error)

    public func dematerialize() throws -> Type {
        switch self {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }
}

