import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/work_status/work_status_cubit.dart';
import 'package:otzaria/work_status/work_status_item.dart';

void main() {
  WorkStatusItem buildItem({String id = 'x', Duration? autoDismissAfter}) =>
      WorkStatusItem(
        id: id,
        title: 'כותרת',
        message: 'הודעה',
        autoDismissAfter: autoDismissAfter,
      );

  group('WorkStatusCubit auto-dismiss', () {
    test('פריט עם autoDismissAfter יורד מעצמו אחרי המשך שהוגדר', () {
      fakeAsync((async) {
        final cubit = WorkStatusCubit();
        cubit.upsert(
          buildItem(autoDismissAfter: const Duration(seconds: 8)),
        );
        expect(cubit.state.items, isNotEmpty);

        async.elapse(const Duration(seconds: 7));
        expect(cubit.state.items, isNotEmpty);

        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.items, isEmpty);
        cubit.close();
      });
    });

    test('פריט בלי autoDismissAfter נשאר — אין טיימר סמוי', () {
      fakeAsync((async) {
        final cubit = WorkStatusCubit();
        cubit.upsert(buildItem());

        async.elapse(const Duration(minutes: 5));
        expect(cubit.state.items, isNotEmpty);
        cubit.close();
      });
    });

    test('upsert חוזר בלי autoDismissAfter מבטל טיימר קודם', () {
      fakeAsync((async) {
        final cubit = WorkStatusCubit();
        cubit.upsert(
          buildItem(autoDismissAfter: const Duration(seconds: 8)),
        );
        cubit.upsert(buildItem());

        async.elapse(const Duration(seconds: 20));
        expect(cubit.state.items, isNotEmpty);
        cubit.close();
      });
    });

    test('remove ידני מבטל את הטיימר וסגירת ה-cubit לא זורקת', () {
      fakeAsync((async) {
        final cubit = WorkStatusCubit();
        cubit.upsert(
          buildItem(autoDismissAfter: const Duration(seconds: 8)),
        );
        cubit.remove('x');
        expect(cubit.state.items, isEmpty);

        cubit.close();
        async.elapse(const Duration(seconds: 20));
      });
    });
  });
}
