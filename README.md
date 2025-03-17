# wallet_lib

### Add dependency
```yaml
dependencies:
 wallet_lib:
    git:
        url: https://github.com/Vincent8725/wallet_lib.git
```

###  Example
```dart
import 'package:wallet_lib/features/home/screens/main_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: 
        Center(
            child: ElevatedButton(
                onPressed: () {
                    // Open Wallet Main Page
                    navigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (context) => MainScreen()),
                    );
                },
                child: const Text('Open Wallet'),
            ),
        ),
    );
  }
}
```