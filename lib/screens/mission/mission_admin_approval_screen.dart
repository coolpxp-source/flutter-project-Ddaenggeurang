import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/mission_service.dart';

class MissionAdminApprovalScreen extends StatefulWidget {
  const MissionAdminApprovalScreen({super.key});

  @override
  State<MissionAdminApprovalScreen> createState() =>
      _MissionAdminApprovalScreenState();
}

class _MissionAdminApprovalScreenState
    extends State<MissionAdminApprovalScreen> {
  final MissionService _missionService = MissionService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingProofs = [];

  void _showProofImage(
      String imageUrl,
      ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (
                          context,
                          error,
                          stackTrace,
                          ) {
                        return const Center(
                          child: Text(
                            '이미지를 불러올 수 없습니다.',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPendingProofs();
  }

  Future<void> _loadPendingProofs() async {
    try {
      final proofs =
      await _missionService.getPendingMissionVerifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingProofs = proofs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '승인 대기 목록을 불러오지 못했습니다: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F8),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '미션 인증 관리',
          style: TextStyle(
            color: Color(0xFF252735),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _pendingProofs.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: _pendingProofs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _buildProofCard(_pendingProofs[index]);
        },
      ),
    );
  }

  Future<void> _approveProof(
      Map<String, dynamic> proof,
      ) async {
    final verificationId =
    proof['id'] as String;

    final success =
    await _missionService
        .approveMissionVerification(
      verificationId,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '미션 인증 승인에 실패했습니다.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _pendingProofs.removeWhere(
            (item) =>
        item['id'] == verificationId,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '미션 인증을 승인했습니다.',
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(
      Map<String, dynamic> proof,
      ) async {
    final reasonController = TextEditingController();

    final String? rejectReason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '인증 반려',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '반려 사유를 입력해 주세요.',
                style: TextStyle(
                  color: Color(0xFF6F7280),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 4,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: '예: 미션과 관련된 사진이 아닙니다.',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0B2BA),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF68AE),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF888B96),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason =
                reasonController.text.trim();

                if (reason.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  reason,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFE65C5C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: const Text('반려하기'),
            ),
          ],
        );
      },
    );

    if (rejectReason == null ||
        rejectReason.isEmpty ||
        !mounted) {
      return;
    }

    final success =
    await _missionService
        .rejectMissionVerification(
      verificationId: proof['id'] as String,
      reason: rejectReason,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '미션 인증 반려에 실패했습니다.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _pendingProofs.removeWhere(
            (item) => item['id'] == proof['id'],
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '미션 인증을 반려했습니다.',
        ),
      ),
    );
  }

  Widget _buildProofCard(Map<String, dynamic> proof) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFFFEAF3),
                child: Icon(
                  Icons.person,
                  color: Color(0xFFFF68AE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proof['nickname'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proof['submittedAt'] as String,
                      style: const TextStyle(
                        color: Color(0xFF999CA7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '승인 대기',
                  style: TextStyle(
                    color: Color(0xFFE89B24),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              _showProofImage(
                proof['imageUrl'] as String,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  proof['imageUrl'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (
                      context,
                      error,
                      stackTrace,
                      ) {
                    return Container(
                      color: const Color(0xFFF0F1F5),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF999CA7),
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            proof['missionTitle'] as String,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            proof['description'] as String,
            style: const TextStyle(
              color: Color(0xFF6F7280),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showRejectDialog(proof);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE65C5C),
                    side: const BorderSide(
                      color: Color(0xFFFFC9C9),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '반려',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveProof(proof),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF68AE),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '승인',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 56,
            color: Color(0xFFB4B6C0),
          ),
          SizedBox(height: 14),
          Text(
            '승인 대기 중인 인증이 없어요.',
            style: TextStyle(
              color: Color(0xFF777A86),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}