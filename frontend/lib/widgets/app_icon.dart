import 'package:flutter/material.dart';
import '../core/visuals/app_visual_id.dart';
import '../core/visuals/app_visual_spec.dart';
import 'app_visual.dart';

/// Resolves existing Material identifiers to the approved Figma artwork.
class AppIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  static final assets = <IconData, String>{
    Icons.arrow_back: 'assets/icons/common_back.svg',
    Icons.arrow_back_rounded: 'assets/icons/common_back.svg',
    Icons.chevron_left_rounded: 'assets/icons/common_back.svg',
    Icons.chevron_right_rounded: 'assets/icons/common_forward.svg',
    Icons.expand_more: 'assets/icons/common_down.svg',
    Icons.expand_more_rounded: 'assets/icons/common_down.svg',
    Icons.keyboard_arrow_down: 'assets/icons/common_down.svg',
    Icons.keyboard_arrow_down_rounded: 'assets/icons/common_down.svg',
    Icons.search_rounded: 'assets/icons/common_search.svg',
    Icons.notifications_none: 'assets/icons/common_bell.svg',
    Icons.notifications_none_rounded: 'assets/icons/common_bell.svg',
    Icons.notifications_active: 'assets/icons/common_bell_new.svg',
    Icons.favorite: 'assets/icons/common_heart.svg',
    Icons.image: 'assets/icons/common_photo.svg',
    Icons.image_outlined: 'assets/icons/common_photo.svg',
    Icons.share: 'assets/icons/common_share.svg',
    Icons.share_rounded: 'assets/icons/common_share.svg',
    Icons.chat_bubble_outline: 'assets/icons/common_comment.svg',
    Icons.chat_bubble_outline_rounded: 'assets/icons/common_comment.svg',
    Icons.report_outlined: 'assets/icons/common_report.svg',
    Icons.block_rounded: 'assets/icons/common_block.svg',
    Icons.help_outline_rounded: 'assets/icons/common_help.svg',
    Icons.send_rounded: 'assets/icons/common_send.svg',
    Icons.settings_outlined: 'assets/icons/common_settings.svg',
    Icons.edit: 'assets/icons/common_edit.svg',
    Icons.edit_outlined: 'assets/icons/common_edit.svg',
    Icons.edit_note_rounded: 'assets/icons/common_edit.svg',
    Icons.delete_outline_rounded: 'assets/icons/common_delete.svg',
    Icons.add: 'assets/icons/common_add.svg',
    Icons.add_rounded: 'assets/icons/common_add.svg',
    Icons.save: 'assets/icons/common_save.svg',
    Icons.save_outlined: 'assets/icons/common_save.svg',
    Icons.check_rounded: 'assets/icons/common_check.svg',
    Icons.calendar_today_rounded: 'assets/icons/common_calendar.svg',
    Icons.event_note_rounded: 'assets/icons/common_calendar.svg',
    Icons.close: 'assets/icons/ui_close.svg',
    Icons.backspace_outlined: 'assets/icons/ui_clear.svg',
    Icons.close_rounded: 'assets/icons/ui_close.svg',
    Icons.more_vert_rounded: 'assets/icons/ui_more.svg',
    Icons.expand_less: 'assets/icons/ui_collapse.svg',
    Icons.keyboard_arrow_up_rounded: 'assets/icons/ui_collapse.svg',
    Icons.reply_rounded: 'assets/icons/ui_reply.svg',
    Icons.info_outline_rounded: 'assets/icons/ui_info.svg',
    Icons.repeat_rounded: 'assets/icons/ui_repeat.svg',
    Icons.show_chart_rounded: 'assets/icons/ui_graph.svg',
    Icons.map_outlined: 'assets/icons/ui_map.svg',
    Icons.photo_camera_outlined: 'assets/icons/ui_camera.svg',
    Icons.add_a_photo_rounded: 'assets/icons/ui_add_camera.svg',
    Icons.image_not_supported: 'assets/icons/ui_image_error.svg',
    Icons.poll_outlined: 'assets/icons/ui_poll.svg',
    Icons.check_box_outline_blank: 'assets/icons/ui_unchecked.svg',
    Icons.visibility: 'assets/icons/ui_eye.svg',
    Icons.visibility_off: 'assets/icons/ui_eye_off.svg',
    Icons.logout_rounded: 'assets/icons/ui_logout.svg',
    Icons.group_outlined: 'assets/icons/ui_group.svg',
    Icons.person_outline_rounded: 'assets/icons/ui_profile.svg',
    Icons.badge_outlined: 'assets/icons/ui_profile.svg',
    Icons.palette_outlined: 'assets/icons/ui_theme.svg',
    Icons.campaign_outlined: 'assets/icons/ui_announcement.svg',
    Icons.support_agent_rounded: 'assets/icons/ui_support.svg',
    Icons.favorite_border: 'assets/icons/ui_heart_outline.svg',
    Icons.favorite_border_rounded: 'assets/icons/ui_heart_outline.svg',
    Icons.check_circle_rounded: 'assets/icons/ui_done.svg',
    Icons.pets: 'assets/icons/pet_exotic.svg',
    Icons.pets_rounded: 'assets/icons/pet_exotic.svg',
    Icons.content_cut_rounded: 'assets/icons/record_groom.svg',
    Icons.local_hospital_rounded: 'assets/icons/record_vet.svg',
    Icons.directions_walk_rounded: 'assets/icons/record_walk.svg',
    Icons.luggage_rounded: 'assets/icons/schedule_travel.svg',
    Icons.home_work_rounded: 'assets/icons/schedule_hotel.svg',
    Icons.local_cafe_rounded: 'assets/icons/schedule_outing.svg',
    Icons.celebration_rounded: 'assets/icons/schedule_event.svg',
    Icons.health_and_safety_outlined: 'assets/icons/home_dental.svg',
    Icons.cookie_outlined: 'assets/icons/meal_snack.svg',
  };

  @override
  Widget build(BuildContext context) {
    final path = assets[icon];
    if (path == null) {
      return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    }
    final theme = IconTheme.of(context);
    return AppVisual.fromSpec(
      id: AppVisualId.genericUnknown,
      spec: AppVisualSpec(
        source: SvgAssetVisualSource.figma(
          path,
          tintable: path.contains('/common_') || path.contains('/ui_'),
          strokeWidth: path.contains('/common_') || path.contains('/ui_')
              ? 2
              : null,
        ),
        fallback: AppVisualFallback.material(icon!),
      ),
      size: size ?? theme.size ?? 24,
      color: color ?? theme.color,
      semanticLabel: semanticLabel,
    );
  }
}
