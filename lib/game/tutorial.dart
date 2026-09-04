import 'combos.dart';
import 'weapons.dart';

/// What the sparring dummy does during a lesson.
enum DummyMode { still, guards, attacks }

/// What counts toward a lesson's goal.
enum LessonGoal { walk, hit, openHit, strokes, block, parry, stepBack, advance, smash }

/// One step of the dojo tutorial: what to do, how to do it, and the dummy's
/// behaviour while it is practised.
class Lesson {
  const Lesson({
    required this.title,
    required this.text,
    required this.goal,
    required this.target,
    required this.unit,
    this.left,
    this.right,
    this.dummy = DummyMode.still,
  });

  final String title;

  /// One or two lines shown at the top of the arena.
  final String text;
  final LessonGoal goal;
  final int target;
  final String unit;

  /// Stick directions to show on the banner (null = any / not used).
  final Dir? left, right;
  final DummyMode dummy;

  static const all = [
    Lesson(
      title: 'MOVE',
      text: 'Push the LEFT stick alone to walk. Your fighter always faces the enemy.',
      goal: LessonGoal.walk,
      target: 3,
      unit: 'steps',
    ),
    Lesson(
      title: 'ATTACK',
      text: 'Hold BOTH sticks toward the enemy and keep holding: every cycle is a new strike.',
      goal: LessonGoal.hit,
      target: 3,
      unit: 'hits',
      left: Dir.fwd,
      right: Dir.fwd,
    ),
    Lesson(
      title: 'AIM',
      text: 'LEFT stick height picks the target: ▲ head, ► body, ▼ legs. Hit the OPEN zone.',
      goal: LessonGoal.openHit,
      target: 3,
      unit: 'open hits',
      dummy: DummyMode.guards,
    ),
    Lesson(
      title: 'STROKES',
      text: 'RIGHT stick picks the stroke: ▲ leap and smash, ► cut, ▼ kick. Land all three.',
      goal: LessonGoal.strokes,
      target: 3,
      unit: 'strokes',
    ),
    Lesson(
      title: 'BLOCK',
      text: 'LEFT stick AWAY from the enemy + RIGHT stick at the height of the incoming blow.',
      goal: LessonGoal.block,
      target: 3,
      unit: 'blocks',
      left: Dir.back,
      right: Dir.up,
      dummy: DummyMode.attacks,
    ),
    Lesson(
      title: 'PARRY',
      text: 'Block with the RIGHT stick angled at the enemy (◥ high, ◢ low): no damage, and they stagger.',
      goal: LessonGoal.parry,
      target: 2,
      unit: 'parries',
      left: Dir.back,
      right: Dir.upFwd,
      dummy: DummyMode.attacks,
    ),
    Lesson(
      title: 'STEP BACK',
      text: 'BOTH sticks away from the enemy to retreat. ▲ hops, ▼ slides.',
      goal: LessonGoal.stepBack,
      target: 3,
      unit: 'steps',
      left: Dir.back,
      right: Dir.back,
    ),
    Lesson(
      title: 'GUARD ADVANCE',
      text: 'LEFT stick toward the enemy + RIGHT stick away: close in behind your guard.',
      goal: LessonGoal.advance,
      target: 3,
      unit: 'steps',
      left: Dir.fwd,
      right: Dir.back,
      dummy: DummyMode.attacks,
    ),
    Lesson(
      title: 'SKULL SMASH',
      text: 'LEFT ▲ + RIGHT ▲: the leaping smash. Unblockable while charged, then it recharges.',
      goal: LessonGoal.smash,
      target: 1,
      unit: 'smash',
      left: Dir.up,
      right: Dir.up,
      dummy: DummyMode.guards,
    ),
  ];
}

/// Progress through the tutorial while sparring in the dojo.
class Practice {
  Practice({this.index = 0});

  int index;
  int progress = 0;

  /// Seconds since the current lesson was completed (the banner celebrates,
  /// then the next lesson starts).
  double doneT = -1;

  /// Distinct strokes landed for the STROKES lesson.
  final Set<String> strokes = {};

  /// Distance walked for the MOVE lesson.
  double walked = 0;

  Lesson get lesson => Lesson.all[index];
  bool get finished => index >= Lesson.all.length;
  bool get lessonDone => doneT >= 0;

  /// Counts one unit toward the goal; returns true when the lesson is done.
  bool score([int n = 1]) {
    if (lessonDone) return false;
    progress = (progress + n).clamp(0, lesson.target);
    if (progress >= lesson.target) {
      doneT = 0;
      return true;
    }
    return false;
  }

  void nextLesson() {
    index++;
    progress = 0;
    doneT = -1;
    strokes.clear();
    walked = 0;
  }
}

/// A stroke's family, for the STROKES lesson.
String strokeFamily(MoveSpec m) => switch (m.kind) {
      MoveKind.heavy => 'smash',
      MoveKind.kick => 'kick',
      _ => 'cut',
    };
