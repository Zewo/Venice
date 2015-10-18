import Venice
import Darwin

extension CollectionType where Index == Int {
    func shuffle() -> [Generator.Element] {
        var list = Array(self)
        list.shuffleInPlace()
        return list
    }
}

extension MutableCollectionType where Index == Int {
    mutating func shuffleInPlace() {
        if count < 2 { return }

        for i in 0..<count - 1 {
            let j = Int(arc4random_uniform(UInt32(count - i))) + i
            guard i != j else { continue }
            swap(&self[i], &self[j])
        }
    }
}

final class Tree<T> {
    var left: Tree?
    var value: T
    var right: Tree?

    init(left: Tree?, value: T, right: Tree?) {
        self.left = left
        self.value = value
        self.right = right
    }
}
//: Traverses a tree depth-first,
//: sending each Value on a channel.
func walk<T>(tree: Tree<T>?, channel: Channel<T>) {
    if let tree = tree {
        walk(tree.left, channel: channel)
        channel <- tree.value
        walk(tree.right, channel: channel)
    }
}
//: Launches a walk in a new coroutine,
//: and returns a read-only channel of values.
func walker<T>(tree: Tree<T>?) -> SendingChannel<T> {
    let channel = Channel<T>()
    co {
        walk(tree, channel: channel)
        channel.close()
    }
    return channel.sendingChannel
}
//: Reads values from two walkers
//: that run simultaneously, and returns true
//: if tree1 and tree2 have the same contents.
func ==<T : Equatable>(tree1: Tree<T>, tree2: Tree<T>) -> Bool {
    let channel1 = walker(tree1)
    let channel2 = walker(tree2)
    while true {
        let value1 = <-channel1
        let value2 = <-channel2
        if value1 == nil || value2 == nil {
            return value1 == value2
        }
        if value1 != value2 {
            break
        }
    }
    return false
}
//: Returns a new, random binary tree
//: holding the values 1*k, 2*k, ..., n*k.
func newTree(n n: Int, k: Int) -> Tree<Int> {
    var tree: Tree<Int>?
    for value in (1...n).shuffle() {
        tree = insert(tree, value: value * k)
    }
    return tree!
}
//: Inserts a value in the tree
func insert(tree: Tree<Int>?, value: Int) -> Tree<Int> {
    if let tree = tree {
        if value < tree.value {
            tree.left = insert(tree.left, value: value)
            return tree
        } else {
            tree.right = insert(tree.right, value: value)
            return tree
        }
    } else {
        return Tree<Int>(left: nil, value: value, right: nil)
    }
}

let tree = newTree(n: 100, k: 1)

print("Same contents \(tree == newTree(n: 100, k: 1))")
print("Differing sizes \(tree == newTree(n: 99, k: 1))")
print("Differing values \(tree == newTree(n: 100, k: 2))")
print("Dissimilar \(tree == newTree(n: 101, k: 2))")
