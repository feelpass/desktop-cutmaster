# CSV 기반 부품 관리 + 자재 자동 선택 작업 (Phase 2)

## 배경
- `0502전경인화이트.CSV` 같은 파일을 그대로 가져와 부품 목록을 채우고 싶음
- CSV의 `MATERIAL` 칼럼(예: `화이트_18T`)이 자재 선택의 단일 기준
- 동일 MATERIAL = 같은 자재 시트 (2440×1220) → 결과 도면이 자재(색상)별로 묶여 출력

## CSV 스키마 (확정)
```
PART, W, D, T, MATERIAL, GRAIN, QTY, ARTICLE, EDGE1..4, FILE, GROOVE, ORIENTATION
```
- `PART` → CutPart.label
- `W`/`D` → length/width
- `T` → thickness
- `MATERIAL` (예: `화이트_18T`) → 색상 + 두께 묶음 → ColorPreset 매핑
- `GRAIN` (0/1) → grainDirection (0=none, 1=lengthwise)
- `QTY` → qty
- `ARTICLE` → 프로젝트명/메모로 흡수
- `EDGE*`, `FILE`, `GROOVE`, `ORIENTATION` → 일단 무시 (Phase 3에서)

## 작업 항목

### A. CSV 파서 + 자재 매핑 (인프라)
- [x] **A1** `lib/data/csv/parts_csv_importer.dart` 생성 — CSV → `List<CutPart>` 파서
- [x] **A2** `MATERIAL` 문자열 파서: `화이트_18T` → (`색상명`, `두께`)
- [x] **A3** ColorPreset 자동 매칭/생성 로직 (이름 일치 우선, 없으면 새 preset 자동 추가)
- [x] **A4** 단위 테스트: `parts_csv_importer_test.dart` (실제 0502전경인화이트.CSV 라인 사용)

### B. UI에서 CSV 가져오기 연결
- [x] **B1** PartsTable 위에 "엑셀/CSV 가져오기" 버튼 추가
- [x] **B2** FilePicker로 CSV 선택 → 임포터 호출 → 파트 교체
- [x] **B3** 임포트 시 ColorPreset 라이브러리도 자동 갱신 (없는 색상이면 추가)
- [x] **B4** ARTICLE → Project.name 자동 채우기 (비어있을 때만)

### C. 부품 행에 두께 표시
- [x] **C1** EditableDimensionTable에 thickness 셀 추가 (선택적, parts에서만)
- [x] **C2** 메타 줄 색상 라벨을 "{색상}_{두께}T" 형식으로 보완

### D. 결과 화면 자재별 그룹 확인
- [x] **D1** `derivedStocks()`이 (color, thickness) 별로 시트 분리하는지 검증 (Project.derivedStocks 키 = `colorPresetId|thickness`)
- [x] **D2** Solver가 부품별로 올바른 stock에 배치 — `runCalculate`에서 자재별로 부품/스톡을 분리해 솔버를 그룹별 호출
- [x] **D3** CuttingResultPane: stock lookup을 `derivedStocks()` 기준으로 변경 (project.stocks → project.derivedStocks())

### E. 검증
- [x] **E1** 0502전경인화이트.CSV 형식 단위 테스트 통과 (11/11)
- [ ] **E2** 실 사용자 테스트 (사용자가 실제로 CSV 임포트 → 최적화 실행)
- [x] **E3** flutter analyze: 변경 파일 0 issues / flutter test: 224/224 통과
