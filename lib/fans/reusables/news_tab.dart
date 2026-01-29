import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';

class NewsTab extends StatelessWidget {
  final String leagueId;

  const NewsTab({
    super.key,
    required this.leagueId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.newspaper_outlined,
            size: eqW(48),
            color: kGrey2,
          ),
          SizedBox(height: eqW(12)),
          Text(
            'Coming Soon',
            style: kText14White.copyWith(
              fontWeight: FontWeight.w600,
              color: kGrey2,
            ),
          ),
        
        ],
      ),
    );
  }
}
