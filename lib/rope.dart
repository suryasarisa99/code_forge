class Rope {
  static const int _leafSize = 1024;   
  _RopeNode _root;
  int _length;
  
  List<String>? _lineCache;
  
  Rope([String initialText = '']) 
    : _root = _RopeLeaf(initialText),
      _length = initialText.length;
  
  int get length => _length;
  
  String getText() => _root.getText();
  
  String substring(int start, [int? end]) {
    end ??= _length;
    if (start < 0 || start > _length || end < start || end > _length) {
      throw RangeError('Invalid range');
    }
    return _root.substring(start, end);
  }
  
  void insert(int position, String text) {
    if (position < 0 || position > _length) {
      throw RangeError('Invalid position');
    }
    if (text.isEmpty) return;
    
    _lineCache = null;     _root = _root.insert(position, text, _leafSize);
    _length += text.length;
  }
  
  void delete(int start, int end) {
    if (start < 0 || start > _length || end < start || end > _length) {
      throw RangeError('Invalid range');
    }
    if (start == end) return;
    
    _lineCache = null;     _root = _root.delete(start, end);
    _length -= (end - start);
  }
  
  List<String> get cachedLines {
    _lineCache ??= lines.toList();
    return _lineCache!;
  }
  
  String charAt(int position) {
    if (position < 0 || position >= _length) {
      throw RangeError('Invalid position');
    }
    return _root.charAt(position);
  }
  
  Iterable<String> get lines sync* {
    final buffer = StringBuffer();
    
    for (final chunk in _root.chunks()) {
      for (int i = 0; i < chunk.length; i++) {
        final char = chunk[i];
        if (char == '\n') {
          yield buffer.toString();
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    
    if (buffer.isNotEmpty || _length == 0) {
      yield buffer.toString();
    }
  }
  
  int get lineCount {
    int count = 1;
    for (final chunk in _root.chunks()) {
      count += '\n'.allMatches(chunk).length;
    }
    return count;
  }
  
  int findLineStart(int offset) {
    if (offset <= 0) return 0;
    
    int searchStart = offset - 1;
    const chunkSize = 256;     
    while (searchStart >= 0) {
      final chunkStart = (searchStart - chunkSize + 1).clamp(0, _length);
      final chunk = substring(chunkStart, searchStart + 1);
      
      for (int i = chunk.length - 1; i >= 0; i--) {
        if (chunk[i] == '\n') {
          return chunkStart + i + 1;
        }
      }
      
      if (chunkStart == 0) {
        return 0;       }
      
      searchStart = chunkStart - 1;
    }
    
    return 0;
  }
  
  int findLineEnd(int offset) {
    if (offset >= _length) return _length;
    
    int searchStart = offset;
    const chunkSize = 256;     
    while (searchStart < _length) {
      final chunkEnd = (searchStart + chunkSize).clamp(0, _length);
      final chunk = substring(searchStart, chunkEnd);
      
      for (int i = 0; i < chunk.length; i++) {
        if (chunk[i] == '\n') {
          return searchStart + i;
        }
      }
      
      if (chunkEnd == _length) return _length;
      searchStart = chunkEnd;
    }
    
    return _length;
  }
}

abstract class _RopeNode {
  int get weight;   int get _totalLength;   String getText();
  String substring(int start, int end);
  String charAt(int position);
  _RopeNode insert(int position, String text, int leafSize);
  _RopeNode delete(int start, int end);
  Iterable<String> chunks();
}

class _RopeLeaf extends _RopeNode {
  final String text;
  
  _RopeLeaf(this.text);
  
  @override
  int get _totalLength => text.length;
  
  @override
  int get weight => text.length;
  
  @override
  String getText() => text;
  
  @override
  String substring(int start, int end) => text.substring(start, end);
  
  @override
  String charAt(int position) => text[position];
  
  @override
  _RopeNode insert(int position, String insertText, int leafSize) {
    final newText = text.substring(0, position) + insertText + text.substring(position);
    
    if (newText.length > leafSize * 2) {
      final mid = newText.length ~/ 2;
      return _RopeConcat(
        _RopeLeaf(newText.substring(0, mid)),
        _RopeLeaf(newText.substring(mid)),
      );
    }
    
    return _RopeLeaf(newText);
  }
  
  @override
  _RopeNode delete(int start, int end) {
    return _RopeLeaf(text.substring(0, start) + text.substring(end));
  }
  
  @override
  Iterable<String> chunks() sync* {
    yield text;
  }
}

class _RopeConcat extends _RopeNode {
  final _RopeNode left;
  final _RopeNode right;
  final int _leftLength;   
  _RopeConcat(this.left, this.right) : _leftLength = left._totalLength;
  
  @override
  int get weight => _leftLength;
  
  @override
  int get _totalLength => _leftLength + right._totalLength;
  
  @override
  String getText() => left.getText() + right.getText();
  
  @override
  String substring(int start, int end) {
    if (end <= weight) {
      return left.substring(start, end);
    } else if (start >= weight) {
      return right.substring(start - weight, end - weight);
    } else {
      return left.substring(start, weight) + right.substring(0, end - weight);
    }
  }
  
  @override
  String charAt(int position) {
    if (position < weight) {
      return left.charAt(position);
    } else {
      return right.charAt(position - weight);
    }
  }
  
  @override
  _RopeNode insert(int position, String text, int leafSize) {
    if (position <= weight) {
      return _RopeConcat(
        left.insert(position, text, leafSize),
        right,
      )._rebalance();
    } else {
      return _RopeConcat(
        left,
        right.insert(position - weight, text, leafSize),
      )._rebalance();
    }
  }
  
  @override
  _RopeNode delete(int start, int end) {
    if (end <= weight) {
      return _RopeConcat(left.delete(start, end), right)._rebalance();
    } else if (start >= weight) {
      return _RopeConcat(left, right.delete(start - weight, end - weight))._rebalance();
    } else {
      final newLeft = left.delete(start, weight);
      final newRight = right.delete(0, end - weight);
      return _RopeConcat(newLeft, newRight)._rebalance();
    }
  }
  
  @override
  Iterable<String> chunks() sync* {
    yield* left.chunks();
    yield* right.chunks();
  }
  
  _RopeNode _rebalance() {
    if (left is _RopeLeaf && (left as _RopeLeaf).text.isEmpty) {
      return right;
    }
    if (right is _RopeLeaf && (right as _RopeLeaf).text.isEmpty) {
      return left;
    }
    return this;
  }
}