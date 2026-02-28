import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/open_router_service.dart';

// Top-level function for compute()
List<Routine> parseRoutinesOnIsolate(String json) {
  final svc = OpenRouterService(apiKey: '');
  return svc.parseRoutinesFromJsonString(json);
}

