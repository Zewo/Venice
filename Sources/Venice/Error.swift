/// Venice operation error
public enum VeniceError : Error, Equatable {
    /// Thrown when the operation is performed on an invalid file descriptor.
    case invalidFileDescriptor
    /// Thrown when another coroutine is already blocked on `poll` with this file descriptor.
    case fileDescriptorBlockedInAnotherCoroutine
    /// Thrown when the operation reaches the deadline.
    case deadlineReached
    /// Thrown when the operation is performed on a closed channel.
    case closedChannel
    /// Thrown when a read operation fails.
    case readFailed
    /// Thrown when a write operation fails.
    case writeFailed

    /// Thrown when a system error occurs.
    case systemError(number: Int32)
    
    /// Thrown when an unexpected error occurs.
    /// This should never happen in the regular flow of an application.
    case unexpectedError

    /// :nodoc:
    public static func == (lhs: VeniceError, rhs: VeniceError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidFileDescriptor, .invalidFileDescriptor):
            return true
        case (.fileDescriptorBlockedInAnotherCoroutine, .fileDescriptorBlockedInAnotherCoroutine):
            return true
        case (.deadlineReached, .deadlineReached):
            return true
        case (.closedChannel, .closedChannel):
            return true
        case (.unexpectedError, .unexpectedError):
            return true
        case (.readFailed, .readFailed):
            return true
        case (.writeFailed, .writeFailed):
            return true
        default:
            return false
        }
    }
}
