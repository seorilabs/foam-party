extends RefCounted

# Runtime localization for the canvas-drawn UI. The game renders every label with
# draw_string, so there is no scene-tree text to auto-translate; instead we push a
# Korean + English message table into the TranslationServer and each draw site
# calls tr("KEY"). Locale is chosen once at startup from the device language:
# Korean device -> ko, everything else -> en. AppsInToss (Toss, Korea) resolves to
# ko, so the mini-app ships fully Korean; Google Play / App Store users get their
# language via the same device-locale path.
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
	# daily mission
	"DM_HEADER": ["오늘의 미션", "Daily Mission"],
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
	"TUT_AIR": ["낙엽과 먼지를 날려요", "Blow away leaves & dust"],
	"TUT_WATER": ["흙탕물과 비누를 씻어요", "Rinse mud & soap"],
	"TUT_SOAP": ["기름때와 벌레 자국을 불려요", "Loosen oil & bug marks"],
	"TUT_SPONGE": ["불린 얼룩을 닦아요", "Scrub loosened stains"],
	"TUT_TIP": ["콤보를 이어가면 별 3개! 거품 폭탄: %d 코인", "Chain combos for 3 stars! Foam bomb: %d coins"],
	"TUT_START": ["탭하여 시작!", "Tap to start!"],
	# foam bomb
	"BOMB_LABEL": ["거품", "Foam"],
	"BOMB_FREE": ["무료", "Free"],
	# level-end double-coins rewarded ad
	"DOUBLE_COINS": ["광고 보고 코인 2배", "Watch ad — 2× coins"],
	"DOUBLE_DONE": ["코인 2배 획득!", "Coins doubled!"],
	# pause menu + quit confirm (AIT back button)
	"PAUSE_TITLE": ["일시정지 · 설정", "Paused · Settings"],
	"RESUME": ["계속하기", "Resume"],
	"GUIDE": ["세차 가이드", "Wash Guide"],
	"HOME": ["홈으로", "Home"],
	"QUIT": ["종료", "Quit"],
	"SOUND_ON": ["소리 끄기", "Mute"],
	"SOUND_OFF": ["소리 켜기", "Unmute"],
	"QUIT_CONFIRM": ["앱을 종료할까요?", "Quit the app?"],
	"QUIT_YES": ["종료", "Quit"],
	"QUIT_NO": ["취소", "Cancel"],
	# completion panel
	"COMPLETE_TITLE": ["완전 청소!", "All Clean!"],
	"COMPLETE_SUB": ["%s %02d ㆍ %s ㆍ 최고 콤보 x%d", "%s %02d ㆍ %s ㆍ Best Combo x%d"],
	"NEW_RECORD": ["신기록! %s", "New Record! %s"],
	"BEST_RECORD": ["최고 기록 %s", "Best %s"],
	"MILESTONE_CHIP": ["Lv.%d 이정표! +%d", "Lv.%d milestone! +%d"],
	"RETRY": ["다시 세차", "Rewash"],
	"NEXT": ["다음 차 ▶", "Next Car ▶"],
	# upgrade panel
	"UPG_SHOP_TITLE": ["업그레이드 상점", "Upgrade Shop"],
	"COINS_LABEL": ["코인: %d", "Coins: %d"],
	"MAX": ["최대", "MAX"],
	"COST_COIN": ["%d 코인", "%d Coins"],
	"UPG_NAME_WATER": ["고압수 강화", "Jet Upgrade"],
	"UPG_NAME_SOAP": ["비누 강화", "Soap Upgrade"],
	"UPG_NAME_SPONGE": ["스펀지 강화", "Sponge Upgrade"],
	"UPG_DESC_WATER": ["흙탕물ㆍ먼지 제거 속도 향상", "Faster mud & dust removal"],
	"UPG_DESC_SOAP": ["얼룩 분리 속도 향상", "Faster stain loosening"],
	"UPG_DESC_SPONGE": ["닦는 속도 향상", "Faster scrubbing"],
	# skin panel
	"SKIN_TITLE": ["노즐 스킨", "Nozzle Skins"],
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
}


# Registers the ko/en tables with the TranslationServer and selects the locale
# from the device language. Safe to call more than once. Returns the chosen locale.
static func setup() -> String:
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
	var locale := "ko" if OS.get_locale_language() == "ko" else "en"
	TranslationServer.set_locale(locale)
	return locale
