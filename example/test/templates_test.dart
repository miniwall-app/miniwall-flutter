import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniwall_flutter_example/templates.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

void main() {
  test('the template is read from the deep link, whatever path the engine reports', () {
    expect(templateFromRoute('/present?tpl=calm-money'), 'calm-money');
    expect(templateFromRoute('/?tpl=notice-bar'), 'notice-bar');
    expect(templateFromRoute('/'), isNull);
    expect(templateFromRoute('/present?tpl='), isNull);
  });

  test('the display follows the file name, as in the iOS and Android samples', () {
    expect(styleFor('stack-toast'), {'type': 'toast', 'seconds': 60});
    expect(styleFor('app-update-bar'), {'type': 'banner', 'position': 'top'});
    expect(styleFor('autumn-banner'), {'type': 'banner', 'position': 'top'});
    expect(styleFor('bake-class-slide-in'), {'type': 'sheet'});
    expect(styleFor('x-drawer'), {'type': 'modal'});
    expect(styleFor('x-launcher'), {'type': 'modal'});
    expect(styleFor('calm-money'), isNull);
  });

  test('a template file is unwrapped to its screen; components are tried when it is not a template', () async {
    final bundle = _Bundle({
      'assets/templates/a.json': '{"description":"A","paywall":{"id":"p1"}}',
      'assets/components/c.json': '{"id":"c1"}',
    });
    expect((await loadTemplate('a', bundle: bundle))!['id'], 'p1');
    expect((await loadTemplate('c', bundle: bundle))!['id'], 'c1');
    expect(await loadTemplate('nope', bundle: bundle), isNull);
  });
}
