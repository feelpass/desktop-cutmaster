import '../../domain/models/stock_sheet.dart' show GrainDirection;
import 'preset_models.dart';

const seedColorPresets = <ColorPreset>[
  // vivid (구 partColorPresets)
  ColorPreset(id: 'cp_red',     name: '빨강', argb: 0xFFEF4444),
  ColorPreset(id: 'cp_orange',  name: '주황', argb: 0xFFF97316),
  ColorPreset(id: 'cp_yellow',  name: '황색', argb: 0xFFEAB308),
  ColorPreset(id: 'cp_lime',    name: '연두', argb: 0xFF84CC16),
  ColorPreset(id: 'cp_green',   name: '초록', argb: 0xFF16A34A),
  ColorPreset(id: 'cp_teal',    name: '청록', argb: 0xFF14B8A6),
  ColorPreset(id: 'cp_sky',     name: '하늘', argb: 0xFF0EA5E9),
  ColorPreset(id: 'cp_blue',    name: '남색', argb: 0xFF3B82F6),
  ColorPreset(id: 'cp_purple',  name: '보라', argb: 0xFF8B5CF6),
  ColorPreset(id: 'cp_magenta', name: '자홍', argb: 0xFFD946EF),
  ColorPreset(id: 'cp_pink',    name: '분홍', argb: 0xFFEC4899),
  ColorPreset(id: 'cp_crimson', name: '진홍', argb: 0xFFBE123C),
  // wood-tone (구 stockColorPresets)
  ColorPreset(id: 'cp_birch',     name: '자작',     argb: 0xFFFAF1DC),
  ColorPreset(id: 'cp_maple',     name: '단풍',     argb: 0xFFE8D2A6),
  ColorPreset(id: 'cp_beige',     name: '베이지',   argb: 0xFFD4B896),
  ColorPreset(id: 'cp_pine',      name: '솔송',     argb: 0xFFC9A876),
  ColorPreset(id: 'cp_oak',       name: '적참',     argb: 0xFFB8865C),
  ColorPreset(id: 'cp_walnut',    name: '호두',     argb: 0xFF8B6240),
  ColorPreset(id: 'cp_ebony',     name: '흑단',     argb: 0xFF3D2A1E),
  ColorPreset(id: 'cp_white_mel', name: '백색멜라민', argb: 0xFFF7F7F2),
  ColorPreset(id: 'cp_lt_gray',   name: '연회색',   argb: 0xFFD4D4D4),
  ColorPreset(id: 'cp_mdf_gray',  name: '회색MDF',  argb: 0xFFA8A29E),
  ColorPreset(id: 'cp_dk_gray',   name: '진회색',   argb: 0xFF6B6B6B),
  ColorPreset(id: 'cp_black_mel', name: '검정멜라민', argb: 0xFF262626),
];

const seedPartPresets = <DimensionPreset>[];

const seedStockPresets = <DimensionPreset>[
  DimensionPreset(id: 'sp_ply12_h',   length: 2440, width: 1220, label: '12T 합판',
      colorPresetId: null, grainDirection: GrainDirection.none),
  DimensionPreset(id: 'sp_ply12_v',   length: 1220, width: 2440, label: '12T 합판 가로',
      colorPresetId: null, grainDirection: GrainDirection.none),
  DimensionPreset(id: 'sp_ply15',     length: 2440, width: 1220, label: '15T 합판',
      colorPresetId: null, grainDirection: GrainDirection.none),
  DimensionPreset(id: 'sp_ply18',     length: 2440, width: 1220, label: '18T 합판',
      colorPresetId: null, grainDirection: GrainDirection.none),
  DimensionPreset(id: 'sp_mdf9',      length: 2440, width: 1220, label: 'MDF 9T',
      colorPresetId: null, grainDirection: GrainDirection.none),
  DimensionPreset(id: 'sp_mdf18',     length: 2440, width: 1220, label: 'MDF 18T',
      colorPresetId: null, grainDirection: GrainDirection.none),
];
