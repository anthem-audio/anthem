import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

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
        return MyHomePage(_store, title: 'Anthem');
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Store _store;
  MyHomePage(this._store, {Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFaaaaaa),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'You have counted to:',
            ),
            Text(
              '${widget._store.count}',
            ),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  child: Container(
                    color: Color(0xFFFF0000),
                    width: 100,
                    height: 100,
                  ),
                  onTap: _addTen,
                ),
                GestureDetector(
                  child: Container(
                    color: Color(0xFF00FF00),
                    width: 100,
                    height: 100,
                  ),
                  onTap: _incrementCounter,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addTen() async {
    final res = await widget._store.msgAdd(10);
    debugPrint('$res');
    debugPrint("${widget._store.raw.debug(true)}");
    setState(() {});
  }

  void _incrementCounter() {
    widget._store.msgInc().then((res) {
      debugPrint('$res');
      debugPrint("${widget._store.raw.debug(true)}");
      setState(() {});
    });
  }
}
