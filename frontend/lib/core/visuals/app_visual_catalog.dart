import 'package:flutter/material.dart';

import 'app_visual_id.dart';
import 'app_visual_spec.dart';

const Map<AppVisualId, AppVisualSpec> appVisualCatalog = {
  AppVisualId.petDog: AppVisualSpec(source: EmojiVisualSource('🐶')),
  AppVisualId.petCat: AppVisualSpec(source: EmojiVisualSource('🐱')),
  AppVisualId.petSmallAnimal: AppVisualSpec(source: EmojiVisualSource('🐰')),
  AppVisualId.petBird: AppVisualSpec(source: EmojiVisualSource('🐦')),
  AppVisualId.petReptile: AppVisualSpec(source: EmojiVisualSource('🦎')),
  AppVisualId.petFish: AppVisualSpec(source: EmojiVisualSource('🐟')),
  AppVisualId.petExotic: AppVisualSpec(source: EmojiVisualSource('🐾')),
  AppVisualId.recordMeal: AppVisualSpec(
    source: MaterialVisualSource(Icons.restaurant_rounded),
  ),
  AppVisualId.recordWater: AppVisualSpec(
    source: MaterialVisualSource(Icons.water_drop_rounded),
  ),
  AppVisualId.recordWalk: AppVisualSpec(
    source: MaterialVisualSource(Icons.directions_walk_rounded),
  ),
  AppVisualId.recordPoop: AppVisualSpec(
    source: MaterialVisualSource(Icons.pets_rounded),
  ),
  AppVisualId.recordMedicine: AppVisualSpec(
    source: MaterialVisualSource(Icons.medication_rounded),
  ),
  AppVisualId.recordWeight: AppVisualSpec(
    source: MaterialVisualSource(Icons.monitor_weight_rounded),
  ),
  AppVisualId.recordVet: AppVisualSpec(
    source: MaterialVisualSource(Icons.local_hospital_rounded),
  ),
  AppVisualId.recordBath: AppVisualSpec(
    source: MaterialVisualSource(Icons.bathtub_rounded),
  ),
  AppVisualId.recordGroom: AppVisualSpec(
    source: MaterialVisualSource(Icons.content_cut_rounded),
  ),
  AppVisualId.recordDiary: AppVisualSpec(
    source: MaterialVisualSource(Icons.menu_book_rounded),
  ),
  AppVisualId.recordEtc: AppVisualSpec(
    source: MaterialVisualSource(Icons.more_horiz_rounded),
  ),
  AppVisualId.mealWet: AppVisualSpec(source: EmojiVisualSource('🥫')),
  AppVisualId.mealDry: AppVisualSpec(source: EmojiVisualSource('🍚')),
  AppVisualId.mealSnack: AppVisualSpec(source: EmojiVisualSource('🦴')),
  AppVisualId.mealPrescription: AppVisualSpec(source: EmojiVisualSource('💊')),
  AppVisualId.mealRaw: AppVisualSpec(source: EmojiVisualSource('🥩')),
  AppVisualId.mealFreezeDried: AppVisualSpec(source: EmojiVisualSource('❄️')),
  AppVisualId.mealConsumed25: AppVisualSpec(source: EmojiVisualSource('😭')),
  AppVisualId.mealConsumed50: AppVisualSpec(source: EmojiVisualSource('😐')),
  AppVisualId.mealConsumed75: AppVisualSpec(source: EmojiVisualSource('🙂')),
  AppVisualId.mealConsumed100: AppVisualSpec(source: EmojiVisualSource('🥰')),
  AppVisualId.scheduleGrooming: AppVisualSpec(
    source: MaterialVisualSource(Icons.content_cut_rounded),
  ),
  AppVisualId.scheduleHospital: AppVisualSpec(
    source: MaterialVisualSource(Icons.local_hospital_rounded),
  ),
  AppVisualId.scheduleTravel: AppVisualSpec(
    source: MaterialVisualSource(Icons.luggage_rounded),
  ),
  AppVisualId.scheduleHotel: AppVisualSpec(
    source: MaterialVisualSource(Icons.home_work_rounded),
  ),
  AppVisualId.scheduleOuting: AppVisualSpec(
    source: MaterialVisualSource(Icons.local_cafe_rounded),
  ),
  AppVisualId.scheduleEvent: AppVisualSpec(
    source: MaterialVisualSource(Icons.celebration_rounded),
  ),
  AppVisualId.scheduleEtc: AppVisualSpec(
    source: MaterialVisualSource(Icons.event_note_rounded),
  ),
  AppVisualId.homeRecords: AppVisualSpec(
    source: MaterialVisualSource(Icons.edit_note_rounded),
  ),
  AppVisualId.homeWallet: AppVisualSpec(
    source: MaterialVisualSource(Icons.account_balance_wallet_rounded),
  ),
  AppVisualId.homeRoutine: AppVisualSpec(
    source: MaterialVisualSource(Icons.check_circle_outline_rounded),
  ),
  AppVisualId.homePetLog: AppVisualSpec(
    source: MaterialVisualSource(Icons.category_outlined),
  ),
  AppVisualId.homeNewsSnack: AppVisualSpec(
    source: MaterialVisualSource(Icons.cookie_outlined),
  ),
  AppVisualId.homeNewsWalk: AppVisualSpec(
    source: MaterialVisualSource(Icons.directions_walk_rounded),
  ),
  AppVisualId.homeNewsDental: AppVisualSpec(
    source: MaterialVisualSource(Icons.health_and_safety_outlined),
  ),
  AppVisualId.homeBottomBanner: AppVisualSpec(source: EmojiVisualSource('🐾')),
  AppVisualId.communityAll: AppVisualSpec(
    source: MaterialVisualSource(Icons.grid_view_rounded),
  ),
  AppVisualId.communityPopular: AppVisualSpec(
    source: MaterialVisualSource(Icons.trending_up_rounded),
  ),
  AppVisualId.communityCare: AppVisualSpec(
    source: MaterialVisualSource(Icons.health_and_safety_outlined),
  ),
  AppVisualId.communityFood: AppVisualSpec(
    source: MaterialVisualSource(Icons.restaurant_outlined),
  ),
  AppVisualId.communityOuting: AppVisualSpec(
    source: MaterialVisualSource(Icons.directions_walk_rounded),
  ),
  AppVisualId.communityShow: AppVisualSpec(
    source: MaterialVisualSource(Icons.photo_camera_outlined),
  ),
  AppVisualId.communityQuestion: AppVisualSpec(
    source: MaterialVisualSource(Icons.help_outline_rounded),
  ),
  AppVisualId.communityFree: AppVisualSpec(
    source: MaterialVisualSource(Icons.chat_bubble_outline_rounded),
  ),
  AppVisualId.communityAdoption: AppVisualSpec(
    source: MaterialVisualSource(Icons.volunteer_activism_outlined),
  ),
  AppVisualId.communityRescue: AppVisualSpec(
    source: MaterialVisualSource(Icons.emergency_outlined),
  ),
  AppVisualId.communityNews: AppVisualSpec(
    source: MaterialVisualSource(Icons.article_outlined),
  ),
  AppVisualId.communityEvent: AppVisualSpec(
    source: MaterialVisualSource(Icons.celebration_outlined),
  ),
  AppVisualId.communityPaw: AppVisualSpec(source: EmojiVisualSource('🐾')),
  AppVisualId.communityTop: AppVisualSpec(source: EmojiVisualSource('🔝')),
  AppVisualId.genericUnknown: AppVisualSpec(
    source: MaterialVisualSource(Icons.circle),
  ),
};

AppVisualSpec appVisualSpecFor(AppVisualId id) => appVisualCatalog[id]!;
