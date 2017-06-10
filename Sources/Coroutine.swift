#if os(Linux)
    import Glibc
#else
    import Darwin.C
    import Foundation
#endif

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
/// let coroutine = try Coroutine {
///     ...
/// }
///
/// coroutine.cancel()
/// ```
public final class Coroutine {
    private typealias Handle = Int32
    private let handle: Handle
    
    /// Launches a coroutine that executes the closure passed as argument.
    /// The coroutine is executed concurrently, and its lifetime may exceed the lifetime
    /// of the caller.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// let coroutine = try Coroutine {
    ///     ...
    /// }
    ///
    /// coroutine.cancel()
    /// ```
    ///
    /// - Parameters:
    ///   - body: Body of the newly created coroutine.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceledCoroutine
    ///   Thrown when the operation is performed within a canceled coroutine.
    ///   #### VeniceError.outOfMemory
    ///   Thrown when the system doesn't have enough memory to create a new coroutine.
    public init(body: @escaping () throws -> Void) throws {
        var coroutine = {
            do {
                try body()
            } catch VeniceError.canceledCoroutine {
                return
            } catch {
                print(error)
            }
        }

        let result = co(nil, 0, &coroutine, nil, 0) { pointer in
            pointer?.assumingMemoryBound(to: (() -> Void).self).pointee()
        }

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
        cancel()
    }
    
    /// Cancels the coroutine.
    ///
    /// - Warning:
    /// Once a coroutine is canceled any coroutine-blocking operation within the coroutine
    /// will throw `VeniceError.canceledCoroutine`.
    public func cancel() {
        hclose(handle)
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
    ///
    /// - Warning:
    /// Once a coroutine is canceled calling `Couroutine.yield`
    /// will throw `VeniceError.canceledCoroutine`.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceledCoroutine
    ///   Thrown when the operation is performed within a canceled coroutine.
    public static func yield() throws {
        let result = CLibdill.yield()
        
        guard result == 0 else {
            switch errno {
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            default:
                throw VeniceError.unexpectedError
            }
        }
    }

    /// Wakes up at deadline.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// func execute<R>(_ deadline: Deadline, body: (Void) throws -> R) throws -> R {
    ///     try Coroutine.wakeUp(deadline)
    ///     try body()
    /// }
    ///
    /// try execute(1.second.fromNow()) {
    ///     print("Hey! Ho! Let's go!")
    /// }
    /// ```
    ///
    /// - Warning:
    /// Once a coroutine is canceled calling `Couroutine.wakeUp`
    /// will throw `VeniceError.canceledCoroutine`.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceledCoroutine
    ///   Thrown when the operation is performed within a canceled coroutine.
    public static func wakeUp(_ deadline: Deadline) throws {
        let result = msleep(deadline.value)
        
        guard result == 0 else {
            switch errno {
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
    
    /// Coroutine groups are useful for canceling multiple coroutines at the
    /// same time.
    ///
    /// ## Example:
    /// ```swift
    /// let group = Coroutine.Group(minimumCapacity: 2)
    ///
    /// try group.addCoroutine {
    ///     ...
    /// }
    ///
    /// try group.addCoroutine {
    ///     ...
    /// }
    ///
    /// // all coroutines in the group will be canceled
    /// group.cancel()
    /// ```
    public class Group {
        private var coroutines: [Int: Coroutine]
        private var finishedCoroutines: Set<Int> = []
        
        private static var id = 0
        
        private static func getNextID() -> Int {
            defer {
                if id == Int.max {
                    id = -1
                }
                
                id += 1
            }
            
            return id
        }
        
        /// Creates a new, empty coroutine group with at least the specified number
        /// of elements' worth of buffer.
        ///
        /// Use this initializer to avoid repeated reallocations of a group's buffer
        /// if you know you'll be adding elements to the group after creation. The
        /// actual capacity of the created group will be the smallest power of 2 that
        /// is greater than or equal to `minimumCapacity`.
        ///
        /// ## Example:
        ///
        /// ```swift
        /// let group = CoroutineGroup(minimumCapacity: 2)
        ///
        /// try group.addCoroutine {
        ///     ...
        /// }
        ///
        /// try group.addCoroutine {
        ///     ...
        /// }
        ///
        /// // all coroutines in the group will be canceled
        /// group.cancel()
        /// ```
        ///
        /// - Parameter minimumCapacity: The minimum number of elements that the
        ///   newly created group should be able to store without reallocating its
        ///   buffer.
        public init(minimumCapacity: Int = 0) {
            coroutines = [Int: Coroutine](minimumCapacity: minimumCapacity)
        }
        
        deinit {
            cancel()
        }
        
        /// Creates a lightweight coroutine and adds it to the group.
        ///
        /// ## Example:
        ///
        /// ```swift
        /// let coroutine = try group.addCoroutine {
        ///     ...
        /// }
        /// ```
        ///
        /// - Parameters:
        ///   - body: Body of the newly created coroutine.
        ///
        /// - Throws: The following errors might be thrown:
        ///   #### VeniceError.canceledCoroutine
        ///   Thrown when the operation is performed within a canceled coroutine.
        ///   #### VeniceError.outOfMemory
        ///   Thrown when the system doesn't have enough memory to create a new coroutine.
        /// - Returns: Newly created coroutine
        @discardableResult public func addCoroutine(body: @escaping () throws -> Void) throws -> Coroutine {
            removeFinishedCoroutines()
            
            var finished = false
            let id = Group.getNextID()
            
            let coroutine = try Coroutine { [unowned self] in
                defer {
                    finished = true
                    self.finishedCoroutines.insert(id)
                }
                
                try body()
            }
            
            if !finished {
                coroutines[id] = coroutine
            }
            
            return coroutine
        }
        
        /// Cancels all coroutines in the group.
        ///
        /// - Warning:
        /// Once a coroutine is canceled any coroutine-blocking operation within the coroutine
        /// will throw `VeniceError.canceledCoroutine`.
        public func cancel() {
            removeFinishedCoroutines()
            
            for (id, coroutine) in coroutines {
                defer {
                    coroutines[id] = nil
                }
                
                coroutine.cancel()
            }
        }
        
        private func removeFinishedCoroutines() {
            for id in finishedCoroutines {
                coroutines[id] = nil
            }
            
            finishedCoroutines.removeAll()
        }
    }
}
