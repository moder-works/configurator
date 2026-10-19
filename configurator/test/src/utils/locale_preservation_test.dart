import 'package:code_builder/code_builder.dart';
import 'package:configurator/configurator.dart';
import 'package:configurator/src/writers/configuration_writer.dart';
import 'package:test/test.dart';

String fixture(String section, String namespace) => '''
id: locale_fixture
${namespace.isEmpty ? '' : 'namespace: $namespace'}
configuration:
  $section:
    en_us:
      welcome: 'Hello \${name}, \${count} items'
      englishOnly: 'English fallback'
    es:
      welcome: 'Hola \${name}, \${count} elementos'
    pt_br:
      welcome: 'Olá \${name}, \${count} itens'
    zh_cn:
      welcome: '你好 \${name}，共 \${count} 项'
''';

const expectedWelcome = {
  'en_us': 'Hello %s, %s items',
  'es': 'Hola %s, %s elementos',
  'pt_br': 'Olá %s, %s itens',
  'zh_cn': '你好 %s，共 %s 项',
};

void main() {
  for (final section in ['i18n', 'strings']) {
    for (final namespace in ['screen', 'customer.screen']) {
      test('$section retains every locale under $namespace', () {
        final yaml = fixture(section, namespace);
        final parsed = YamlParser.fromYamlString(yaml);
        final entries = section == 'i18n' ? parsed.i18n : parsed.strings;
        expect(entries.map((entry) => entry.locale).toSet(),
            {'en_us', 'es', 'pt_br', 'zh_cn'});

        final scope = ConfigScope.fromYaml(yaml);
        final prefix = namespace == 'screen' ? 'screen' : 'customerScreen';
        expect(scope.translations['${prefix}Welcome'], expectedWelcome);
        expect(scope.translations['${prefix}EnglishOnly'],
            {'en_us': 'English fallback'});
      });
    }
  }

  test('unnamespaced translations retain all locales and placeholders', () {
    final scope = ConfigScope.fromYaml(fixture('i18n', ''));
    expect(scope.translations['welcome'], expectedWelcome);
    expect(scope.translations['englishOnly'], {'en_us': 'English fallback'});
  });

  test('visiting another locale never replaces an earlier locale', () {
    final entries = [
      YamlI18n('title', 'en_us', 'English'),
      YamlI18n('title', 'es', 'Español'),
      YamlI18n('title', 'pt_br', 'Português'),
      YamlI18n('title', 'zh_cn', '中文'),
    ];
    const expected = {
      'title': {
        'en_us': 'English',
        'es': 'Español',
        'pt_br': 'Português',
        'zh_cn': '中文',
      },
    };
    expect(I18nParser.parse(strings: entries), expected);
    expect(I18nParser.parse(strings: entries.reversed.toList()), expected);
  });

  test('generated scope contains all namespaced locale values', () {
    final parsed = YamlParser.fromYamlString(fixture('i18n', 'screen'));
    final writer = ConfigWriter(
      name: parsed.name,
      weight: parsed.weight,
      strings: parsed.resolvedTranslations,
      textStyles: parsed.textStyles,
      routes: parsed.routes,
      flags: parsed.flags,
      sizes: parsed.sizes,
      colors: parsed.colors,
      misc: parsed.misc,
      images: parsed.images,
      margins: parsed.margins,
      padding: parsed.padding,
    );
    expect(writer.translations['screenWelcome'], expectedWelcome);
    final source = writer.write().accept(DartEmitter()).toString();
    for (final entry in expectedWelcome.entries) {
      expect(source, contains(entry.key));
      expect(source, contains(entry.value));
    }
  });
}
