class Node<T> {
    var value: T
    var next: Node<T>?
    weak var previous: Node<T>?

    init(value: T) {
        self.value = value
    }
}

class List<T> {
    private var head: Node<T>?
    private var tail: Node<T>?

    @discardableResult func append(_ value: T) -> Node<T> {
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

    @discardableResult func remove(_ node: Node<T>) -> T {
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
    
    @discardableResult func removeFirst() throws -> T {
        guard let head = head else {
            throw VeniceError.unexpectedError
        }
        
        return remove(head)
    }
}
