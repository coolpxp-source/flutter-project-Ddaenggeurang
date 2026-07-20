import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  static String get _kakaoApiKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 꺼져 있어요. 설정에서 켜주세요.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 필요해요.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부됐어요. 설정에서 직접 허용해주세요.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<String> reverseGeocodeToDong(double lat, double lng) async {
    final url = Uri.parse(
      'https://dapi.kakao.com/v2/local/geo/coord2address.json?x=$lng&y=$lat',
    );

    final response = await http.get(
      url,
      headers: {'Authorization': 'KakaoAK $_kakaoApiKey'},
    );

    if (response.statusCode != 200) {
      throw Exception('주소 변환 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final documents = data['documents'] as List;
    if (documents.isEmpty) {
      throw Exception('이 위치의 주소를 찾을 수 없어요.');
    }

    final address = documents.first['address'];
    // 시/도 + 시/군/구 + 동/읍/면 조합 (예: "인천 미추홀구 주안동")
    final region1 = address['region_1depth_name']; // 시/도
    final region2 = address['region_2depth_name']; // 시/군/구
    final region3 = address['region_3depth_name']; // 동/읍/면

    return '$region1 $region2 $region3';
  }
}