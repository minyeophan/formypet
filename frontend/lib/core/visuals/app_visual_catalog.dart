import 'package:flutter/material.dart';
import 'app_visual_id.dart';
import 'app_visual_spec.dart';

const Map<AppVisualId, AppVisualSpec> appVisualCatalog = {
  AppVisualId.petDog: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_dog.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.petCat: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_cat.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.petSmallAnimal: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_small_animal.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.petBird: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_bird.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.petReptile: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_reptile.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.petFish: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_fish.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.petExotic: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_exotic.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordMeal: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_meal.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordWater: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_water.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordWalk: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_walk.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordPoop: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_poop.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordMedicine: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_medicine.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordWeight: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_weight.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordVet: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_vet.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordBath: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_bath.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordGroom: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_groom.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordDiary: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_diary.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.recordEtc: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_etc.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealWet: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_wet.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealDry: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_meal.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealSnack: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_snack.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealPrescription: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_prescription.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealRaw: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_raw.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealFreezeDried: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_freeze_dried.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealConsumed25: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_consumed_25.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealConsumed50: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_consumed_50.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealConsumed75: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_consumed_75.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.mealConsumed100: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_consumed_100.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleGrooming: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_groom.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleHospital: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_vet.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleTravel: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/schedule_travel.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleHotel: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/schedule_hotel.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleOuting: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/schedule_outing.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleEvent: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/schedule_event.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.scheduleEtc: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_etc.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeRecords: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/home_records.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeWallet: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/home_wallet.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeRoutine: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/home_routine.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homePetLog: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/home_pet_log.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeNewsSnack: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/meal_snack.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeNewsWalk: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_walk.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeNewsDental: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/home_dental.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.homeBottomBanner: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_exotic.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.navHome: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/nav_home.svg',
      tintable: true,
      strokeWidth: 2,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.navCommunity: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/nav_community.svg',
      tintable: true,
      strokeWidth: 2,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.navMy: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/nav_my.svg',
      tintable: true,
      strokeWidth: 2,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityAll: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/community_all.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityPopular: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/community_popular.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityCare: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/community_care.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityFood: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/record_meal.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityOuting: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/schedule_outing.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityShow: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/ui_camera.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityQuestion: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/common_help.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityFree: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/common_comment.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityAdoption: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/community_adoption.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityRescue: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/community_rescue.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityNews: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/community_news.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityEvent: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/schedule_event.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityPaw: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/pet_exotic.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.communityTop: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/ui_top.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
  AppVisualId.genericUnknown: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/ui_image_error.svg',
      tintable: false,
    ),
    fallback: AppVisualFallback.material(Icons.image_not_supported),
  ),
};

AppVisualSpec appVisualSpecFor(AppVisualId id) => appVisualCatalog[id]!;
