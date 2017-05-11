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
/// invokes a function that would block (such as `Coroutine.wakeUp`, `fileDescriptor.poll`, `channel.send` or `channel.receive`),
/// the CPU is automatically yielded.
/// However, if a coroutine runs without calling any blocking functions, it may hold
/// the CPU forever. For these cases, the `Coroutine.yield` function can be used to manually relinquish
/// the CPU to other coroutines manually.
public class Coroutine : Handle {
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
    /// try coroutine.cancel()
    /// ```
    ///
    /// - Parameters:
    ///   - body: Body of the newly created coroutine.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceled
    ///   Thrown when the operation is performed within a canceled coroutine.
    ///   #### VeniceError.outOfMemory
    ///   Thrown when the system doesn't have enough memory to perform the operation.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
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
            pointer?.assumingMemoryBound(to: ((Void) -> Void).self).pointee()
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

        super.init(handle: result)
    }

    deinit {
        try? cancel()
    }
    
    /// Explicitly passes control to other coroutines.
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
    /// try group.cancel()
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
        /// try group.cancel()
        /// ```
        ///
        /// - Parameter minimumCapacity: The minimum number of elements that the
        ///   newly created group should be able to store without reallocating its
        ///   buffer.
        public init(minimumCapacity: Int = 0) {
            coroutines = [Int: Coroutine](minimumCapacity: minimumCapacity)
        }
        
        deinit {
            try? cancel()
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
        ///   #### VeniceError.canceled
        ///   Thrown when the operation is performed within a canceled coroutine.
        ///   #### VeniceError.outOfMemory
        ///   Thrown when the system doesn't have enough memory to perform the operation.
        ///   #### VeniceError.unexpectedError
        ///   Thrown when an unexpected error occurs.
        ///   This should never happen in the regular flow of an application.
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
        /// `cancel` guarantees that all associated resources are deallocated.
        /// However, it does not guarantee that the coroutines' work will have been fully finished.
        /// For example, outbound network data may not be flushed.
        ///
        /// - Throws: The following errors might be thrown:
        ///   #### VeniceError.canceled
        ///   Thrown when the operation is performed on a canceled coroutine.
        ///   #### VeniceError.unexpectedError
        ///   Thrown when an unexpected error occurs.
        ///   This should never happen in the regular flow of an application.
        public func cancel() throws {
            removeFinishedCoroutines()
            
            for (id, coroutine) in coroutines {
                defer {
                    coroutines[id] = nil
                }
                
                try coroutine.cancel()
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
