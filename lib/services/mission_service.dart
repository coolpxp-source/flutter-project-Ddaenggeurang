import '../models/mission_definition_model.dart';

class MissionService {
  Future<List<MissionDefinition>> getMissions() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return const [
      MissionDefinition(
        id: 'attendance_daily',
        title: '오늘 출석하기',
        type: 'attendance',
        points: 10,
        frequency: 'daily',
        requiresApproval: false,
        isActive: true,
      ),
      MissionDefinition(
        id: 'expense_record_daily',
        title: '오늘 지출 기록하기',
        type: 'writing',
        points: 20,
        frequency: 'daily',
        requiresApproval: false,
        isActive: true,
      ),
      MissionDefinition(
        id: 'saving_photo',
        title: '절약 인증 사진 올리기',
        type: 'photo_proof',
        points: 30,
        frequency: 'once',
        requiresApproval: true,
        isActive: true,
      ),
    ];
  }
  Future<bool> checkAttendance() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}