class Tile2048 {
  final int x;
  final int y;
  final int value;
  bool isNew;
  bool isMerged;

  Tile2048({
    required this.x,
    required this.y,
    required this.value,
    this.isNew = true,
    this.isMerged = false,
  });

  Tile2048 copyWith({
    int? x,
    int? y,
    int? value,
    bool? isNew,
    bool? isMerged,
  }) {
    return Tile2048(
      x: x ?? this.x,
      y: y ?? this.y,
      value: value ?? this.value,
      isNew: isNew ?? this.isNew,
      isMerged: isMerged ?? this.isMerged,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tile2048 &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          value == other.value;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ value.hashCode;
}

class Cell2048 {
  final int x;
  final int y;
  Tile2048? tile;
  Tile2048? mergeTile;

  Cell2048({required this.x, required this.y, this.tile, this.mergeTile});

  bool canAccept(Tile2048 tile) {
    return tile == null ||
        (mergeTile == null && tile.value == this.tile?.value);
  }

  void mergeTiles() {
    if (tile != null && mergeTile != null) {
      tile = tile!.copyWith(value: tile!.value + mergeTile!.value);
      mergeTile = null;
    }
  }
}

class Game2048State {
  final List<Tile2048> tiles;
  final int score;
  final int highScore;
  final bool gameOver;
  final bool won;
  final int gridSize;

  Game2048State({
    required this.tiles,
    required this.score,
    required this.highScore,
    required this.gameOver,
    required this.won,
    this.gridSize = 5,
  });

  Game2048State copyWith({
    List<Tile2048>? tiles,
    int? score,
    int? highScore,
    bool? gameOver,
    bool? won,
    int? gridSize,
  }) {
    return Game2048State(
      tiles: tiles ?? this.tiles,
      score: score ?? this.score,
      highScore: highScore ?? this.highScore,
      gameOver: gameOver ?? this.gameOver,
      won: won ?? this.won,
      gridSize: gridSize ?? this.gridSize,
    );
  }
}
