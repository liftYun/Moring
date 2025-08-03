import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'home_content.dart';

class HomePage extends ConsumerWidget {
  final Car? car;
  const HomePage({Key? key, this.car}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeContent(car: car);
  }
}
