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
    private typealias Handle = Int32
    
    private enum ChannelResult<Type> {
        case value(Type)
        case error(Error)

        fileprivate func getValue() throws -> Type {
            switch self {
            case .value(let value):
                return value
            case .error(let error):
                throw error
            }
        }
    }
    
    private let handle: Handle
    private var buffer = List<ChannelResult<Type>>()

    /// Creates a channel
    ///
    /// - Warning:
    ///   A channel is a synchronization primitive, not a container.
    ///   It doesn't store any items.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceledCoroutine
    ///   Thrown when the operation is performed within a canceled coroutine.
    ///   #### VeniceError.outOfMemory
    ///   Thrown when the system doesn't have enough memory to create a new channel.
    public init() throws {
        let result = chmake(0)

        guard result != -1 else {
            switch errno {
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case ENOMEM:
                throw VeniceError.outOfMemory
            default:
                throw VeniceError.unexpectedError
            }
        }

        handle = result
    }
    
    deinit {
        hclose(handle)
    }
    
    /// Reference to the channel which can only send.
    public lazy var sending: Sending = Sending(self)
    
    /// Reference to the channel which can only receive.
    public lazy var receiving: Receiving = Receiving(self)

    /// Sends a value to the channel.
    public func send(_ value: Type, deadline: Deadline) throws {
        try send(.value(value), deadline: deadline)
    }

    /// Sends an error to the channel.
    public func send(_ error: Error, deadline: Deadline) throws {
        try send(.error(error), deadline: deadline)
    }

    private func send(_ channelResult: ChannelResult<Type>, deadline: Deadline) throws {
        let node = buffer.append(channelResult)
        let result = chsend(handle, nil, 0, deadline.value)

        guard result == 0 else {
            switch errno {
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case EPIPE:
                throw VeniceError.doneChannel
            case ETIMEDOUT:
                buffer.remove(node)
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }
    }

    /// Receives a value from channel.
    @discardableResult public func receive(deadline: Deadline) throws -> Type {
        let result = chrecv(handle, nil, 0, deadline.value)

        guard result == 0 else {
            switch errno {
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case EPIPE:
                throw VeniceError.doneChannel
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }

        return try buffer.removeFirst().getValue()
    }
    
    /// This function is used to inform the channel that no more `send` or `receive` should be
    /// performed on the channel.
    ///
    /// - Warning:
    /// After `done` is called on a channel, any attempts to `send` or `receive`
    /// will result in a `VeniceError.doneChannel` error.
    public func done() {
        hdone(handle, 0)
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
        private let channel: Channel<Type>
        
        fileprivate init(_ channel: Channel<Type>) {
            self.channel = channel
        }
        
        /// :nodoc:
        public func send(_ value: Type, deadline: Deadline) throws {
            try channel.send(value, deadline: deadline)
        }
        
        /// :nodoc:
        public func send(_ error: Error, deadline: Deadline) throws {
            try channel.send(error, deadline: deadline)
        }
        
        /// :nodoc:
        public func done() {
            channel.done()
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
        private let channel: Channel<Type>
        
        fileprivate init(_ channel: Channel<Type>) {
            self.channel = channel
        }
        
        /// :nodoc:
        @discardableResult public func receive(deadline: Deadline) throws -> Type {
            return try channel.receive(deadline: deadline)
        }
        
        /// :nodoc:
        public func done() {
            channel.done()
        }
    }
}

extension Channel where Type == Void {
    /// :nodoc:
    public func send(deadline: Deadline) throws {
        try send((), deadline: deadline)
    }
}

extension Channel.Sending where Type == Void {
    /// :nodoc:
    public func send(deadline: Deadline) throws {
        try send((), deadline: deadline)
    }
}

class Node<T> {
    var value: T
    var next: Node<T>?
    weak var previous: Node<T>?
    
    init(value: T) {
        self.value = value
    }
}

fileprivate class List<T> {
    private var head: Node<T>?
    private var tail: Node<T>?
    
    @discardableResult fileprivate func append(_ value: T) -> Node<T> {
        let newNode = Node(value: value)
        
        if let tailNode = tail {
            newNode.previous = tailNode
            tailNode.next = newNode
        } else {
            head = newNode
        }
        
        tail = newNode
        return newNode
    }
    
    @discardableResult fileprivate func remove(_ node: Node<T>) -> T {
        let prev = node.previous
        let next = node.next
        
        if let prev = prev {
            prev.next = next
        } else {
            head = next
        }
        
        next?.previous = prev
        
        if next == nil {
            tail = prev
        }
        
        node.previous = nil
        node.next = nil
        
        return node.value
    }
    
    @discardableResult fileprivate func removeFirst() throws -> T {
        guard let head = head else {
            throw VeniceError.unexpectedError
        }
        
        return remove(head)
    }
}
