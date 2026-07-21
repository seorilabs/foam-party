extends RefCounted

# Runtime localization for the canvas-drawn UI. The game renders every label with
# draw_string, so there is no scene-tree text to auto-translate; instead we push a
# Korean + English message table into the TranslationServer and each draw site
# calls tr("KEY"). A persisted ko/en preference wins; without one, Korean devices
# resolve to ko and every other device resolves to en. The pause/settings sheet
# can switch the active TranslationServer locale without rebuilding the scene.
#
# Strings that carry printf placeholders keep them inside the translated value,
# e.g. tr("CONTINUE") % [car, level]. Decorative glyphs are limited to ones the
# bundled Do Hyeon font actually contains (it lacks '·', '✓', '↺'); the Hangul
# araea 'ㆍ' (U+318D) is used as the middle-dot separator instead.

const STRINGS := {
	# tools
	"TOOL_AIR": ["바람", "Air"],
	"TOOL_WATER": ["고압수", "Jet"],
	"TOOL_SOAP": ["비누", "Soap"],
	"TOOL_SPONGE": ["스펀지", "Sponge"],
	# car types
	"CAR_COMPACT": ["시티", "City"],
	"CAR_SPORTS": ["스포츠", "Sports"],
	"CAR_TRUCK": ["트럭", "Truck"],
	"CAR_VAN": ["밴", "Van"],
	"CAR_OFFROAD": ["오프로더", "Off-roader"],
	# active tool hint bubble
	"HINT_AIR": ["낙엽을 날려요", "Blow away leaves"],
	"HINT_WATER": ["오물을 씻어요", "Rinse off grime"],
	"HINT_SOAP": ["얼룩을 불려요", "Loosen the stain"],
	"HINT_SPONGE": ["오물을 닦아요", "Scrub off grime"],
	# title screen
	"TITLE_SUBTITLE": ["거품 팡팡 세차 게임", "Bubbly Car Wash"],
	"START": ["세차 시작", "Start Wash"],
	"CONTINUE": ["이어하기 ㆍ %s %02d", "Continue ㆍ %s %02d"],
	"COIN_STAR": ["코인 %d  ㆍ  별 %d", "Coins %d  ㆍ  Stars %d"],
	"BTN_UPGRADE": ["업그레이드", "Upgrades"],
	"BTN_SKIN": ["스킨", "Skins"],
	"BTN_STAGE": ["스테이지", "Stages"],
	"BTN_ACHIEVEMENT": ["업적  %d/%d", "Achievements  %d/%d"],
	"TEXT_SCALE_LABEL": ["글자 %d%%", "Text %d%%"],
	"ACH_TITLE": ["누적 업적", "Lifetime Achievements"],
	"ACH_SUMMARY": ["완료 %d / %d", "Completed %d / %d"],
	"ACH_REWARD": ["+%d 코인", "+%d Coins"],
	"ACH_DONE": ["완료 · 보상 지급됨", "Complete · Rewarded"],
	"ACH_WASHES": ["세차 %d대 완료", "Complete %d washes"],
	"ACH_DIRT": ["오물 %d개 제거", "Remove %d dirt spots"],
	"ACH_LEAF": ["낙엽 %d개 날리기", "Blow away %d leaves"],
	"ACH_STARS": ["별 %d개 모으기", "Collect %d stars"],
	"ACH_COMBO": ["최고 콤보 x%d 달성", "Reach combo x%d"],
	"STAGE_TITLE": ["스테이지 선택", "Select Stage"],
	"STAGE_LEVEL": ["레벨 %02d", "Level %02d"],
	"STAGE_BEST": ["최고 %s", "Best %s"],
	"STAGE_LOCKED": ["잠김", "Locked"],
	"STAGE_PREV": ["이전", "Prev"],
	"STAGE_NEXT": ["다음", "Next"],
	"STAGE_PAGE": ["%d / %d", "%d / %d"],
	# daily mission
	"DM_HEADER": ["오늘의 미션", "Daily Mission"],
	"DM_STREAK": ["연속 %d일 · 보너스 +%d", "%d-day streak · +%d bonus"],
	"DM_STREAK_SHORT": ["연속 %d일", "Streak %dd"],
	"DM_PROGRESS": ["%d/%d 완료", "%d/%d done"],
	"DM_REWARD": ["+%d 코인", "+%d Coins"],
	"DM_DONE": ["완료!", "Done!"],
	"DM_CLEAR_POP": ["+%d 코인!  데일리 미션 클리어!", "+%d Coins!  Daily mission clear!"],
	"DM_LEAF": ["낙엽 %d개 날리기", "Blow away %d leaves"],
	"DM_DUST": ["먼지 %d개 제거하기", "Clear %d dust"],
	"DM_MUD": ["흙탕물 %d개 씻기", "Rinse %d mud spots"],
	"DM_OIL": ["오일 %d개 청소하기", "Clean %d oil spots"],
	"DM_BUG": ["벌레 자국 %d개 닦기", "Wipe %d bug marks"],
	"DM_POOP": ["새똥 %d개 닦기", "Wipe %d droppings"],
	"DM_ROAD_GRIME": ["도로 때 %d개 닦기", "Wipe %d road-grime spots"],
	"DM_COMBO": ["한 판에서 콤보 x%d 달성", "Reach combo x%d in one wash"],
	"DM_FAST": ["%d초 이내 세차 완료", "Finish a wash within %d seconds"],
	"DM_PERFECT3": ["별 3개 세차 %d회", "Earn 3 stars on %d washes"],
	# grade tracker
	"GRADE_COMBO_URGENT": ["콤보 x%d! %d초", "Combo x%d! %ds"],
	"GRADE_KEEP_STAR": ["별 %d 유지: %d초", "Keep star %d: %ds"],
	"GRADE_COMBO_FOR3": ["별 3개까지 콤보 x%d", "Combo x%d for 3 stars"],
	"GRADE_TIME": ["시간 %s", "Time %s"],
	# progress milestones
	"MILESTONE_25": ["25%! 좋은 출발!", "25%! Great start!"],
	"MILESTONE_50": ["절반 청소 완료!", "Halfway clean!"],
	"MILESTONE_75": ["거의 다 됐어요!", "Almost done!"],
	# combo cheers
	"CHEER_NICE": ["좋아요!", "Nice!"],
	"CHEER_KEEP": ["계속 가요!", "Keep going!"],
	"CHEER_SPOTLESS": ["완벽해요!", "Spotless!"],
	"CHEER_WOW": ["우와!", "WOW!"],
	# customer mood
	"MOOD_HAPPY": ["만족!", "Happy!"],
	"MOOD_OK": ["보통...", "Meh..."],
	"MOOD_HURRY": ["서둘러!", "Hurry!"],
	"MOOD_ANGRY": ["화났어요!", "Angry!"],
	# combo badge / milestones
	"COMBO_BADGE": ["콤보 x%d", "Combo x%d"],
	"COIN_GAIN": ["+%d 코인!", "+%d Coins!"],
	"COMBO_FAN_4": ["콤보 x4!", "Combo x4!"],
	"COMBO_FAN_6": ["콤보 x6!", "Combo x6!"],
	"COMBO_FAN_8": ["콤보 x8!", "Combo x8!"],
	"COMBO_FAN_MAX": ["최대 콤보 x%d!", "Max Combo x%d!"],
	# tutorial
	"TUT_TITLE": ["세차 가이드", "Wash Guide"],
	"TUT_TAB_TOOLS": ["도구", "Tools"],
	"TUT_TAB_DIRT": ["오물 도감", "Dirt Guide"],
	"TUT_AIR": ["낙엽과 먼지를 날려요", "Blow away leaves & dust"],
	"TUT_WATER": ["흙탕물과 비누를 씻어요", "Rinse mud & soap"],
	"TUT_SOAP": ["기름때와 벌레 자국을 불려요", "Loosen oil & bug marks"],
	"TUT_SPONGE": ["불린 얼룩을 닦아요", "Scrub loosened stains"],
	"TUT_TIP": ["부스터: 거품 %d · 고압수 %d 코인", "Boosters: foam %d · jet %d coins"],
	"TUT_START": ["돌아가기", "Back"],
	"GUIDE_HEADER_DIRT": ["오물", "Dirt"],
	"GUIDE_HEADER_PATH": ["1차  →  후속", "First  →  Next"],
	"GUIDE_NONE": ["완료", "Done"],
	"GUIDE_DIRT_MUD": ["흙탕물", "Mud"],
	"GUIDE_DIRT_DUST": ["먼지", "Dust"],
	"GUIDE_DIRT_LEAF": ["낙엽", "Leaf"],
	"GUIDE_DIRT_OIL": ["오일", "Oil"],
	"GUIDE_DIRT_BUG": ["벌레", "Bug"],
	"GUIDE_DIRT_POOP": ["새똥", "Dropping"],
	"GUIDE_DIRT_ROAD_GRIME": ["도로 때", "Road grime"],
	"GUIDE_DIRT_SAP": ["나무 수액", "Tree sap"],
	"GUIDE_DESC_MUD": ["먼저 적시거나 불린 뒤 닦아요", "Rinse or soap, then scrub"],
	"GUIDE_DESC_DUST": ["물로 헹구거나 바람으로 날려요", "Rinse or blow it away"],
	"GUIDE_DESC_LEAF": ["바람으로 차 밖까지 날려요", "Blow it completely off the car"],
	"GUIDE_DESC_OIL": ["비누로 불린 뒤 닦거나 헹궈요", "Soap, then scrub or rinse"],
	"GUIDE_DESC_BUG": ["비누로 불린 뒤 닦거나 헹궈요", "Soap, then scrub or rinse"],
	"GUIDE_DESC_POOP": ["비누로 불린 뒤 헹구거나 닦아요", "Soap, then rinse or scrub"],
	"GUIDE_DESC_ROAD_GRIME": ["먼저 모래를 씻고 부드럽게 닦아요", "Rinse grit first, then scrub"],
	"GUIDE_DESC_SAP": ["비누로 충분히 불린 뒤 닦아요", "Soften with soap, then scrub"],
	# booster picker
	"BOOSTER_LABEL": ["부스터", "Boosters"],
	"BOOSTER_SELECT": ["2가지 선택", "Choose 1 of 2"],
	"BOOSTER_TITLE": ["부스터 선택", "Choose a Booster"],
	"BOOSTER_FOAM": ["거품 폭탄", "Foam Bomb"],
	"BOOSTER_FOAM_DESC": ["전체 오염 불림", "Loosen all dirt"],
	"BOOSTER_WATER": ["고압수 부스트", "Jet Boost"],
	"BOOSTER_WATER_DESC": ["%d초 반경·세기 UP", "%ds reach and power"],
	"WATER_BOOST_SHORT": ["고압수 UP", "Jet Boost"],
	"BOOSTER_ACTIVE": ["%d초", "%ds"],
	"BOMB_FREE": ["무료", "Free"],
	# level-end double-coins rewarded ad
	"DOUBLE_COINS": ["광고 보고 코인 2배", "Watch ad — 2× coins"],
	"DOUBLE_DONE": ["코인 2배 획득!", "Coins doubled!"],
	# pause menu + quit confirm (AIT back button)
	"PAUSE_TITLE": ["일시정지 · 설정", "Paused · Settings"],
	"RESUME": ["계속하기", "Resume"],
	"PAUSE_RESTART": ["이 차 다시 세차", "Restart Car"],
	"GUIDE": ["세차 가이드", "Wash Guide"],
	"HOME": ["홈으로", "Home"],
	"QUIT": ["종료", "Quit"],
	"MUSIC_ON": ["음악 켜짐", "Music On"],
	"MUSIC_OFF": ["음악 꺼짐", "Music Off"],
	"SFX_ON": ["효과음 켜짐", "SFX On"],
	"SFX_OFF": ["효과음 꺼짐", "SFX Off"],
	"HAPTICS_ON": ["진동 켜짐", "Haptics On"],
	"HAPTICS_OFF": ["진동 꺼짐", "Haptics Off"],
	"LANGUAGE_KO": ["한국어", "한국어"],
	"LANGUAGE_EN": ["English", "English"],
	"REDUCE_MOTION_ON": ["모션 줄이기  켜짐", "Reduced Motion  On"],
	"REDUCE_MOTION_OFF": ["모션 줄이기  꺼짐", "Reduced Motion  Off"],
	"QUIT_CONFIRM": ["앱을 종료할까요?", "Quit the app?"],
	"QUIT_YES": ["종료", "Quit"],
	"QUIT_NO": ["취소", "Cancel"],
	# completion panel
	"COMPLETE_TITLE": ["완전 청소!", "All Clean!"],
	"COMPLETE_SUB": ["%s %02d ㆍ %s ㆍ 최고 콤보 x%d", "%s %02d ㆍ %s ㆍ Best Combo x%d"],
	"BEFORE_WASH": ["세차 전", "Before"],
	"AFTER_WASH": ["세차 후", "After"],
	"REWASH_REWARD": ["재세차 50%", "Rewash 50%"],
	"NEW_RECORD": ["신기록! %s", "New Record! %s"],
	"BEST_RECORD": ["최고 기록 %s", "Best %s"],
	"MILESTONE_CHIP": ["Lv.%d 이정표! +%d", "Lv.%d milestone! +%d"],
	"PERFECT_CHIP": ["완벽! +%d", "Perfect! +%d"],
	"PATIENCE_TIP_CHIP": ["만족 팁  +%d", "Happy tip  +%d"],
	"RETRY": ["다시 세차", "Rewash"],
	"NEXT": ["다음 차 ▶", "Next Car ▶"],
	# upgrade panel
	"UPG_SHOP_TITLE": ["업그레이드 상점", "Upgrade Shop"],
	"UPG_TAB_POWER": ["세기", "Power"],
	"UPG_TAB_REACH": ["반경", "Reach"],
	"COINS_LABEL": ["코인: %d", "Coins: %d"],
	"MAX": ["최대", "MAX"],
	"COST_COIN": ["%d 코인", "%d Coins"],
	"UPG_NAME_AIR": ["바람 강화", "Air Upgrade"],
	"UPG_NAME_WATER": ["고압수 강화", "Jet Upgrade"],
	"UPG_NAME_SOAP": ["비누 강화", "Soap Upgrade"],
	"UPG_NAME_SPONGE": ["스펀지 강화", "Sponge Upgrade"],
	"UPG_DESC_AIR": ["낙엽ㆍ먼지 날리기 속도 향상", "Faster leaf & dust clearing"],
	"UPG_DESC_WATER": ["흙탕물ㆍ먼지 제거 속도 향상", "Faster mud & dust removal"],
	"UPG_DESC_SOAP": ["얼룩 분리 속도 향상", "Faster stain loosening"],
	"UPG_DESC_SPONGE": ["닦는 속도 향상", "Faster scrubbing"],
	"UPG_REACH_NAME_AIR": ["바람 반경", "Air Reach"],
	"UPG_REACH_NAME_WATER": ["고압수 반경", "Jet Reach"],
	"UPG_REACH_NAME_SOAP": ["비누 반경", "Soap Reach"],
	"UPG_REACH_NAME_SPONGE": ["스펀지 반경", "Sponge Reach"],
	"UPG_REACH_DESC": ["적용 범위 +%d%%", "Coverage +%d%%"],
	# skin panel
	"SKIN_TITLE": ["차량 꾸미기", "Car Customization"],
	"CAR_PAINT_TAB": ["차량", "Car"],
	"PLATE_TITLE": ["번호판 문구", "License Plate"],
	"SKIN_SELECTED": ["선택됨", "Selected"],
	"SKIN_SELECT": ["선택", "Select"],
	"SKIN_CLASSIC": ["클래식", "Classic"],
	"SKIN_CORAL": ["코랄", "Coral"],
	"SKIN_MINT": ["민트", "Mint"],
	"SKIN_GOLD": ["골드", "Gold"],
	"SKIN_COBALT": ["코발트", "Cobalt"],
	"SKIN_VIOLET": ["바이올렛", "Violet"],
	"SKIN_PINK": ["핑크", "Pink"],
	"SKIN_LAVENDER": ["라벤더", "Lavender"],
	"SKIN_LIME": ["라임", "Lime"],
	"SKIN_PURPLE": ["퍼플", "Purple"],
	"SKIN_AUTO": ["자동 순환", "Auto"],
	"SKIN_PAINT_CORAL": ["코랄", "Coral"],
	"SKIN_PAINT_MINT": ["민트", "Mint"],
	"SKIN_PAINT_VIOLET": ["바이올렛", "Violet"],
}

const SUPPORTED_LOCALES := ["ko", "en"]


static func normalize_preference(locale: String) -> String:
	var language := locale.strip_edges().to_lower().replace("-", "_").get_slice("_", 0)
	return language if language in SUPPORTED_LOCALES else ""


static func resolve_locale(preferred_locale: String, device_language: String) -> String:
	var preferred := normalize_preference(preferred_locale)
	if preferred != "":
		return preferred
	return "ko" if normalize_preference(device_language) == "ko" else "en"


static func select_locale(preferred_locale: String = "") -> String:
	var locale := resolve_locale(preferred_locale, OS.get_locale_language())
	TranslationServer.set_locale(locale)
	return locale


# Registers the ko/en tables and selects a stored preference or the device
# fallback. Safe to call more than once. Returns the chosen locale.
static func setup(preferred_locale: String = "") -> String:
	var tr_ko := Translation.new()
	tr_ko.locale = "ko"
	var tr_en := Translation.new()
	tr_en.locale = "en"
	for key in STRINGS:
		var pair: Array = STRINGS[key]
		tr_ko.add_message(key, pair[0])
		tr_en.add_message(key, pair[1])
	TranslationServer.add_translation(tr_ko)
	TranslationServer.add_translation(tr_en)
	return select_locale(preferred_locale)
