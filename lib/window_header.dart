import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

class WindowHeader extends StatefulWidget {
  WindowHeader({Key? key}) : super(key: key);

  @override
  _WindowHeaderState createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 37,
      color: Theme.panel.main,
    );
  }
}
