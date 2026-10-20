import 'dart:io';

/// Makes a new deploy of the web app load on a plain refresh:
/// `dart tool/web_cache_bust.dart <build id>`, after `flutter build web`.
///
/// GitHub Pages lets browsers keep every file for 10 minutes, and a plain
/// refresh only re-checks the page itself. So the page now asks for its
/// scripts by version (`flutter_bootstrap.js?v=<id>`, `main.dart.js?v=<id>`)
/// and the engine's files live in a folder named after the engine
/// (`canvaskit-<rev>/`): a new build means new addresses, which no browser
/// has cached. `build_id.txt` lets the running app notice a newer deploy.
void main(List<String> args) {
  final id = args.isNotEmpty ? args.first : DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  const dir = 'build/web';

  String edit(String text, String from, String to, String file) {
    if (!text.contains(from)) {
      stderr.writeln('$file: could not find $from');
      exit(1);
    }
    return text.replaceFirst(from, to);
  }

  final index = File('$dir/index.html');
  var html = index.readAsStringSync();
  html = edit(html, 'src="flutter_bootstrap.js"', 'src="flutter_bootstrap.js?v=$id"', 'index.html');
  html = edit(html, 'href="manifest.json"', 'href="manifest.json?v=$id"', 'index.html');
  index.writeAsStringSync(html);

  final boot = File('$dir/flutter_bootstrap.js');
  var js = boot.readAsStringSync();
  js = edit(js, '"mainJsPath":"main.dart.js"', '"mainJsPath":"main.dart.js?v=$id"', 'flutter_bootstrap.js');

  final engine = RegExp(r'"engineRevision":"([0-9a-f]+)"').firstMatch(js)?.group(1);
  if (engine == null) {
    stderr.writeln('flutter_bootstrap.js: no engineRevision');
    exit(1);
  }
  final canvasKit = 'canvaskit-${engine.substring(0, 12)}';
  Directory('$dir/canvaskit').renameSync('$dir/$canvasKit');
  js = edit(
    js,
    '_flutter.loader.load({',
    '_flutter.loader.load({\n  config: { canvasKitBaseUrl: "$canvasKit/" },',
    'flutter_bootstrap.js',
  );
  boot.writeAsStringSync(js);

  File('$dir/build_id.txt').writeAsStringSync(id);
  stdout.writeln('Web build $id: scripts versioned, engine files in $canvasKit/');
}
