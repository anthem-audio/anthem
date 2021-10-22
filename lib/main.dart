/*
  Copyright (C) 2021 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:ui';
import 'package:anthem/widgets/basic/menu/menu_overlay.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'widgets/main_window/main_window.dart';
import 'widgets/main_window/main_window_cubit.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Store _store = Store.instance;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Anthem',
      color: const Color.fromARGB(255, 7, 210, 212),
      builder: (context, widget) {
        return BlocProvider<MainWindowCubit>(
          create: (_) => MainWindowCubit(),
          child: MenuOverlay(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image.asset("assets/images/background-small.jpg",
                      fit: BoxFit.cover),
                ),
                Container(
                  color: const Color.fromARGB(77, 0, 0, 0),
                ),
                MainWindow(_store),
              ],
            ),
          ),
        );
      },
    );
  }
}

// class MyHomePage extends StatefulWidget {
//   final Store _store;
//   MyHomePage(this._store, {Key? key, required this.title}) : super(key: key);
//   final String title;
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               'You have counted to:',
//             ),
//             Text(
//               '${widget._store.counter.count}',
//             ),
//             const SizedBox(height: 100),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 GestureDetector(
//                   child: Container(
//                     color: Color(0xFFFF0000),
//                     width: 100,
//                     height: 100,
//                   ),
//                   onTap: _addTen,
//                 ),
//                 GestureDetector(
//                   child: Container(
//                     color: Color(0xFF00FF00),
//                     width: 100,
//                     height: 100,
//                   ),
//                   onTap: _incrementCounter,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _addTen() async {
//     final res = await widget._store.msgAdd(10);
//     debugPrint('$res');
//     debugPrint("${widget._store.raw.debug(true)}");
//     setState(() {});
//   }

//   void _incrementCounter() {
//     widget._store.msgInc().then((res) {
//       debugPrint('$res');
//       debugPrint("${widget._store.raw.debug(true)}");
//       setState(() {});
//     });
//   }
// }
