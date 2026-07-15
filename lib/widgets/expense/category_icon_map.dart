import 'package:flutter/material.dart';

/// 카테고리 소분류 이름 → 아이콘 매핑.
/// 여기 없는 이름은 fallback 아이콘(Icons.category_outlined)으로 표시됨.
class CategoryIconMap {
  static const Map<String, IconData> _icons = {
    // 고정비 - 주거비
    '월세': Icons.house_outlined,
    '관리비': Icons.apartment_outlined,
    '공과금': Icons.receipt_long_outlined,

    // 고정비 - 통신비
    '휴대폰요금': Icons.phone_iphone,
    '인터넷': Icons.wifi,

    // 고정비 - 금융/보험
    '대출이자': Icons.account_balance_outlined,
    '보험료': Icons.shield_outlined,

    // 고정비 - 정기구독
    'OTT': Icons.live_tv_outlined,
    '음원스트리밍': Icons.music_note_outlined,
    '정기후원': Icons.volunteer_activism_outlined,

    // 변동비 - 식비
    '식사': Icons.restaurant_outlined,
    '카페/디저트': Icons.local_cafe_outlined,
    '마트/장보기': Icons.shopping_cart_outlined,
    '편의점': Icons.local_convenience_store_outlined,

    // 변동비 - 교통/차량
    '대중교통': Icons.directions_bus_outlined,
    '택시': Icons.local_taxi_outlined,
    '주유': Icons.local_gas_station_outlined,
    '주차/통행료': Icons.local_parking_outlined,
    '차량정비': Icons.car_repair_outlined,

    // 변동비 - 패션/미용
    '의류/잡화': Icons.checkroom_outlined,
    '화장품': Icons.face_retouching_natural_outlined,
    '미용실': Icons.content_cut_outlined,

    // 변동비 - 생활/쇼핑
    '생필품': Icons.cleaning_services_outlined,
    '전자기기': Icons.devices_other_outlined,

    // 변동비 - 문화/여가
    '영화/공연': Icons.theaters_outlined,
    '일반도서': Icons.menu_book_outlined,
    '운동': Icons.fitness_center_outlined,
    '여행/숙박': Icons.flight_takeoff_outlined,
    '게임/취미': Icons.sports_esports_outlined,

    // 변동비 - 건강/의료
    '병원': Icons.local_hospital_outlined,
    '약국': Icons.local_pharmacy_outlined,
    '영양제': Icons.medication_outlined,

    // 변동비 - 교육/학습
    '학원비': Icons.school_outlined,
    '인터넷강의': Icons.laptop_outlined,
    '시험응시료': Icons.edit_document,
    '교재/수험서': Icons.auto_stories_outlined,

    // 기타 - 경조사/선물
    '축의금/조의금': Icons.card_giftcard_outlined,
    '생일선물': Icons.cake_outlined,
    '명절용돈': Icons.redeem_outlined,
    '일회성기부': Icons.favorite_outline,

    // 기타 - 미분류
    '기타': Icons.help_outline,
  };

  static IconData iconFor(String name) => _icons[name] ?? Icons.category_outlined;
}