import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/year_end_simulation_model.dart';

class YearEndSimulationService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String userId) =>
      _db.collection('users').doc(userId).collection('yearEndSimulations');

  Future<void> saveSimulation({
    required String userId,
    required YearEndSimulationModel simulation,
  }) async {
    await _ref(userId).add(simulation.toFirestore());
  }

  Stream<List<YearEndSimulationModel>> getSimulations({required String userId}) {
    return _ref(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => YearEndSimulationModel.fromFirestore(d)).toList());
  }
}