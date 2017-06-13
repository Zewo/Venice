#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

/// A file descriptor used to access a file or other input/output resource,
/// such as a pipe or network socket.
public final class FileDescriptor {
    /// File descriptor handle.
    public typealias Handle = Int32
    
    /// File descriptor handle.
    public private(set) var handle: Handle
    
    /// Standard input file descriptor
    public static var standardInput = try! FileDescriptor(STDIN_FILENO)
    
    /// Standard output file descriptor
    public static var standardOutput = try! FileDescriptor(STDOUT_FILENO)
    
    /// Standard error file descriptor
    public static var standardError = try! FileDescriptor(STDERR_FILENO)

    /// Creates a `FileDescriptor` from a file descriptor handle.
    ///
    /// - Warning:
    /// This operation will configure the file descriptor as non-blocking.
    ///
    /// - Parameters:
    ///   - fileDescriptor: Previously opened file descriptor.
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when the operation is performed on an invalid file descriptor.
    public init(_ handle: Handle) throws {
        let flags = fcntl(handle, F_GETFL, 0)
        guard flags != -1 else {
            throw VeniceError.invalidFileDescriptor
        }
        // Error checking here is unecessary. If the file descriptor is invalid,
        // it was caught by the previous statement.
        let _ = fcntl(handle, F_SETFL, flags | O_NONBLOCK)
        self.handle = handle
    }
    
    deinit {
        try? close()
    }
    
    /// Reads from the file descriptor.
    ///
    /// - Parameters:
    ///   - buffer: Buffer in which the data will be read to.
    ///   - deadline: `deadline` is a point in time when the operation should timeout.
    ///     Use the `.fromNow()` function to get the current point in time.
    ///     Use `.immediate` if the operation needs to be performed without blocking.
    ///     Use `.never` to allow the operation to block forever if needed.
    ///
    /// - Returns: Buffer containing the amount of bytes read.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.readFailed
    ///   Thrown when `read` operation fails.
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when `handle` is not an open file descriptor.
    public func read(
        _ buffer: UnsafeMutableRawBufferPointer,
        deadline: Deadline
    ) throws -> UnsafeRawBufferPointer {
        let handle = try getHandle()
        
        guard !buffer.isEmpty, let baseAddress = buffer.baseAddress else {
            return UnsafeRawBufferPointer(start: nil, count: 0)
        }
        
        loop: while true {
            #if os(Linux)
                let result = Glibc.read(handle, buffer.baseAddress, buffer.count)
            #else
                let result = Darwin.read(handle, buffer.baseAddress, buffer.count)
            #endif
            
            guard result != -1 else {
                switch errno {
                case EWOULDBLOCK, EAGAIN:
                    try FileDescriptor.poll(handle, event: .read, deadline: deadline)
                    continue loop
                default:
                    throw VeniceError.readFailed
                }
            }
        
            return UnsafeRawBufferPointer(start: baseAddress, count: result)
        }
    }
    
    /// Writes to the file descriptor.
    ///
    /// - Parameters:
    ///   - buffer: Buffer which will be written to the file descriptor.
    ///   - deadline: `deadline` is a point in time when the operation should timeout.
    ///     Use the `.fromNow()` function to get the current point in time.
    ///     Use `.immediate` if the operation needs to be performed without blocking.
    ///     Use `.never` to allow the operation to block forever if needed.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.writeFailed
    ///   Thrown when `write` operation fails.
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when `handle` is not an open file descriptor.
    public func write(_ buffer: UnsafeRawBufferPointer, deadline: Deadline) throws {
        let handle = try getHandle()
        var buffer = buffer

        loop: while !buffer.isEmpty {
            #if os(Linux)
                let result = Glibc.write(handle, buffer.baseAddress, buffer.count)
            #else
                let result = Darwin.write(handle, buffer.baseAddress, buffer.count)
            #endif
            
            guard result != -1 else {
                switch errno {
                case EWOULDBLOCK, EAGAIN:
                    try FileDescriptor.poll(handle, event: .write, deadline: deadline)
                    continue loop
                default:
                    throw VeniceError.writeFailed
                }
            }
            
            #if swift(>=3.2)
                buffer = UnsafeRawBufferPointer(rebasing: buffer.suffix(from: result))
            #else
                buffer = buffer.suffix(from: result)
            #endif
        }
    }
    
    /// Closes a file descriptor, so that it no longer refers to any
    /// file and may be reused.  Any record locks held on the
    /// file it was associated with, and owned by the process, are removed
    /// (regardless of the file descriptor that was used to obtain the lock).
    ///
    /// - Warning:
    /// If `handle` is the last file descriptor referring to the underlying open
    /// *file description*, the resources associated with the
    /// open file description are freed; if the file descriptor was the last
    /// reference to a file which has been removed using `unlink`, the file
    /// is deleted.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when `handle` is not an open file descriptor.
    public func close() throws {
        let handle = try detach()
        
        #if os(Linux)
            guard Glibc.close(handle) == 0 else {
                throw VeniceError.invalidFileDescriptor
            }
        #else
            guard Darwin.close(handle) == 0 else {
                throw VeniceError.invalidFileDescriptor
            }
        #endif
    }
    
    /// Detaches the underlying `handle`.
    /// After `detach` any operation on the `FileDescriptor` will throw an error.
    ///
    /// - Returns: The underlying file descriptor.
    @discardableResult public func detach() throws -> Handle {
        let handle = try getHandle()
        
        defer {
            self.handle = -1
        }
        
        FileDescriptor.clean(handle)
        return handle
    }
    
    private func getHandle() throws -> Handle {
        guard handle != -1 else {
            throw VeniceError.invalidFileDescriptor
        }
        
        return handle
    }
    
    /// Waits for the file descriptor to become either readable/writable
    /// or to get into an error state. Either case leads to a successful return
    /// from the function. To distinguish the two outcomes, follow up with a
    /// read/write operation on the file descriptor.
    ///
    /// - Parameters:
    ///   - event:
    ///     Use `.read` to wait for the file descriptor to become readable.
    ///     Use `.write` to wait for the file descriptor to become writable.
    ///   - deadline: `deadline` is a point in time when the operation should timeout.
    ///     Use the `.fromNow()` function to get the current point in time.
    ///     Use `.immediate` if the operation needs to be performed without blocking.
    ///     Use `.never` to allow the operation to block forever if needed.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when the operation is performed on an invalid file descriptor.
    ///   #### VeniceError.canceledCoroutine
    ///   Thrown when the operation is performed within a canceled coroutine.
    ///   #### VeniceError.fileDescriptorBlockedInAnotherCoroutine
    ///   Thrown when another coroutine is already blocked on `poll` with this file descriptor.
    ///   #### VeniceError.deadlineReached
    ///   Thrown when the operation reaches the deadline.
    public static func poll(_ handle: Handle, event: PollEvent, deadline: Deadline) throws {
        let result: Int32
        
        switch event {
        case .read:
            result = fdin(handle, deadline.value)
        case .write:
            result = fdout(handle, deadline.value)
        }
        
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidFileDescriptor
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case EBUSY:
                throw VeniceError.fileDescriptorBlockedInAnotherCoroutine
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
    
    /// Erases cached info about a file descriptor.
    ///
    /// This function drops any state that Venice associates with
    /// the file descriptor.
    ///
    /// - Warning:
    /// `clean` has to be called with file descriptors provided by
    /// third-party libraries, just before returning them back to
    /// their original owners. Otherwise the behavior is **undefined**.
    public static func clean(_ handle: Handle) {
        guard handle != -1 else {
            return
        }
        
        fdclean(handle)
    }
    
    /// Event used to poll file descriptors for reading or writing.
    public enum PollEvent {
        /// Event which represents when data is available
        /// to be read from the file descriptor
        case read
        /// Event which represents when writing to the file
        /// descriptor will not block
        case write
    }
}
