import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';

class CuratedTemplates {
  static List<Routine> hypertrophy() => [
        Routine(
          routineName: 'Hypertrophy Beginner (Full Body)',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          createdDate: DateTime.now(),
          parts: [
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.Chest,
              exercises: [
                const Exercise(name: 'Dumbbell Bench Press', weight: 20, sets: 3, reps: '8-12', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Chest),
              ],
              partName: 'Chest',
            ),
            Part(
              setType: SetType.Super,
              targetedBodyPart: TargetedBodyPart.Back,
              exercises: [
                const Exercise(name: 'One-Arm Row', weight: 18, sets: 3, reps: '8-12', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Back),
                const Exercise(name: 'Lat Pulldown', weight: 35, sets: 3, reps: '10-12', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Back),
              ],
              partName: 'Back Superset',
            ),
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.Leg,
              exercises: [
                const Exercise(name: 'Goblet Squat', weight: 24, sets: 3, reps: '10-12', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Leg),
              ],
              partName: 'Legs',
            ),
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.Shoulder,
              exercises: [
                const Exercise(name: 'Lateral Raise', weight: 6, sets: 3, reps: '12-15', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Shoulder),
              ],
              partName: 'Shoulders',
            ),
          ],
          weekdays: [2, 5],
          routineHistory: const [],
        ),
        Routine(
          routineName: 'Hypertrophy Intermediate (Push/Pull/Legs)',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          createdDate: DateTime.now(),
          parts: [
            Part(
              setType: SetType.Tri,
              targetedBodyPart: TargetedBodyPart.Chest,
              exercises: [
                const Exercise(name: 'Bench Press', weight: 40, sets: 4, reps: '6-10', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Chest),
                const Exercise(name: 'Incline DB Press', weight: 24, sets: 3, reps: '8-12', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Chest),
                const Exercise(name: 'Dip', weight: 0, sets: 3, reps: 'AMRAP', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Chest),
              ],
              partName: 'Push',
            ),
          ],
          weekdays: [1, 3, 5],
          routineHistory: const [],
        ),
      ];

  static List<Routine> strength() => [
        Routine(
          routineName: 'Strength Beginner (Full Body)',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          createdDate: DateTime.now(),
          parts: [
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.Leg,
              exercises: [
                const Exercise(name: 'Back Squat', weight: 50, sets: 3, reps: '5', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Leg),
              ],
              partName: 'Squat',
            ),
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.Back,
              exercises: [
                const Exercise(name: 'Deadlift', weight: 60, sets: 1, reps: '5', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Back),
              ],
              partName: 'Deadlift',
            ),
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.Chest,
              exercises: [
                const Exercise(name: 'Bench Press', weight: 40, sets: 3, reps: '5', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.Chest),
              ],
              partName: 'Bench',
            ),
          ],
          weekdays: [2, 5],
          routineHistory: const [],
        ),
      ];

  static List<Routine> fatLoss() => [
        Routine(
          routineName: 'Fat Loss Beginner (Circuit)',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          createdDate: DateTime.now(),
          parts: [
            Part(
              setType: SetType.Giant,
              targetedBodyPart: TargetedBodyPart.FullBody,
              exercises: const [
                Exercise(name: 'KB Swing', weight: 16, sets: 4, reps: '15', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.FullBody),
                Exercise(name: 'Burpee', weight: 0, sets: 4, reps: '12', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.FullBody),
                Exercise(name: 'Mountain Climbers', weight: 0, sets: 4, reps: '30', workoutType: WorkoutType.Weight, primaryTarget: TargetedBodyPart.FullBody),
                Exercise(name: 'Row (Cardio)', weight: 0, sets: 4, reps: '60', workoutType: WorkoutType.Cardio, primaryTarget: TargetedBodyPart.FullBody),
              ],
              partName: 'Circuit',
            ),
          ],
          weekdays: [2, 4, 6],
          routineHistory: const [],
        ),
      ];
}

