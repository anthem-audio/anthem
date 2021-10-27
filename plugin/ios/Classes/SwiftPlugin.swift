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
    _to_dart_for_Instrument();
    rid_instrument_id(nil);
    rid_instrument_name(nil);
    rid_instrument_name_len(nil);
    rid_cstring_free(nil);
    rid_init_msg_isolate(0);
    rid_init_reply_isolate(0);
    _to_dart_for_Controller();
    rid_controller_id(nil);
    rid_controller_name(nil);
    rid_controller_name_len(nil);
    _to_dart_for_Note();
    rid_note_id(nil);
    rid_note_key(nil);
    rid_note_velocity(nil);
    rid_note_length(nil);
    rid_note_offset(nil);
    _to_dart_for_Pattern();
    __include_dart_for_hash_map_u64_channelnotes();
    rid_pattern_id(nil);
    rid_pattern_name(nil);
    rid_pattern_name_len(nil);
    rid_pattern_channel_notes(nil);
    rid_pattern_time_signature_changes(nil);
    rid_pattern_default_time_signature(nil);
    rid_pattern_useless_time_sig_change(nil);
    rid_export_rid_len_hash_map_u64_channelnotes(nil);
    rid_export_rid_get_hash_map_u64_channelnotes(nil, 0);
    rid_export_rid_contains_key_hash_map_u64_channelnotes(nil, 0);
    rid_export_rid_keys_hash_map_u64_channelnotes(nil);
    __include_dart_for_ridvec_u64();
    rid_free_ridvec_u64(RidVec_u64());
    rid_get_item_ridvec_u64(RidVec_u64(), 0);
    rid_len_vec_timesignaturechange(nil);
    rid_get_item_vec_timesignaturechange(nil, 0);
    _to_dart_for_ChannelNotes();
    __include_dart_for_vec_note();
    rid_channelnotes_notes(nil);
    rid_len_vec_note(nil);
    rid_get_item_vec_note(nil, 0);
    _to_dart_for_Project();
    __include_dart_for_vec_u64();
    rid_project_id(nil);
    rid_project_is_saved(nil);
    rid_project_file_path(nil);
    rid_project_file_path_len(nil);
    rid_project_song(nil);
    rid_project_instruments(nil);
    rid_project_controllers(nil);
    rid_project_generator_list(nil);
    rid_len_vec_u64(nil);
    rid_get_item_vec_u64(nil, 0);
    rid_export_rid_len_hash_map_u64_controller(nil);
    rid_export_rid_get_hash_map_u64_controller(nil, 0);
    rid_export_rid_contains_key_hash_map_u64_controller(nil, 0);
    rid_export_rid_keys_hash_map_u64_controller(nil);
    rid_export_rid_len_hash_map_u64_instrument(nil);
    rid_export_rid_get_hash_map_u64_instrument(nil, 0);
    rid_export_rid_contains_key_hash_map_u64_instrument(nil, 0);
    rid_export_rid_keys_hash_map_u64_instrument(nil);
    _to_dart_for_Song();
    __include_dart_for_vec_pattern();
    rid_song_id(nil);
    rid_song_ticks_per_quarter(nil);
    rid_song_patterns(nil);
    rid_song_active_pattern_id(nil);
    rid_song_active_instrument_id(nil);
    rid_song_active_controller_id(nil);
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
    rid_msg_NewProject(0);
    rid_msg_SetActiveProject(0, 0);
    rid_msg_CloseProject(0, 0);
    rid_msg_SaveProject(0, 0, nil);
    rid_msg_LoadProject(0, nil);
    rid_msg_Undo(0, 0);
    rid_msg_Redo(0, 0);
    rid_msg_AddInstrument(0, 0, nil);
    rid_msg_AddController(0, 0, nil);
    rid_msg_RemoveGenerator(0, 0, 0);
    rid_msg_SetActivePattern(0, 0, 0);
    rid_msg_SetActiveInstrument(0, 0, 0);
    rid_msg_SetActiveController(0, 0, 0);
    rid_msg_AddPattern(0, 0, nil);
    rid_msg_DeletePattern(0, 0, 0);
    rid_msg_AddNote(0, 0, 0, 0, nil);
    rid_msg_DeleteNote(0, 0, 0, 0, 0);
    _to_dart_for_TimeSignature();
    rid_timesignature_numerator(nil);
    rid_timesignature_denominator(nil);
    _to_dart_for_TimeSignatureChange();
    rid_timesignaturechange_offset(nil);
    rid_timesignaturechange_time_signature(nil);
}
// <rid:prevent_tree_shake End>