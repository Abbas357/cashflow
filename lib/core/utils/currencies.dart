import 'formatters.dart';

/// A currency people can pick in Settings, with the symbol shown beside
/// amounts and the way numbers are usually grouped where it is used.
///
/// Symbols in scripts the app's fonts (and printed reports) may lack, such
/// as Arabic or Thai, use the letters people write instead (AED, THB).
class Currency {
  final String code;
  final String name;
  final String symbol;
  final NumberGrouping grouping;

  /// ISO country codes where it is the usual currency, to pick a default
  /// from the device's region.
  final List<String> countries;

  const Currency(this.code, this.name, this.symbol, this.grouping, this.countries);

  static Currency? byCode(String? code) => currencies.where((c) => c.code == code).firstOrNull;

  static Currency? forCountry(String? country) =>
      country == null ? null : currencies.where((c) => c.countries.contains(country.toUpperCase())).firstOrNull;
}

const _lakh = NumberGrouping.lakh;
const _million = NumberGrouping.million;
const _dot = NumberGrouping.dotComma;
const _space = NumberGrouping.spaceComma;
const _apostrophe = NumberGrouping.apostrophe;

/// Most used first in the regions the app started in, then by name.
const currencies = <Currency>[
  Currency('PKR', 'Pakistani rupee', 'Rs', _lakh, ['PK']),
  Currency('INR', 'Indian rupee', '₹', _lakh, ['IN', 'BT']),
  Currency('BDT', 'Bangladeshi taka', 'Tk', _lakh, ['BD']),
  Currency('NPR', 'Nepalese rupee', 'Rs', _lakh, ['NP']),
  Currency('LKR', 'Sri Lankan rupee', 'Rs', _million, ['LK']),
  Currency('USD', 'US dollar', '\$', _million, ['US', 'EC', 'SV', 'PR', 'TL', 'ZW']),
  Currency('EUR', 'Euro', '€', _dot, [
    'AT', 'BE', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'IE', //
    'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PT', 'SI', 'SK', 'MC', 'ME',
  ]),
  Currency('GBP', 'British pound', '£', _million, ['GB', 'IM', 'JE', 'GG']),
  Currency('AED', 'UAE dirham', 'AED', _million, ['AE']),
  Currency('SAR', 'Saudi riyal', 'SAR', _million, ['SA']),
  Currency('QAR', 'Qatari riyal', 'QAR', _million, ['QA']),
  Currency('KWD', 'Kuwaiti dinar', 'KD', _million, ['KW']),
  Currency('BHD', 'Bahraini dinar', 'BD', _million, ['BH']),
  Currency('OMR', 'Omani rial', 'OMR', _million, ['OM']),
  Currency('AFN', 'Afghan afghani', 'Af', _million, ['AF']),
  Currency('ARS', 'Argentine peso', 'AR\$', _dot, ['AR']),
  Currency('AUD', 'Australian dollar', 'A\$', _million, ['AU']),
  Currency('BRL', 'Brazilian real', 'R\$', _dot, ['BR']),
  Currency('CAD', 'Canadian dollar', 'CA\$', _million, ['CA']),
  Currency('CHF', 'Swiss franc', 'CHF', _apostrophe, ['CH', 'LI']),
  Currency('CLP', 'Chilean peso', 'CLP\$', _dot, ['CL']),
  Currency('CNY', 'Chinese yuan', '¥', _million, ['CN']),
  Currency('COP', 'Colombian peso', 'COL\$', _dot, ['CO']),
  Currency('CZK', 'Czech koruna', 'Kč', _space, ['CZ']),
  Currency('DKK', 'Danish krone', 'kr', _dot, ['DK', 'GL', 'FO']),
  Currency('DZD', 'Algerian dinar', 'DZD', _space, ['DZ']),
  Currency('EGP', 'Egyptian pound', 'E£', _million, ['EG']),
  Currency('ETB', 'Ethiopian birr', 'Br', _million, ['ET']),
  Currency('GHS', 'Ghanaian cedi', 'GHS', _million, ['GH']),
  Currency('HKD', 'Hong Kong dollar', 'HK\$', _million, ['HK']),
  Currency('HUF', 'Hungarian forint', 'Ft', _space, ['HU']),
  Currency('IDR', 'Indonesian rupiah', 'Rp', _dot, ['ID']),
  Currency('ILS', 'Israeli new shekel', '₪', _million, ['IL', 'PS']),
  Currency('IQD', 'Iraqi dinar', 'IQD', _million, ['IQ']),
  Currency('IRR', 'Iranian rial', 'IRR', _million, ['IR']),
  Currency('JOD', 'Jordanian dinar', 'JD', _million, ['JO']),
  Currency('JPY', 'Japanese yen', '¥', _million, ['JP']),
  Currency('KES', 'Kenyan shilling', 'KSh', _million, ['KE']),
  Currency('KRW', 'South Korean won', '₩', _million, ['KR']),
  Currency('KZT', 'Kazakhstani tenge', '₸', _space, ['KZ']),
  Currency('MAD', 'Moroccan dirham', 'MAD', _space, ['MA']),
  Currency('MXN', 'Mexican peso', 'MX\$', _million, ['MX']),
  Currency('MYR', 'Malaysian ringgit', 'RM', _million, ['MY']),
  Currency('NGN', 'Nigerian naira', '₦', _million, ['NG']),
  Currency('NOK', 'Norwegian krone', 'kr', _space, ['NO']),
  Currency('NZD', 'New Zealand dollar', 'NZ\$', _million, ['NZ']),
  Currency('PEN', 'Peruvian sol', 'S/', _million, ['PE']),
  Currency('PHP', 'Philippine peso', '₱', _million, ['PH']),
  Currency('PLN', 'Polish zloty', 'zł', _space, ['PL']),
  Currency('RON', 'Romanian leu', 'lei', _dot, ['RO']),
  Currency('RUB', 'Russian ruble', '₽', _space, ['RU']),
  Currency('SEK', 'Swedish krona', 'kr', _space, ['SE']),
  Currency('SGD', 'Singapore dollar', 'S\$', _million, ['SG']),
  Currency('THB', 'Thai baht', 'THB', _million, ['TH']),
  Currency('TND', 'Tunisian dinar', 'DT', _space, ['TN']),
  Currency('TRY', 'Turkish lira', '₺', _dot, ['TR']),
  Currency('TWD', 'New Taiwan dollar', 'NT\$', _million, ['TW']),
  Currency('TZS', 'Tanzanian shilling', 'TSh', _million, ['TZ']),
  Currency('UAH', 'Ukrainian hryvnia', '₴', _space, ['UA']),
  Currency('UGX', 'Ugandan shilling', 'USh', _million, ['UG']),
  Currency('UZS', 'Uzbekistani som', 'soʻm', _space, ['UZ']),
  Currency('VND', 'Vietnamese dong', '₫', _dot, ['VN']),
  Currency('ZAR', 'South African rand', 'R', _space, ['ZA', 'NA', 'LS']),
];
