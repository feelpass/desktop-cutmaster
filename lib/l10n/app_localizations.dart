import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'합판 재단'**
  String get appTitle;

  /// No description provided for @calculate.
  ///
  /// In ko, this message translates to:
  /// **'계산'**
  String get calculate;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @newProject.
  ///
  /// In ko, this message translates to:
  /// **'새 프로젝트'**
  String get newProject;

  /// No description provided for @parts.
  ///
  /// In ko, this message translates to:
  /// **'부품'**
  String get parts;

  /// No description provided for @stockSheets.
  ///
  /// In ko, this message translates to:
  /// **'자재'**
  String get stockSheets;

  /// No description provided for @options.
  ///
  /// In ko, this message translates to:
  /// **'옵션'**
  String get options;

  /// No description provided for @kerf.
  ///
  /// In ko, this message translates to:
  /// **'톱날 두께(mm)'**
  String get kerf;

  /// No description provided for @lockGrain.
  ///
  /// In ko, this message translates to:
  /// **'결방향 고정'**
  String get lockGrain;

  /// No description provided for @showPartLabels.
  ///
  /// In ko, this message translates to:
  /// **'부품 라벨 표시'**
  String get showPartLabels;

  /// No description provided for @useSingleSheet.
  ///
  /// In ko, this message translates to:
  /// **'단일 시트 사용'**
  String get useSingleSheet;

  /// No description provided for @emptyResultTitle.
  ///
  /// In ko, this message translates to:
  /// **'자재와 부품을 입력하고'**
  String get emptyResultTitle;

  /// No description provided for @emptyResultAction.
  ///
  /// In ko, this message translates to:
  /// **'▶ 계산 버튼을 눌러주세요'**
  String get emptyResultAction;

  /// No description provided for @length.
  ///
  /// In ko, this message translates to:
  /// **'가로'**
  String get length;

  /// No description provided for @width.
  ///
  /// In ko, this message translates to:
  /// **'세로'**
  String get width;

  /// No description provided for @qty.
  ///
  /// In ko, this message translates to:
  /// **'수량'**
  String get qty;

  /// No description provided for @label.
  ///
  /// In ko, this message translates to:
  /// **'라벨'**
  String get label;

  /// No description provided for @preset.
  ///
  /// In ko, this message translates to:
  /// **'프리셋'**
  String get preset;

  /// No description provided for @efficiency.
  ///
  /// In ko, this message translates to:
  /// **'효율'**
  String get efficiency;

  /// No description provided for @sheetUsed.
  ///
  /// In ko, this message translates to:
  /// **'{n}장 사용'**
  String sheetUsed(int n);

  /// No description provided for @partsCount.
  ///
  /// In ko, this message translates to:
  /// **'{n}개 부품'**
  String partsCount(int n);

  /// No description provided for @unplacedCount.
  ///
  /// In ko, this message translates to:
  /// **'{n}개 미배치'**
  String unplacedCount(int n);

  /// No description provided for @exportPng.
  ///
  /// In ko, this message translates to:
  /// **'PNG 내보내기'**
  String get exportPng;

  /// No description provided for @exportPdf.
  ///
  /// In ko, this message translates to:
  /// **'PDF 내보내기'**
  String get exportPdf;

  /// No description provided for @materialUpdatedTitle.
  ///
  /// In ko, this message translates to:
  /// **'자재가 변경되었습니다'**
  String get materialUpdatedTitle;

  /// No description provided for @materialUpdatedBody.
  ///
  /// In ko, this message translates to:
  /// **'이 프로젝트도 변경된 자재로 다시 계산할까요?'**
  String get materialUpdatedBody;

  /// No description provided for @yes.
  ///
  /// In ko, this message translates to:
  /// **'예'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ko, this message translates to:
  /// **'아니오'**
  String get no;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @addRow.
  ///
  /// In ko, this message translates to:
  /// **'행 추가'**
  String get addRow;

  /// No description provided for @deleteRow.
  ///
  /// In ko, this message translates to:
  /// **'행 삭제'**
  String get deleteRow;

  /// No description provided for @clearAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 삭제'**
  String get clearAll;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
