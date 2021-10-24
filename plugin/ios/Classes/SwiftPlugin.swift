import Flutter
import UIKit

public class SwiftPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(nil)
  }
}
// <rid:prevent_tree_shake Start>
func dummyCallsToPreventTreeShaking() {
    _to_dart_for_Pattern();
    rid_pattern_debug(nil);
    rid_pattern_debug_pretty(nil);
    rid_pattern_id(nil);
    rid_pattern_name(nil);
    rid_pattern_name_len(nil);
    rid_cstring_free(nil);
    rid_init_msg_isolate(0);
    rid_init_reply_isolate(0);
    _to_dart_for_Song();
    rid_song_debug(nil);
    rid_song_debug_pretty(nil);
    __include_dart_for_vec_pattern();
    rid_song_id(nil);
    rid_song_patterns(nil);
    rid_len_vec_pattern(nil);
    rid_get_item_vec_pattern(nil, 0);
    _to_dart_for_Store();
    create_store();
    rid_store_unlock();
    rid_store_free();
    __include_dart_for_vec_project();
    rid_store_projects(nil);
    rid_store_active_project_id(nil);
    rid_len_vec_project(nil);
    rid_get_item_vec_project(nil, 0);
    _include_Store_field_wrappers();
    _to_dart_for_Project();
    rid_project_id(nil);
    rid_project_is_saved(nil);
    rid_project_file_path(nil);
    rid_project_file_path_len(nil);
    rid_project_song(nil);
    rid_msg_NewProject(0);
    rid_msg_SetActiveProject(0, 0);
    rid_msg_CloseProject(0, 0);
    rid_msg_SaveProject(0, 0, nil);
    rid_msg_LoadProject(0, nil);
    rid_msg_Undo(0, 0);
    rid_msg_Redo(0, 0);
    rid_msg_AddPattern(0, 0, nil);
    rid_msg_DeletePattern(0, 0, 0);
}
// <rid:prevent_tree_shake End>