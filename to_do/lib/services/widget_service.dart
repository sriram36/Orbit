import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String _androidWidgetName = 'HomeWidgetProvider';

  static Future<void> updateStreak(int streak) async {
    await HomeWidget.saveWidgetData<int>('streak', streak);
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  }
}
