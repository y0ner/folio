import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';
import 'package:folio/core/files/recent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

DocumentRef doc(String name, [int t = 0]) => DocumentRef(
      path: '/docs/$name',
      name: name,
      kind: DocKind.fromName(name)!,
      sizeBytes: 100,
      openedAt: DateTime.fromMillisecondsSinceEpoch(t),
    );

Future<SharedPreferencesWithCache> prefs() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
}

void main() {
  test('el más reciente queda primero y no se duplica', () async {
    final store = RecentStore(await prefs());
    await store.add(doc('a.pdf'));
    await store.add(doc('b.docx'));
    await store.add(doc('a.pdf', 5));
    expect(store.items.map((e) => e.name), ['a.pdf', 'b.docx']);
    expect(store.items.first.openedAt.millisecondsSinceEpoch, 5);
  });

  test('persiste entre instancias', () async {
    final p = await prefs();
    await RecentStore(p).add(doc('x.xlsx'));
    expect(RecentStore(p).items.single.name, 'x.xlsx');
  });

  test('devuelve los expulsados al superar el máximo', () async {
    final store = RecentStore(await prefs());
    for (var i = 0; i < RecentStore.maxItems; i++) {
      await store.add(doc('f$i.pdf'));
    }
    final evicted = await store.add(doc('nuevo.pdf'));
    expect(evicted.single.name, 'f0.pdf');
    expect(store.items.length, RecentStore.maxItems);
  });

  test('quitar elimina la entrada', () async {
    final store = RecentStore(await prefs());
    await store.add(doc('a.pdf'));
    await store.remove(doc('a.pdf'));
    expect(store.items, isEmpty);
  });
}
