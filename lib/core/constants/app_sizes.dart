import 'package:flutter/widgets.dart';

/// Spacing tokens (4px baseline grid).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double gutter = 12;
  static const double md = 16;
  static const double mobileMargin = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radius tokens.
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 9999;

  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusXl = Radius.circular(xl);

  static const BorderRadius brXs = BorderRadius.all(radiusXs);
  static const BorderRadius brSm = BorderRadius.all(radiusSm);
  static const BorderRadius brMd = BorderRadius.all(radiusMd);
  static const BorderRadius brLg = BorderRadius.all(radiusLg);
  static const BorderRadius brXl = BorderRadius.all(radiusXl);
}

/// Common icon sizes.
class AppIconSize {
  AppIconSize._();

  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

/// Common element heights.
class AppDimens {
  AppDimens._();

  static const double appBarHeight = 64;
  static const double bottomNavHeight = 72;
  static const double buttonHeight = 48;
  static const double inputHeight = 52;
  static const double listTileHeight = 80;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 96;

  static const double maxContentWidth = 600;
}
