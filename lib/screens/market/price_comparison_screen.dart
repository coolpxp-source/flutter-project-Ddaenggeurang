import 'package:flutter/material.dart';
import '../../models/market_product_model.dart';

class PriceComparisonScreen extends StatelessWidget {
  final MarketProduct product;
  const PriceComparisonScreen({super.key, required this.product});

  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);

  @override
  Widget build(BuildContext context) {
    // 내 상품 가격 포함해서 정렬 (낮은 가격순)
    final allPrices = [
      PriceComparison(source: '땡그랑 마켓 (이 상품)', price: product.price, url: ''),
      ...product.priceComparisons,
    ]..sort((a, b) => a.price.compareTo(b.price));

    final lowestPrice = allPrices.first.price;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('가격 비교', style: TextStyle(color: Colors.black)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(product.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${allPrices.length}개 쇼핑몰 가격 비교',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 20),

          if (product.priceComparisons.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('아직 등록된 가격 비교 정보가 없어요',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...allPrices.map((item) {
              final isLowest = item.price == lowestPrice;
              final isThisProduct = item.source.contains('이 상품');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLowest ? _greenLight : Colors.white,
                  border: Border.all(
                    color: isLowest ? _green : Colors.grey[200]!,
                    width: isLowest ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(item.source,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isThisProduct ? FontWeight.bold : FontWeight.normal,
                                  )),
                              if (isLowest) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _green,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('최저가',
                                      style: TextStyle(fontSize: 10, color: Colors.white)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('${item.price}원',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isLowest ? _green : Colors.black,
                              )),
                        ],
                      ),
                    ),
                    if (!isThisProduct && item.url.isNotEmpty)
                      Icon(Icons.open_in_new, size: 16, color: Colors.grey[400]),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}