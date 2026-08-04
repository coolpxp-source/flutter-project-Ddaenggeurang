import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsultationAdService {
  RewardedAd? _rewardedAd;
  static  int _adWatchCount = 0;
  static  String _adWatchDate = '';

  static const int maxAdWatchesPerDay = 3;

  void _resetIfNewDay() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_adWatchDate != today) {
      _adWatchDate = today;
      _adWatchCount = 0;
    }
  }

  bool get canWatchAd {
    _resetIfNewDay();
    return _adWatchCount < maxAdWatchesPerDay;
  }

  int get adWatchesRemaining {
    _resetIfNewDay();
    return maxAdWatchesPerDay - _adWatchCount;
  }

  void loadAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // 테스트용 ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ 광고 로드 성공');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('🔥 광고 로드 실패: $error');
        },
      ),
    );
  }

  void showAd({
    required VoidCallback onRewarded,
    VoidCallback? onLimitReached,
  }) {
    _resetIfNewDay();

    if (!canWatchAd) {
      onLimitReached?.call();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('광고가 아직 준비되지 않았어요');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('📺 광고 닫힘');
        ad.dispose();
        _rewardedAd = null;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        debugPrint('광고 표시 실패: $error');
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('🎁 보상 지급됨!');
        _adWatchCount++;
        onRewarded();
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}