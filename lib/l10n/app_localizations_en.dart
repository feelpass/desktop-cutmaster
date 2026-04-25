// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cutmaster';

  @override
  String get calculate => '계산';

  @override
  String get save => '저장';

  @override
  String get settings => '설정';

  @override
  String get newProject => '새 프로젝트';

  @override
  String get parts => '부품';

  @override
  String get stockSheets => '자재';

  @override
  String get options => '옵션';

  @override
  String get kerf => '톱날 두께(mm)';

  @override
  String get lockGrain => '결방향 고정';

  @override
  String get showPartLabels => '부품 라벨 표시';

  @override
  String get useSingleSheet => '단일 시트 사용';

  @override
  String get emptyResultTitle => '자재와 부품을 입력하고';

  @override
  String get emptyResultAction => '▶ 계산 버튼을 눌러주세요';

  @override
  String get length => '가로';

  @override
  String get width => '세로';

  @override
  String get qty => '수량';

  @override
  String get label => '라벨';

  @override
  String get preset => '프리셋';

  @override
  String get efficiency => '효율';

  @override
  String sheetUsed(int n) {
    return '$n장 사용';
  }

  @override
  String partsCount(int n) {
    return '$n개 부품';
  }

  @override
  String unplacedCount(int n) {
    return '$n개 미배치';
  }

  @override
  String get exportPng => 'PNG 내보내기';

  @override
  String get materialUpdatedTitle => '자재가 변경되었습니다';

  @override
  String get materialUpdatedBody => '이 프로젝트도 변경된 자재로 다시 계산할까요?';

  @override
  String get yes => '예';

  @override
  String get no => '아니오';

  @override
  String get cancel => '취소';

  @override
  String get addRow => '행 추가';

  @override
  String get deleteRow => '행 삭제';

  @override
  String get clearAll => '전체 삭제';
}
