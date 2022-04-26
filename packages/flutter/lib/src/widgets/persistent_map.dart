import 'dart:collection' show Queue;

const int _mask = 0x1f;
const int _maskSize = 5;
const int _maxDepth = 6;

abstract class _Node<T> {}

class _Leaf<T> implements _Node<T> {
  _Leaf(this.value);
  final T value;
}

class _Trie<T> implements _Node<T> {

  _Trie(this.children) : assert(children.length == childrenCount);

  _Trie.one(int idx, _Node<T>? value) : children = makeOneChildren(idx, value);
  final List<_Node<T>?> children;
  static const int childrenCount = 1 << _maskSize;

  static List<_Node<T>?> makeOneChildren<T>(int idx, _Node<T>? value) {
    assert(idx < childrenCount);
    final List<_Node<T>?> tempChildren = List<_Node<T>?>.filled(childrenCount, null);
    tempChildren[idx] = value;
    return tempChildren;
  }

  _Node<T>? set(int idx, _Node<T>? value) {
    assert(idx < childrenCount);
    final List<_Node<T>?> tempChildren = List<_Node<T>?>.from(children, growable: false);
    tempChildren[idx] = value;
    return _Trie<T>(tempChildren);
  }
}

_Node<T>? _setter<T>(_Node<T>? root, int idx, T? value, int depth) {
  if (depth > _maxDepth) {
    if (value != null) {
      return _Leaf<T>(value);
    } else {
      return null;
    }
  } else {
    final int adjustedIdx = (idx >> ((_maxDepth - depth) * _maskSize)) & _mask;
    if (root == null) {
      return _Trie<T>.one(adjustedIdx, _setter(null, idx, value, depth + 1));
    } else {
      final _Trie<T> trie = root as _Trie<T>;
      return trie.set(adjustedIdx,
          _setter(trie.children[adjustedIdx], idx, value, depth + 1));
    }
  }
}

T? _getter<T>(_Node<T>? root, int idx, int depth) {
  if (depth > _maxDepth) {
    if (root != null) {
      final _Leaf<T> leaf = root as _Leaf<T>;
      return leaf.value;
    } else {
      return null;
      // throw Exception('no item at $idx');
    }
  } else {
    if (root == null) {
      return null;
      // throw Exception('no item at $idx');
    } else {
      final int adjustedIdx = (idx >> ((_maxDepth - depth) * _maskSize)) & _mask;
      final _Trie<T> trie = root as _Trie<T>;
      final _Node<T>? child = trie.children[adjustedIdx];
      return _getter(child, idx, depth + 1);
    }
  }
}

void _forEach<T>(_Node<T>? root, int idx, Function(int, T) forFunc) {
  if (root != null) {
    if (root is _Trie<T>) {
      final _Trie<T> trie = root;
      for (int i = 0; i < _Trie.childrenCount; ++i) {
        final int adjustedIdx = (idx << _maskSize) + i;
        _forEach(trie.children[i], adjustedIdx, forFunc);
      }
    } else {
      final _Leaf<T> leaf = root as _Leaf<T>;
      forFunc(idx, leaf.value);
    }
  }
}

void _debug<T>(_Node<T>? root, int indent, int prefix) {
  var indentString = '';
  for (var j = 0; j < indent; ++j) {
    indentString += '  ';
  }
  if (root != null) {
    if (root is _Trie<T>) {
      var trie = root;
      var indentString = '';
      for (var j = 0; j < indent; ++j) {
        indentString += '  ';
      }
      print('$indentString$prefix: {');
      for (var i = 0; i < _Trie.childrenCount; ++i) {
        _debug(trie.children[i], indent + 1, i);
      }
      print('$indentString}');
    } else {
      var leaf = root as _Leaf<T>;
      print('$indentString$prefix: ${leaf.value} ');
    }
  } else {
    print('$indentString$prefix: null');
  }
}

class PersistentMap<K, V> {

  PersistentMap() : _root = null;
  PersistentMap._(_Node<V>? root) : _root = root;
  final _Node<V>? _root;
  static const int maxSize = 1 << (_maxDepth + 1 * _maskSize);

  V? get(K idx) {
    return _getter(_root, identityHashCode(idx), 0);
  }

  PersistentMap<K, V> set(K idx, V value) {
    return PersistentMap<K, V>._(_setter(_root, identityHashCode(idx), value, 0));
  }

  PersistentMap<K, V> remove(K idx) {
    return PersistentMap<K, V>._(_setter(_root, identityHashCode(idx), null, 0));
  }

  void forEach(void Function(int, V) forFunc) {
    _forEach(_root, 0, forFunc);
  }

  void debug() {
    _debug(_root, 0, 0);
  }

  Iterable<V> get values sync* {
    final Queue<_Node<V>> nodes = Queue<_Node<V>>();
    if (_root != null) {
      nodes.addLast(_root!);
    }
    while (nodes.isNotEmpty) {
      final _Node<V> node = nodes.removeFirst();
      if (node is _Leaf<V>) {
        yield node.value;
      } else if (node is _Trie<V>) {
        for (int i = 0; i < _Trie.childrenCount; ++i) {
          if (node.children[i] != null) {
            nodes.addLast(node.children[i]!);
          }
        }
      }
    }
  }
}
