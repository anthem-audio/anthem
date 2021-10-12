import Cocoa
import FlutterMacOS

public class Plugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "plugin", binaryMessenger: registrar.messenger)
    let instance = Plugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
// <rid:prevent_tree_shake Start>
func dummyCallsToPreventTreeShaking() {
    _to_dart_for_Store();
    rid_store_debug(nil);
    rid_store_debug_pretty(nil);
    create_store();
    rid_store_unlock();
    rid_store_free();
    __include_dart_for_vec_project();
    rid_store_projects(nil);
    rid_store_active_project_id(nil);
    rid_len_vec_project(nil);
    rid_get_item_vec_project(nil, 0);
    _include_Store_field_wrappers();
    rid_cstring_free(nil);
    rid_init_msg_isolate(0);
    rid_init_reply_isolate(0);
    _to_dart_for_Project();
    rid_project_debug(nil);
    rid_project_debug_pretty(nil);
    rid_project_id(nil);
    rid_msg_NewProject(0);
    rid_msg_SetActiveProject(0, 0);
}
// <rid:prevent_tree_shake End>