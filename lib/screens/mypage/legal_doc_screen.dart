import 'package:flutter/material.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);

/// 이용약관 / 개인정보 처리방침처럼 제목 + 섹션 본문으로 구성된
/// 정적 법률 문서를 보여주는 공용 화면.
///
/// TODO: 아래 [kTermsOfService], [kPrivacyPolicy] 문구는 법무 검토 전
/// 임시 초안입니다. 실제 서비스 배포 전 법무 검토를 거쳐 교체해주세요.
class LegalDocScreen extends StatelessWidget {
  final String title;
  final String updatedAt;
  final List<LegalSection> sections;

  const LegalDocScreen({
    super.key,
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('시행일 $updatedAt',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _inkSub)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  Text(sections[i].heading,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 8),
                  Text(sections[i].body,
                      style: const TextStyle(
                          fontSize: 13, height: 1.7, fontWeight: FontWeight.w500, color: Color(0xFF5B5049))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, size: 14, color: _accent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '본 문서는 서비스 준비 단계의 임시 초안이에요. 정식 서비스 전 법무 검토를 거칠 예정이에요.',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSub),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

const String kLegalUpdatedAt = '2026.07.15';

final List<LegalSection> kTermsOfService = [
  const LegalSection('제1조 (목적)',
      '이 약관은 땡그랑(이하 "회사")이 제공하는 가계부 및 소비 관리 서비스(이하 "서비스")의 이용과 관련하여 '
          '회사와 이용자의 권리, 의무 및 책임사항을 정하는 것을 목적으로 합니다.'),
  const LegalSection('제2조 (서비스의 제공)',
      '회사는 이용자에게 수입/지출 기록, 예산 관리, 소비 성향 분석, 커뮤니티, AI 코치 상담 등의 기능을 제공합니다. '
          '서비스의 내용은 회사 사정에 따라 변경될 수 있으며, 중요한 변경 사항은 사전에 공지합니다.'),
  const LegalSection('제3조 (회원가입)',
      '이용자는 이메일 또는 소셜 계정(카카오, 네이버, 구글, 애플)을 통해 회원가입을 신청할 수 있으며, '
          '이메일로 가입한 경우 이메일 인증을 완료해야 서비스를 정상적으로 이용할 수 있습니다.'),
  const LegalSection('제4조 (이용자의 의무)',
      '이용자는 관계 법령, 이 약관의 규정, 이용안내 및 서비스와 관련하여 공지한 주의사항을 준수해야 하며, '
          '타인의 정보를 도용하거나 허위 정보를 등록해서는 안 됩니다.'),
  const LegalSection('제5조 (계약 해지)',
      '이용자는 언제든지 설정 화면의 회원탈퇴 기능을 통해 이용계약을 해지할 수 있으며, '
          '탈퇴 시 관련 법령 및 개인정보 처리방침에 따라 보관되는 정보를 제외한 모든 기록이 삭제됩니다.'),
];

final List<LegalSection> kPrivacyPolicy = [
  const LegalSection('1. 수집하는 개인정보 항목',
      '회사는 회원가입 시 이메일, 닉네임, 연령대, 직군, 월 소득 구간 등을 수집하며, '
          '서비스 이용 과정에서 수입/지출 기록, 소비 성향 테스트 결과 등이 추가로 저장될 수 있습니다.'),
  const LegalSection('2. 개인정보의 수집 및 이용 목적',
      '수집된 정보는 회원 식별, 서비스 제공 및 개인화(AI 코치 잔소리·상담 등), 부정 이용 방지, '
          '고객 문의 응대를 위해 사용되며 명시된 목적 외 용도로 사용되지 않습니다.'),
  const LegalSection('3. 개인정보의 보유 및 이용 기간',
      '이용자의 개인정보는 회원 탈퇴 시까지 보유하며, 탈퇴 즉시 파기됩니다. '
          '단, 관계 법령에 따라 보존이 필요한 정보는 해당 기간 동안 별도 보관합니다.'),
  const LegalSection('4. 개인정보의 제3자 제공',
      '회사는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않으며, 법령에 근거가 있거나 '
          '이용자가 사전에 동의한 경우에 한하여 제공합니다.'),
  const LegalSection('5. 이용자의 권리',
      '이용자는 언제든지 자신의 개인정보를 열람·수정할 수 있으며, 회원탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.'),
];
