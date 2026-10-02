import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: input.packageName,
      assetName: 'src/native_bindings.dart',
      sources: [
        'src/c_api_error.cpp',
        'src/spsc_record_ring_buffer.cpp',
        'src/shared_memory_region_c_api.cpp',
        'src/spsc_record_ring_buffer_c_api.cpp',
        'src/shared_memory_region_posix.cpp',
        'src/shared_memory_region_windows.cpp',
      ],
      includes: ['include'],
      defines: {'ANTHEM_NATIVE_IPC_BUILDING': null},
      language: Language.cpp,
      std: 'c++20',
    );

    await builder.run(input: input, output: output);
  });
}
