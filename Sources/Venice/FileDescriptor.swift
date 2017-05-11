#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

/// A handle used to access a file or other input/output resource,
/// such as a pipe or network socket.
public struct FileDescriptor {
    /// Creates a `FileDescriptor` from a file descriptor handle.
    public init(_ fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }
    
    /// File descriptor handle.
    public let fileDescriptor: Int32
    
    /// Waits for the file descriptor to become either readable/writable
    /// or to get into an error state. Either case leads to a successful return
    /// from the function. To distinguish the two outcomes, follow up with a
    /// read/write operation on the file descriptor.
    ///
    /// - Parameters:
    ///   - fileDescriptor: Valid file descriptor to be polled
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
    ///   #### VeniceError.timeout
    ///   Thrown when the operation times out.
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
                throw VeniceError.canceledCoroutine
            case EEXIST:
                throw VeniceError.fileDescriptorBlockedInAnotherCoroutine
            case ETIMEDOUT:
                throw VeniceError.timeout
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
    /// `clean` has to be called before the file descriptor
    /// is closed. Otherwise the behavior is **undefined**.
    ///
    /// - Warning:
    /// `clean` has to be called with file descriptors provided by
    /// third-party libraries, just before returning them back to
    /// their original owners. Otherwise the behavior is **undefined**.
    /// - Parameter fileDescriptor: File descriptor to be cleaned
    public func clean() {
        fdclean(fileDescriptor)
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
