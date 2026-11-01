import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatNewspaperDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60 && !difference.isNegative) {
      return 'Just now';
    } else if (difference.inMinutes < 60 && !difference.isNegative) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && !difference.isNegative) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7 && !difference.isNegative) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  static String formatArticleDateTime(DateTime dateTime) {
    return DateFormat('MMMM d, yyyy • h:mm a').format(dateTime);
  }
}
