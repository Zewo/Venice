#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Foundation
import Dispatch
import CLibdill

/// Lightweight coroutine.
///
/// Launching coroutines and switching between them is extremely fast.
/// It requires only a few machine instructions.
/// This makes coroutines a suitable basic flow control mechanism,
/// like the `if` or `while` keywords, which have comparable performance.
///
/// Coroutines have one big limitation, though: All coroutines run on a single
/// CPU core. If you want to take advantage of multiple cores, you have to launch
/// multiple threads or processes, presumably as many of them as there are CPU cores
/// on your machine.
///
/// Coroutines are scheduled cooperatively. What that means is that a coroutine has to
/// explicitly yield control of the CPU to allow a different coroutine to run.
/// In a typical scenario, this is done transparently to the user: When a coroutine
/// invokes a function that would block (such as `Coroutine.wakeUp`, `FileDescriptor.poll`, `channel.send` or `channel.receive`),
/// the CPU is automatically yielded.
/// However, if a coroutine runs without calling any blocking functions, it may hold
/// the CPU forever. For these cases, the `Coroutine.yield` function can be used to manually relinquish
/// the CPU to other coroutines manually.
///
/// ## Example:
///
/// ```swift
/// Coroutine.run {
///     ...
/// }
/// ```
public final class Coroutine : CustomStringConvertible {
    /// Launches a coroutine that executes the closure passed as argument.
    /// The coroutine is executed concurrently, and its lifetime may exceed the lifetime
    /// of the caller.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// Coroutine.run {
    ///     ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - routine: The routine to execute
    public static func run(label: String = "anonymous", file: String = #file, line: Int = #line, routine: @escaping () -> Void) {
        Coroutine.reaper.reap()

        var _routine = {
            Coroutine.current = Coroutine(label: label)
            routine()
            Coroutine.current = Coroutine.main
        }

        let result = co(nil, 0, &_routine, file, Int32(line)) { handle, pointer in
            pointer?.assumingMemoryBound(to: (() -> Void).self).pointee()
            Coroutine.reaper.push(handle: handle)
        }

        guard result != -1 else {
            switch errno {
            case ENOMEM:
                fatalError("Out of memory while creating coroutine.")
            default:
                fatalError("Unexpected error \(errno) while creating coroutine.")
            }
        }
    }

    /// Launches a coroutine on a background thread that executes the closure passed
    /// as an argument. The coroutine is executed concurrently but the caller is
    /// blocked cooperatively until a result is available.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// let result: Bool = Coroutine.worker {
    ///    ... some heavy processing work
    ///    return true
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - routine: the routine to execute
    /// - Warning:
    ///   Worker coroutines should be treated mostly like individual processes. Care must be taken not
    ///   to share any coroutine compatible primitives such as channels or sockets as they are not threadsafe.
    public static func worker<T>(routine: @escaping () throws -> T) throws -> T {
        var resultingValue: T? = nil
        var resultingError: Error? = nil

        var fds: [Int32] = [0, 0]
        var rc: Int32 = fds.withUnsafeMutableBufferPointer {
            #if os(Linux)
            return socketpair(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0, $0.baseAddress!)
            #else
            return socketpair(AF_UNIX, SOCK_STREAM, 0, $0.baseAddress!)
            #endif
        }
        guard rc == 0 else {
            throw VeniceError.systemError(number: errno)
        }
        defer {
            #if os(Linux)
                Glibc.close(fds[0])
                Glibc.close(fds[1])
            #else
                Darwin.close(fds[0])
                Darwin.close(fds[1])
            #endif
        }

        let local = try FileDescriptor(fds[0])
        let remote = try FileDescriptor(fds[1])

        DispatchQueue.global().async {
            do {
                resultingValue = try routine()
            } catch {
                resultingError = error
            }
            try? [UInt8(1)].withUnsafeBufferPointer {
                try remote.write(UnsafeRawBufferPointer($0), deadline: .never)
                return
            }
            try? remote.close()
        }

        var buffer = UnsafeMutableRawBufferPointer.allocate(count: 1)
        defer {
            buffer.deallocate()
        }
        _ = try? local.read(buffer, deadline: .never)
        
        guard let value = resultingValue else {
            guard let error = resultingError else {
                throw VeniceError.unexpectedError
            }
            throw error
        }

        return value
    }

    /// Gets a reference to the current running coroutine
    public private(set) static var current: Coroutine {
        get {
            guard let raw = clsget() else {
                return Coroutine.main
            }
            return Unmanaged<Coroutine>.fromOpaque(raw).takeUnretainedValue()
        }
        set {
            if let raw = clsget() {
                _ = Unmanaged<Coroutine>.fromOpaque(raw).takeRetainedValue()
                clsset(nil)
            }
            clsset(Unmanaged.passRetained(newValue).toOpaque())
        }
    }

    private static var main: Coroutine {
        let coroutine: Coroutine
        if let existing = Thread.current.threadDictionary["Venice.Coroutine.main"] as? Coroutine {
            coroutine = existing
        } else {
            coroutine = Coroutine()
            Thread.current.threadDictionary["Venice.Coroutine.main"] = coroutine
        }
        return coroutine
    }

    private final class Reaper {
        private var handles: [Int32] = []

        func push(handle: Int32) {
            handles.append(handle)
        }

        func reap() {
            guard !handles.isEmpty else {
                return
            }

            for handle in handles {
                hclose(handle)
            }
            handles = []
        }

        deinit {
            reap()
        }
    }

    private static var reaper: Reaper {
        let reaper: Reaper
        if let existing = Thread.current.threadDictionary["Venice.Coroutine.reaper"] as? Reaper {
            reaper = existing
        } else {
            reaper = Reaper()
            Thread.current.threadDictionary["Venice.Coroutine.reaper"] = reaper
        }
        return reaper
    }

    /// Explicitly passes control to other coroutines.
    /// By calling this function, you give other coroutines a chance to run.
    ///
    /// You should consider using `Coroutiner.yield()` when doing lengthy computations
    /// which don't have natural coroutine switching points.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// for _ in 0 ..< 1000000 {
    ///     expensiveComputation()
    ///     try Coroutine.yield() // Give other coroutines a chance to run.
    /// }
    /// ```
    public static func yield() {
        let result = CLibdill.yield()

        guard result != -1 else {
            fatalError("Unexpected error while yielding coroutine.")
        }
    }

    /// Wakes up at deadline.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// func execute<R>(at deadline: Deadline, body: (Void) throws -> R) throws -> R {
    ///     Coroutine.wakeUp(at: deadline)
    ///     try body()
    /// }
    ///
    /// try execute(at: 1.second.fromNow()) {
    ///     print("Hey! Ho! Let's go!")
    /// }
    /// ```
    public static func wakeUp(at deadline: Deadline) {
        let result = CLibdill.msleep(deadline.value)

        guard result != -1 else {
            fatalError("Unexpected error while sleeping coroutine.")
        }
    }

    /// Sleeps for duration.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// func execute<R>(after duration: Duration, body: (Void) throws -> R) throws -> R {
    ///     Coroutine.sleep(for: duration)
    ///     try body()
    /// }
    ///
    /// try execute(after 1.second) {
    ///     print("Hey! Ho! Let's go!")
    /// }
    /// ```
    public static func sleep(for duration: Duration) {
        wakeUp(at: duration.fromNow())
    }

    /// Coroutine label
    public let label: String

    /// Coroutine description
    public var description: String {
        return label
    }

    /// Coroutine local storage subscripting
    public subscript(key: String) -> Any? {
        get {
            return storage[key]
        }
        set {
            if let value = newValue {
                storage[key] = value
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }

    /// Coroutine local storage subscripting
    public subscript(key: String, default: Any) -> Any? {
        get {
            return self[key] ?? `default`
        }
        set {
            self[key] = newValue
        }
    }

    private var storage: [String: Any] = [:]

    private init(label: String = "anonymous") {
        self.label = label
    }
}

