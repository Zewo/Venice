#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

/// A handle used to access a file or other input/output resource,
/// such as a pipe or network socket.
public final class FileDescriptor {
    /// File descriptor handle.
    public private(set) var fileDescriptor: Int32
    
    /// Creates a `FileDescriptor` from a file descriptor handle and
    /// configures it as non-blocking.
    ///
    /// - Parameters:
    ///   - fileDescriptor: Previously opened file descriptor.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when `fileDescriptor` is not an open file descriptor.
    public init(_ fileDescriptor: Int32) throws {
        let flags = fcntl(fileDescriptor, F_GETFL, 0)
        
        guard flags != -1 else {
            throw VeniceError.invalidFileDescriptor
        }
        
        guard fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw VeniceError.invalidFileDescriptor
        }
        
        self.fileDescriptor = fileDescriptor
    }
    
    deinit {
        try? close()
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
    ///   #### VeniceError.canceled
    ///   Thrown when the operation is performed within a closed coroutine.
    ///   #### VeniceError.fileDescriptorBlockedInAnotherCoroutine
    ///   Thrown when another coroutine is already blocked on `poll` with this file descriptor.
    ///   #### VeniceError.deadlineReached
    ///   Thrown when the operation reaches the deadline.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    public func poll(event: PollEvent, deadline: Deadline) throws {
        let result: Int32
        
        switch event {
        case .read:
            result = fdin(fileDescriptor, deadline.value)
        case .write:
            result = fdout(fileDescriptor, deadline.value)
        }
        
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidFileDescriptor
            case ECANCELED:
                throw VeniceError.canceled
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
    public func clean() {
        guard fileDescriptor != -1 else {
            return
        }
        
        fdclean(fileDescriptor)
    }
    
    /// Closes a file descriptor, so that it no longer refers to any
    /// file and may be reused.  Any record locks held on the
    /// file it was associated with, and owned by the process, are removed
    /// (regardless of the file descriptor that was used to obtain the lock).
    ///
    /// - Warning:
    /// If `fileDescriptor` is the last file descriptor referring to the underlying open
    /// file description, the resources associated with the
    /// open file description are freed; if the file descriptor was the last
    /// reference to a file which has been removed using `unlink`, the file
    /// is deleted.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when `fileDescriptor` is not an open file descriptor.
    public func close() throws {
        clean()
        
        #if os(Linux)
            guard Glibc.close(fileDescriptor) == 0 else {
                throw VeniceError.invalidFileDescriptor
            }
        #else
            guard Darwin.close(fileDescriptor) == 0 else {
                throw VeniceError.invalidFileDescriptor
            }
        #endif
    }
    
    /// Detaches the underlying `fileDescriptor`.
    /// After `detach` any operation will throw an error.
    ///
    /// - Returns: The underlying file descriptor.
    @discardableResult public func detach() -> Int32 {
        clean()
        
        defer {
            fileDescriptor = -1
        }
        
        return fileDescriptor
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
