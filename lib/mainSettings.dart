
import 'package:flutter_riverpod/flutter_riverpod.dart';



final darkTheme = StateProvider((ref) => true);
final lang = StateProvider((ref)=> "en");
final themeChangeState = Provider.autoDispose((ref) {

  //
});