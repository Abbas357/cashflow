import 'package:cash_flow/core/utils/device_region.dart';
import 'package:cash_flow/core/utils/zone_countries.dart';
import 'package:cash_flow/services/install_report.dart';
import 'package:cash_flow/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('country', () {
    test('prefers the SIM, then the network, the time zone, the language', () {
      expect(DeviceRegion.pick(sim: 'pk', network: 'ae', zone: 'Asia/Tokyo', locale: 'en_US'), 'PK');
      expect(DeviceRegion.pick(sim: '', network: 'ae', zone: 'Asia/Tokyo', locale: 'US'), 'AE');
      expect(DeviceRegion.pick(zone: 'Asia/Karachi', locale: 'US'), 'PK');
      expect(DeviceRegion.pick(zone: 'Etc/UTC', locale: 'gb'), 'GB');
      expect(DeviceRegion.pick(zone: 'Etc/UTC', locale: '419'), isNull);
      expect(DeviceRegion.pick(), isNull);
    });

    test('old time zone names that browsers report are known', () {
      expect(zoneCountries['Asia/Calcutta'], 'IN');
      expect(zoneCountries['Asia/Kolkata'], 'IN');
      expect(zoneCountries['Asia/Saigon'], 'VN');
      expect(zoneCountries['US/Pacific'], 'US');
    });

    test('the default currency follows the country, not the language', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsController(await SharedPreferences.getInstance());
      await s.setCountry('PK');
      expect(s.currencyInfo.code, 'PKR');

      await s.setCurrencyCode('EUR');
      expect(s.currencyInfo.code, 'EUR');
    });
  });

  group('report', () {
    late SettingsController settings;
    late List<Map<String, Object?>> sent;
    late bool failing;
    late InstallReport report;

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() async {
      SharedPreferences.setMockInitialValues({'country_code': 'PK', 'currency_code': 'PKR', 'currency': 'Rs'});
      settings = SettingsController(await SharedPreferences.getInstance());
      sent = [];
      failing = false;
      report = InstallReport(
        settings,
        send: (params) async {
          if (failing) throw Exception('offline');
          sent.add(params);
        },
      );
      report.start();
      await settle();
    });

    tearDown(() => report.stop());

    test('waits for the welcome popup to finish', () async {
      expect(sent, isEmpty);
      await settings.setOnboarded();
      await settle();
      expect(sent, hasLength(1));
    });

    test('sends only the random id, country, currency and platform', () async {
      await settings.setProfile(name: 'Ali', address: 'Peshawar', phone: '123');
      await settings.setOnboarded();
      await settle();

      expect(sent.single.keys, unorderedEquals(['p_id', 'p_country', 'p_currency', 'p_platform']));
      expect(sent.single['p_id'], settings.installId);
      expect(sent.single['p_id'], isNot(settings.userId));
      expect(sent.single['p_country'], 'PK');
      expect(sent.single['p_currency'], 'PKR');
      expect(sent.single.values, isNot(contains('Ali')));
    });

    test('sends once, and again only when something changes', () async {
      await settings.setOnboarded();
      await settle();
      await settings.setName('Ali');
      await settle();
      expect(sent, hasLength(1));

      await settings.setCurrencyCode('EUR');
      await settle();
      expect(sent, hasLength(2));
      expect(sent.last['p_currency'], 'EUR');
    });

    test('delete removes the row by its id and stops reporting for good', () async {
      await settings.setOnboarded();
      await settle();
      expect(sent, hasLength(1));

      final removed = <String>[];
      await InstallReport.delete(settings, remove: (id) async => removed.add(id));
      expect(removed, [settings.installId]);
      expect(settings.installStatsOff, isTrue);
      expect(settings.installReported, isNull);

      await settings.setCurrencyCode('EUR');
      await settle();
      expect(sent, hasLength(1));
    });

    test('delete with nothing sent needs no connection', () async {
      await InstallReport.delete(settings, remove: (_) async => fail('nothing to remove'));
      expect(settings.installStatsOff, isTrue);

      await settings.setOnboarded();
      await settle();
      expect(sent, isEmpty);
    });

    test('a failed delete changes nothing and does not send again', () async {
      await settings.setOnboarded();
      await settle();
      final before = settings.installReported;

      await expectLater(
        InstallReport.delete(settings, remove: (_) async => throw Exception('offline')),
        throwsException,
      );
      await settle();
      expect(settings.installStatsOff, isFalse);
      expect(settings.installReported, before);
      expect(sent, hasLength(1));
    });

    test('offline: nothing breaks, and it tries again later', () async {
      failing = true;
      await settings.setOnboarded();
      await settle();
      expect(sent, isEmpty);
      expect(settings.installReported, isNull);

      failing = false;
      await settings.setName('Ali');
      await settle();
      expect(sent, hasLength(1));
    });
  });
}
