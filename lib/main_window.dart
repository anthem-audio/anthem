import 'package:anthem/theme.dart';
import 'package:anthem/window_header.dart';
import 'package:flutter/widgets.dart';

class MainWindow extends StatefulWidget {
  MainWindow({Key? key}) : super(key: key);

  @override
  _MainWindowState createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3),
      child: Column(
        children: [
          WindowHeader(),
          Container(
            height: 42,
            color: Theme.panel.accent,
          ),
          SizedBox(
            height: 3,
          ),
          Expanded(
            child: Container(
            color: Theme.panel.main,
            ),
          ),
          SizedBox(
            height: 3,
          ),
          Container(
            height: 42,
            color: Theme.panel.light,
          )
        ],
      ),
    );
  }
}
