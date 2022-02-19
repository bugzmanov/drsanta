import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flame/anchor.dart';
import 'package:flame/assets/images.dart';
import 'package:flame/components/component.dart';
import 'package:flame/components/position_component.dart';
import 'package:flame/components/sprite_component.dart';
import 'package:flame/components/text_box_component.dart';
import 'package:flame/game.dart';
import 'package:flame/gestures.dart';
import 'package:flame/layer/layer.dart';
import 'package:flame/palette.dart';
import 'package:flame/particle.dart';
import 'package:flame/particles/accelerated_particle.dart';
import 'package:flame/particles/computed_particle.dart';
import 'package:flame/particles/translated_particle.dart';
import 'package:flame/sprite.dart';
import 'package:flame/spritesheet.dart';
import 'package:flame/text_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flame/extensions/vector2.dart';
import 'package:flame/sprite_animation.dart';
import 'package:flame/components/sprite_animation_component.dart';
import 'package:flutter/material.dart' hide Image;
import 'dart:ui';

import 'package:tuple/tuple.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final game = DrGame();
  runApp(
    GameWidget(
      game: game,
    ),
  );
}

enum VirusType { Red, Blue, Yellow }

enum PillDirection { Horizontal, Vectical }

class PillObject with GameObject {
  int x, y;
  PillDirection direction = PillDirection.Horizontal;
  SpriteComponent spriteComponent;
  Board board;
  int rotation = 0;
  List<int> colors;

  PillObject(this.x, this.y, this.spriteComponent, this.board, this.colors);

  Tuple2<Anchor, double> _angle(int _rotation) {
    switch (_rotation) {
      case 0:
        return Tuple2<Anchor, double>(Anchor.topLeft, 0.0);
      case 90:
        return Tuple2<Anchor, double>(Anchor.topCenter, -1.5708);
      case 180:
        return Tuple2<Anchor, double>(Anchor.bottomRight, -1.5708 * 2);
      case 270:
        return Tuple2<Anchor, double>(Anchor.bottomCenter, -1.5708 * 3);
    }
  }

  List<List<int>> currentPosition() {
    if (rotation == 90 || rotation == 270) {
      return [
        [y, x, rotation == 90 ? colors[0] : colors[1]],
        [y - 1, x, rotation == 90 ? colors[1] : colors[0]]
      ];
    } else {
      return [
        [y, x, rotation == 0 ? colors[0] : colors[1]],
        [y, x + 1, rotation == 0 ? colors[1] : colors[0]]
      ];
    }
  }

  bool moveDown() {
    var position = currentPosition().map((p) => [p[0] + 1, p[1]]).toList();
    if (board.canOccupy(position)) {
      y += 1;
      return true;
    } else {
      return false;
    }
  }

  bool moveHorizontal(int deltaX) {
    var position = currentPosition().map((p) => [p[0], p[1] + deltaX]).toList();
    if (board.canOccupy(position)) {
      x += deltaX;
      return true;
    } else {
      return false;
    }
  }

  void toggleDirection() {
    var tmpRotation = rotation;

    rotation += 90;
    rotation %= 360;
    if (!board.canOccupy(currentPosition())) {
      rotation = tmpRotation;
      return;
    }

    var angle = _angle(rotation);
    spriteComponent.anchor = angle.item1;
    spriteComponent.angle = angle.item2;
  }

  @override
  PositionComponent component() {
    return spriteComponent;
  }

  @override
  bool canFall() {
    return false;
  }
}

class Board {
  List<List<GameObject>> componentsBoard =
      List.generate(16, (_) => List.generate(8, (_) => null));
  List<List<int>> board = List.generate(16, (_) => List.generate(8, (_) => -1));

  double screenX, screenY;

  Board(this.screenX, this.screenY);

  bool canOccupy(List<List<int>> coordinates) {
    return !coordinates
            .any((v2) => v2[0] < 0 || v2[0] > 15 || v2[1] < 0 || v2[1] > 7) &&
        !coordinates.any((v2) => board[v2[0]][v2[1]] != -1);
  }

  void put(int x, int y, int color) {
    board[y][x] = color;
  }

  void add(GameObject object) {
    for (List<int> p in object.currentPosition()) {
      componentsBoard[p[0]][p[1]] = object;
      board[p[0]][p[1]] = p[2];
    }
  }

  int getColor(int y, int x) {
    return board[y][x];
  }

  //nullable
  GameObject getObject(int y, int x) {
    return componentsBoard[y][x];
  }

  GameObject remove(int y, int x) {
    var obj = getObject(y, x);
    if (obj != null) {
      for (List<int> p in obj.currentPosition()) {
        board[p[0]][p[1]] = -1;
        componentsBoard[p[0]][p[1]] = null;
      }
    }
    return obj;
  }

  Set<GameObject> freeFall() {
    Set<GameObject> global = HashSet<GameObject>();
    Set<GameObject> updated = HashSet<GameObject>();

    do {
      updated.clear();
      for (var y = 15; y >= 0; y--) {
        for (var x = 0; x < 8; x++) {
          var obj = getObject(y, x);
          if (obj != null && !updated.contains(obj) && obj.moveDown()) {
            updated.add(obj);
          }
        }
      }
      global.addAll(updated);
    } while (!updated.isEmpty);

    for (GameObject obj in global) {
      obj.component().position =
          Vector2(screenX + obj.x * 26.0, screenY + obj.y * 26.0);
    }

    return global;
  }
}

mixin GameObject {
  int x, y;
  List<List<int>> currentPosition();
  bool moveDown();
  PositionComponent component();
  bool canFall();
}

class Virus with GameObject {
  PositionComponent _component;
  int x, y, color;

  Virus(this._component, this.x, this.y, this.color);

  @override
  PositionComponent component() => _component;

  @override
  List<List<int>> currentPosition() {
    return [
      [y, x, color]
    ];
  }

  @override
  bool moveDown() {
    return false;
  }

  @override
  bool canFall() {
    return false;
  }
}

class HalfPill with GameObject {
  PositionComponent _component;
  Board board;
  int x, y, color;

  HalfPill(this.board, this._component, this.x, this.y, this.color);

  @override
  PositionComponent component() => _component;

  @override
  List<List<int>> currentPosition() {
    return [
      [y, x, color]
    ];
  }

  @override
  bool moveDown() {
    var position = currentPosition().map((p) => [p[0] + 1, p[1]]).toList();
    if (board.canOccupy(position)) {
      board.remove(y, x);
      y += 1;
      board.add(this);
      return true;
    } else {
      return false;
    }
  }

  @override
  bool canFall() {
    return true;
  }
}

class FrozenPill with GameObject {
  PositionComponent _component;
  Board board;
  int x, y, rotation;
  List<int> colors;

  static FrozenPill from(Board board, PillObject object) {
    return FrozenPill(board, object.component(), object.x, object.y,
        object.rotation, object.colors);
  }

  FrozenPill(
      this.board, this._component, this.x, this.y, this.rotation, this.colors);

  @override
  PositionComponent component() => _component;

  @override
  List<List<int>> currentPosition() {
    if (rotation == 90 || rotation == 270) {
      return [
        [y, x, rotation == 90 ? colors[0] : colors[1]],
        [y - 1, x, rotation == 90 ? colors[1] : colors[0]]
      ];
    } else {
      return [
        [y, x, rotation == 0 ? colors[0] : colors[1]],
        [y, x + 1, rotation == 0 ? colors[1] : colors[0]]
      ];
    }
  }

  @override
  bool moveDown() {
    var position = currentPosition().map((p) => [p[0] + 1, p[1]]).toList();
    if (board.canOccupy(position)) {
      board.remove(y, x);
      y += 1;
      board.add(this);
      return true;
    } else {
      return false;
    }
  }

  @override
  bool canFall() {
    return true;
  }
}

class Pills {
  SpriteSheet sheet;
  Images images;

  List<List<int>> possibleColors = [
    [0, 0],
    [1, 1],
    [2, 2],
    [2, 0],
    [2, 1],
    [0, 1]
  ];

// enum VirusType { Red, Blue, Yellow }

  Pills(Images images) {
    this.images = images;
    sheet = SpriteSheet(
      image: images.fromCache('all_pills.png'),
      srcSize: Vector2(313.0, 132.0),
    );
  }

  SpriteComponent forColors(List<int> colors) {
    Sprite pill;
    if (colors[0] == 0 && colors[1] == 0) {
      pill = sheet.getSprite(0, 0);
    } else if (colors[0] == 1 && colors[1] == 1) {
      pill = sheet.getSprite(0, 2);
    } else if (colors[0] == 2 && colors[1] == 2) {
      pill = sheet.getSprite(0, 1);
    } else if (colors[0] == 2 && colors[1] == 0) {
      pill = sheet.getSprite(0, 3);
    } else if (colors[0] == 2 && colors[1] == 1) {
      pill = sheet.getSprite(0, 4);
    } else if (colors[0] == 0 && colors[1] == 1) {
      pill = sheet.getSprite(0, 5);
    } else {
      throw new Exception("Should not happen. Colors: " + colors.toString());
    }

    SpriteComponent pillComponent =
        SpriteComponent.fromSprite(Vector2(50.0, 22.0), pill);
    return pillComponent;
  }
}

class FiniteAnimation extends Component {
  List<SpriteAnimationComponent> components;
  Function callback;

  FiniteAnimation(this.components, this.callback);

  @override
  void update(double t) {
    var isDone = !components.any((c) => !c.animation.isLastFrame);
    if (isDone) {
      callback();
      remove();
    }
  }
}

class FiniteAnimationComponent extends SpriteAnimationComponent {
  Function callback;
  FiniteAnimationComponent(
      Vector2 size, SpriteAnimation animation, this.callback)
      : super(size, animation, removeOnFinish: true);

  @override
  void onRemove() {
    callback();
  }
}

class DrGame extends BaseGame with TapDetector, HorizontalDragDetector {
  Random random = new Random();

  double time = 0.0;

  Offset currentOffset;
  var pillDeltaX = 0.0;
  PillObject pillObject;

  Pills pills;
  bool speedFall = false;
  int level = 7;
  BackgroundLayer bgLayer;

  double screenX = 90.0, screenY = 170.0, screenWidth, screenHight;
  Board board = new Board(90.0, 170.0);

  int score = 0;
  MyTextBox scoreText;
  SpriteAnimation santa;

  bool freeze = false;

  Vector2 cellSize;
  Vector2 halfCellSize;
  final sceneDuration = const Duration(seconds: 1);
  static const gridSize = 5.0;
  static const steps = 5;

  SpriteAnimation virusAnimation(VirusType type) {
    List spriteAndSize = [];
    switch (type) {
      case VirusType.Blue:
        spriteAndSize = ['blue_mine.png', 25.0];
        break;
      case VirusType.Yellow:
        spriteAndSize = ['yellow_mine.png', 25.0];
        break;
      case VirusType.Red:
        spriteAndSize = ['red_mine.png', 25.0];
        break;
    }
    return SpriteAnimation.fromFrameData(
      images.fromCache(spriteAndSize[0]),
      SpriteAnimationData.sequenced(
        amount: 3,
        textureSize: Vector2.all(spriteAndSize[1]),
        stepTime: 0.25 + (random.nextDouble() / 10.0),
        loop: true,
      ),
    );
  }

  SpriteAnimation deathCell() {
    return SpriteAnimation.fromFrameData(
        images.fromCache('empty_half_3d.png'),
        SpriteAnimationData.sequenced(
            amount: 8,
            textureSize: Vector2(152.0, 129.0),
            stepTime: 0.05,
            loop: true));
  }

  PositionComponent createDethCellComponent() {
    return SpriteAnimationComponent(Vector2.all(25.0), deathCell(),
        removeOnFinish: true);
  }

  PositionComponent createVirusComponent(VirusType type) {
    return SpriteAnimationComponent(Vector2.all(25.0), virusAnimation(type));
  }

  Virus createVirus(int y, int x, VirusType type) {
    var component = createVirusComponent(type);
    return Virus(component, x, y, type.index);
  }

  Sprite createHalfPillSprite(int color) {
    switch (color) {
      case 0:
        return Sprite(images.fromCache('red_half.png'));
      case 1:
        return Sprite(images.fromCache('blue_half.png'));
      case 2:
        return Sprite(images.fromCache('yellow_half.png'));
    }
  }

  HalfPill createHalfPill(int y, int x, int color) {
    Sprite pill = createHalfPillSprite(color);
    SpriteComponent pillComponent =
        SpriteComponent.fromSprite(Vector2(25.0, 22.0), pill);
    var half = HalfPill(board, pillComponent, x, y, color);
    return half;
  }

  void spawnParticles() {
    // Contains sample particles, in order by complexity
    // and amount of used features. Jump to source for more explanation on each
    final particles = <Particle>[fireworkParticle()];

    // Place all the [Particle] instances
    // defined above in a grid on the screen
    // as per defined grid parameters
    do {
      final particle = particles.removeLast();
      final double col = particles.length % gridSize;
      final double row = (particles.length ~/ gridSize).toDouble();
      final cellCenter =
          (cellSize.clone()..multiply(Vector2(col, row))) + (cellSize * .5);

      add(
        // Bind all the particles to a [Component] update
        // lifecycle from the [BaseGame].
        TranslatedParticle(
          lifespan: 1,
          offset: cellCenter.toOffset(),
          child: particle,
        ).asComponent(),
      );
    } while (particles.isNotEmpty);
  }

  @override
  Future<void> onLoad() async {
    cellSize = size / gridSize;
    halfCellSize = cellSize * .5;

    await images.loadAll([
      'red_mine.png',
      'blue_mine.png',
      'blue_monster.png',
      'yellow_mine.png',
      'bottle.png',
      'pill2.png',
      'pill3.png',
      'blue_half.png',
      'red_half.png',
      'yellow_half.png',
      'empty_half_3d.png',
      'all_pills.png',
      'santa-sheet.png',
      'scoreboard.png',
      '100_animation.png',
      'scores_animation.png',
      'pill_throw_sheet.png'
    ]);

    var bgBottle =
        Sprite(images.fromCache('bottle.png'), srcSize: Vector2(226.0, 420.0));
    bgLayer = BackgroundLayer(bgBottle, screenX, screenY);

    pills = Pills(images);
    generateVirusBoard();

    santa = SpriteAnimation.fromFrameData(
        images.fromCache('santa-sheet.png'),
        SpriteAnimationData.sequenced(
            amount: 4,
            textureSize: Vector2(36.0, 51.0),
            stepTime: 0.20,
            loop: false));
    var component = SpriteAnimationComponent(Vector2(55, 82), santa);
    component.position = Vector2(300.0, 20.0);
    add(component);

    dropNewPill();

    // var scoreComponent = SpriteComponent.fromSprite(
    //     Vector2(77.0, 78.0),
    //     Sprite(images.fromCache('scoreboard.png'),
    //         srcSize: Vector2(77.0, 78.0)));

    // scoreComponent.position = Vector2(50, 10);
    // add(scoreComponent);

    var scores = MyTextBox("Score: ");
    scores.position = Vector2(screenX + 10, 30);
    add(scores);

    updateScoreStats();
    // showScoreBanner();
  }

  void updateScoreStats() {
    if (scoreText != null) {
      remove(scoreText);
    }

    scoreText = MyTextBox(score.toString().padLeft(6, '0'));
    scoreText.position = Vector2(screenX + 80, 30);
    add(scoreText);
  }

  void generateVirusBoard() {
    int virusCount = 3 + level * 3;
    int rows = 1 + level;
    List<Tuple2<int, int>> cells = [];

    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x < 8; x++) {
        cells.add(Tuple2(15 - y, x));
      }
    }

    while (virusCount > 0) {
      var cellIndex = random.nextInt(cells.length);
      var cell = cells[cellIndex];
      cells.removeAt(cellIndex);
      var rand = random.nextInt(VirusType.values.length);
      var position =
          Vector2(screenX + cell.item2 * 26.0, screenY + cell.item1 * 26.0);
      final virus = createVirus(cell.item1, cell.item2, VirusType.values[rand]);
      board.add(virus);

      virus.component().position = position;
      add(virus.component());
      virusCount--;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    bgLayer.render(canvas);
  }

  @override
  void onTap() {
    pillObject.toggleDirection();
  }

  @override
  void onHorizontalDragStart(DragStartDetails details) {
    currentOffset = details.globalPosition;
  }

  @override
  void onHorizontalDragUpdate(DragUpdateDetails details) {
    if (speedFall || currentOffset == null) {
      return;
    }
    var tmp = (details.globalPosition.dx - currentOffset.dx) / 24.0;
    if (tmp > 1) {
      pillDeltaX = tmp;
      currentOffset = details.globalPosition;
    } else if (tmp < -1) {
      currentOffset = details.globalPosition;
      pillDeltaX = tmp;
    }

    if (details.globalPosition.dy - currentOffset.dy > 24.0) {
      currentOffset = details.globalPosition;
      speedFall = true;
    }
  }

  @override
  void onHorizontalDragEnd(DragEndDetails details) {}

  @override
  void update(double t) {
    super.update(t);
    if (freeze) {
      return;
    }
    time += t;
    if (pillDeltaX != 0.0) {
      pillObject.moveHorizontal(pillDeltaX.round());
      pillDeltaX = 0.0;
    }

    if (time > 1 || speedFall) {
      if (!pillObject.moveDown()) {
        var frozen = FrozenPill.from(board, pillObject);
        board.add(frozen);
        checkBoardState(pillObject.currentPosition());
        dropNewPill();
      }
      time = 0.0;
    }
    pillObject.spriteComponent.position[0] = screenX + pillObject.x * 26.0;
    pillObject.spriteComponent.position[1] = screenY + pillObject.y * 26.0;
  }

  void dropNewPill() {
    var randomPill = random.nextInt(pills.possibleColors.length);

    var pillColors = pills.possibleColors[randomPill];
    var pillComponent = pills.forColors(pillColors);

    pillComponent.position = Vector2(screenX, 50.0);
    pillObject = PillObject(3, 0, pillComponent, board, pillColors);
    speedFall = false;
    currentOffset = null;

    santa.reset();

    var pillthrow = SpriteAnimation.fromFrameData(
        images.fromCache('pill_throw_sheet.png'),
        SpriteAnimationData.sequenced(
            amount: 9,
            textureSize: Vector2(150.0, 53.0),
            stepTime: 0.05,
            loop: false,
            texturePosition: Vector2(0, 53.0 * (5 - randomPill))));

    freeze = true;
    var throwcomponent =
        FiniteAnimationComponent(Vector2(100, 53), pillthrow, () {
      add(pillComponent);
      freeze = false;
    });
    throwcomponent.position = Vector2(200.0, 30.0);
    add(throwcomponent);
  }

  void showScoreBanner(int score) {
    int shift = min(score ~/ 100, 5);
    var scores = SpriteAnimation.fromFrameData(
        images.fromCache('scores_animation.png'),
        SpriteAnimationData.sequenced(
            amount: 9,
            textureSize: Vector2(46.0, 32.0),
            stepTime: 0.07,
            loop: false,
            texturePosition: Vector2(0, 32.0 * (shift - 1))));
    var component = SpriteAnimationComponent(Vector2(92.0, 64.0), scores,
        removeOnFinish: true);
    component.position = Vector2(150.0, 270.0);
    add(component);
  }

  void checkBoardState(List<List<int>> positions) {
    List<List<int>> toDelete = [];
    for (List<int> pos in positions) {
      List<List<int>> row = [];
      row.add(pos);
      int y = pos[0] - 1;
      while (y >= 0 && board.board[y][pos[1]] == pos[2]) {
        row.add([y--, pos[1]]);
      }
      y = pos[0] + 1;
      while (y <= 15 && board.board[y][pos[1]] == pos[2]) {
        row.add([y++, pos[1]]);
      }

      if (row.length >= 4) {
        toDelete.addAll(row);
      }

      row = [];
      row.add(pos);
      int x = pos[1] - 1;
      while (x >= 0 && board.board[pos[0]][x] == pos[2]) {
        row.add([pos[0], x--]);
      }
      x = pos[1] + 1;
      while (x <= 7 && board.board[pos[0]][x] == pos[2]) {
        row.add([pos[0], x++]);
      }

      if (row.length >= 4) {
        toDelete.addAll(row);
      }
    }

    List<SpriteAnimationComponent> animations = [];

    Set<int> colors = HashSet();
    int virusesCount = 0;

    for (List<int> delete in toDelete) {
      var deathcell = createDethCellComponent();
      deathcell.position =
          Vector2(screenX + delete[1] * 26.0, screenY + delete[0] * 26.0);
      add(deathcell);
      animations.add(deathcell);

      if (board.componentsBoard[delete[0]][delete[1]] != null) {
        colors.add(board.getColor(delete[0], delete[1]));
        if (board.componentsBoard[delete[0]][delete[1]] is Virus) {
          virusesCount += 1;
        }

        var obj = board.remove(delete[0], delete[1]);
        if (obj != null) {
          remove(obj.component());
        }

        for (List<int> p in obj.currentPosition()) {
          if (!toDelete.any((c) => c[0] == p[0] && c[1] == p[1])) {
            // this is extreamly inefficient
            var replacement = createHalfPill(p[0], p[1], p[2]);
            board.add(replacement);
            replacement.component().position =
                Vector2(screenX + p[1] * 26.0, screenY + p[0] * 26.0);
            add(replacement.component());
          }
        }
      }
    }

    if (animations.length != 0) {
      var scoreIncrease = colors.length * 100 + virusesCount * 100;
      score += scoreIncrease;
      showScoreBanner(scoreIncrease);
      updateScoreStats();
      add(FiniteAnimation(animations, () {
        Set<GameObject> fallen = board.freeFall();
        if (fallen.length != 0) {
          List<List<int>> tmp = [];
          var positions =
              fallen.forEach((c) => tmp.addAll(c.currentPosition()));
          checkBoardState(tmp);
        }
      }));
    }
  }

  Color randomMaterialColor() {
    return Colors.primaries[random.nextInt(Colors.primaries.length)];
  }

  Particle fireworkParticle() {
    // A pallete to paint over the "sky"
    final List<Paint> paints = [
      Colors.amber,
      Colors.amberAccent,
      Colors.red,
      Colors.redAccent,
      Colors.yellow,
      Colors.yellowAccent,
      // Adds a nice "lense" tint
      // to overall effect
      Colors.blue,
    ].map<Paint>((color) => Paint()..color = color).toList();

    return Particle.generate(
      count: 10,
      generator: (i) {
        final initialSpeed = randomCellOffset();
        final deceleration = initialSpeed * -1;
        const gravity = const Offset(0, 40);

        return AcceleratedParticle(
          speed: initialSpeed,
          acceleration: deceleration + gravity,
          child: ComputedParticle(renderer: (canvas, particle) {
            final paint = randomElement(paints);
            // Override the color to dynamically update opacity
            paint.color = paint.color.withOpacity(1 - particle.progress);

            canvas.drawCircle(
              Offset.zero,
              // Closer to the end of lifespan particles
              // will turn into larger glaring circles
              random.nextDouble() * particle.progress > .6
                  ? random.nextDouble() * (50 * particle.progress)
                  : 2 + (3 * particle.progress),
              paint,
            );
          }),
        );
      },
    );
  }

  T randomElement<T>(List<T> list) {
    return list[random.nextInt(list.length)];
  }

  Offset randomCellOffset() {
    return Offset(
      cellSize.x * random.nextDouble() - halfCellSize.x,
      cellSize.y * random.nextDouble() - halfCellSize.y,
    );
  }
}

TextConfig regular = TextConfig(color: BasicPalette.white.color);
TextConfig tiny = regular.withFontSize(18.0);

class MyTextBox extends TextBoxComponent {
  MyTextBox(String text)
      : super(
          text,
          config: tiny,
          boxConfig: TextBoxConfig(
            timePerChar: 0.00,
            growingBox: true,
            margins: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          ),
        );

  @override
  void drawBackground(Canvas c) {
    final Rect rect = Rect.fromLTWH(0, 0, width, height);
    c.drawRect(rect, Paint()..color = const Color(0xffa07850));
  }
}

class BackgroundLayer extends PreRenderedLayer {
  final Sprite sprite;
  double screenX, screenY;

  BackgroundLayer(this.sprite, this.screenX, this.screenY);

  @override
  void drawLayer() {
    sprite.render(canvas,
        position: Vector2(screenX - 15, screenY - 75), size: Vector2(300, 500));
  }
}
