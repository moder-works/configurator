import 'dart:convert';
import 'package:configurator/configurator.dart';
import 'package:configurator/src/utils/string_ext.dart';
import 'package:yaml/yaml.dart';

/// Exception thrown when YAML parsing fails.
///
/// This exception is thrown when the YAML content is invalid or cannot be
/// parsed into the expected configuration format.
class InvalidYamlException implements Exception {
  /// The error message describing the parsing failure
  final dynamic message;

  /// Creates a new [InvalidYamlException] with an optional error message.
  InvalidYamlException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "InvalidYamlException";
    return "InvalidYamlException: $message";
  }
}

/// A utility class for parsing YAML configuration files.
///
/// This class provides methods to parse YAML strings into structured configuration
/// objects. It handles various configuration sections including:
/// * Flags
/// * Colors
/// * Images
/// * Text styles
/// * Routes
/// * Internationalization strings
/// * Sizes and dimensions
///
/// Example:
/// ```yaml
/// id: my_config
/// namespace: app
/// weight: 100
/// configuration:
///   flags:
///     isDarkMode: true
///   colors:
///     primary: '#FF0000'
/// ```
class YamlParser {
  /// Attempts to parse a YAML string into a [YamlConfiguration] object.
  ///
  /// This method catches any parsing errors and returns null if parsing fails.
  ///
  /// Parameters:
  /// * [yamlString] - The YAML string to parse
  ///
  /// Returns:
  /// * A [YamlConfiguration] object if parsing succeeds
  /// * null if parsing fails
  static YamlConfiguration? tryParse(String? yamlString) {
    try {
      return fromYamlString(yamlString);
    } catch (e) {
      print(e);
    }
    return null;
  }

  /// Parses a YAML string into a [YamlConfiguration] object.
  ///
  /// This method validates and parses the YAML string, extracting all configuration
  /// sections into a structured object.
  ///
  /// Parameters:
  /// * [yamlString] - The YAML string to parse
  ///
  /// Returns:
  /// * A [YamlConfiguration] object containing the parsed configuration
  ///
  /// Throws:
  /// * [InvalidYamlException] if the YAML is invalid or missing required sections
  static YamlConfiguration fromYamlString(String? yamlString) {
    // Convert to YamlDocument (with validation)
    final YamlDocument document = _validate(yamlString)!;

    // Get the root node
    final YamlNode rootNode = document.contents;

    final YamlNode configNode = rootNode.value['configuration'];
    final String id = rootNode.value['id'];
    final String? ns = rootNode.value['namespace'];

    var yamlConfig = YamlConfiguration(
      name: id,
      partFiles: _processParts(rootNode),
      weight: _processWeight(rootNode),
      flags: _processSettings(configNode, 'flags', ns),
      colors: _processSettings(configNode, 'colors', ns),
      images: _processSettings(configNode, 'images', ns),
      sizes: _processSettings(configNode, 'sizes', ns),
      padding: _processSettings(configNode, 'paddings', ns),
      margins: _processSettings(configNode, 'margins', ns),
      misc: _processSettings(configNode, 'misc', ns),
      textStyles: _processTextStyles(configNode),
      routes: _processRoutes(configNode, 'routes'),
      strings: _processTranslations(configNode, 'strings', ns),
      i18n: _processTranslations(configNode, 'i18n', ns),
    );

    return yamlConfig;
  }

  /// Processes the 'parts' section of the configuration.
  ///
  /// Parts are additional configuration files that should be included.
  ///
  /// Parameters:
  /// * [node] - The YAML node containing the parts list
  ///
  /// Returns:
  /// * A list of part file paths
  static List<String> _processParts(YamlNode node) {
    List<String> parts = [];

    try {
      final partsNode = node.value['parts'];

      if (partsNode is! YamlList) {
        return parts;
      }

      for (var e in partsNode.value) {
        if (e is String) {
          parts.add(e);
        }
      }
    } catch (e) {
      print(e);
    }

    return parts;
  }

  /// Processes the configuration weight.
  ///
  /// The weight determines the precedence of this configuration when multiple
  /// configurations are merged.
  ///
  /// Parameters:
  /// * [configNode] - The YAML node containing the weight value
  ///
  /// Returns:
  /// * The weight as an integer, defaulting to 0 if not specified
  static int _processWeight(YamlNode configNode) {
    try {
      final node = configNode.value['weight'];

      if (node is int) {
        return node;
      } else if (node is String) {
        return int.parse(node);
      }
    } catch (e) {
      print(e);
    }

    return 0;
  }

  /// Processes text style configurations.
  ///
  /// Text styles define the typography settings for the application.
  ///
  /// Parameters:
  /// * [configNode] - The YAML node containing text style definitions
  /// * [namespace] - Optional namespace for the text styles
  ///
  /// Returns:
  /// * A list of [YamlTextStyle] objects
  static List<YamlTextStyle> _processTextStyles(YamlNode configNode,
      [String? namespace]) {
    List<YamlTextStyle> textStyles = [];

    var stylesNode = configNode.value['textStyles'];

    try {
      if (stylesNode is! YamlMap) {
        return textStyles;
      }

      var str = jsonEncode(stylesNode);

      Map<String, dynamic> map = json.decode(str);

      textStyles.addAll(_getTextStyleNamespaces(map, [], namespace ?? ''));
    } catch (e) {
      print(e);
    }

    return textStyles;
  }

  /// Processes general settings sections (flags, colors, images, etc.).
  ///
  /// Parameters:
  /// * [configNode] - The YAML node containing the settings
  /// * [type] - The type of settings to process (e.g., 'flags', 'colors')
  /// * [namespace] - Optional namespace for the settings
  ///
  /// Returns:
  /// * A list of [YamlSetting] objects
  static List<YamlSetting> _processSettings(YamlNode configNode, String type,
      [String? namespace]) {
    List<YamlSetting> settings = [];

    try {
      final settingsNode = configNode.value[type];

      if (settingsNode is! YamlMap) {
        return settings;
      }

      var str = jsonEncode(settingsNode);

      Map<String, dynamic> map = json.decode(str);

      settings.addAll(_getSettingNamespaces(map, [], namespace ?? ''));
    } catch (e) {
      print(e);
    }

    return settings;
  }

  /// Processes route configurations.
  ///
  /// Routes define the navigation structure of the application.
  ///
  /// Parameters:
  /// * [configNode] - The YAML node containing route definitions
  /// * [type] - The type of routes to process
  ///
  /// Returns:
  /// * A list of [YamlRoute] objects
  static List<YamlRoute> _processRoutes(YamlNode configNode, String type) {
    List<YamlRoute> routes = [];

    try {
      final settingsNode = configNode.value[type];

      if (settingsNode is! YamlList) {
        return routes;
      }

      var str = jsonEncode(settingsNode);

      List<dynamic> list = json.decode(str);

      for (var route in list) {
        var processed = YamlRoute.fromJson(route);

        routes.add(processed);

        void addChildrenRecursive(YamlRoute route) {
          for (YamlRoute c in route.children) {
            routes.add(c);

            if (c.children.isNotEmpty) {
              addChildrenRecursive(c);
            }
          }
        }

        addChildrenRecursive(processed);
      }
    } catch (e) {
      print(e);
    }

    return routes;
  }

  /// Recursively processes settings with namespaces.
  ///
  /// This method handles nested settings by creating appropriate namespaces
  /// for each level.
  ///
  /// Parameters:
  /// * [setting] - The map of settings to process
  /// * [result] - The list to store processed settings
  /// * [path] - The current namespace path
  ///
  /// Returns:
  /// * A list of [YamlSetting] objects with namespaced names
  static List<YamlSetting> _getSettingNamespaces(
      Map<String, dynamic> setting, List<YamlSetting> result, String path) {
    for (var es in setting.entries) {
      //  if (es.value is List) {
      //    print('SHES A LIST');
      //
      //    for (var i = 0; i < es.value.length; i++) {
      //      result.add(
      //        YamlSetting(
      //          '${path.capitalized}_${es.key.capitalized}_i_$i'.canonicalize,
      //          es.value[i],
      //        ),
      //      );
      //    }
      // } else
      if (es.value is Map) {
        result.addAll(
          _getSettingNamespaces(
            es.value,
            [],
            '${path.capitalized}_${es.key.capitalized}'.canonicalize,
          ),
        );
      } else {
        result.add(
          YamlSetting(
            '${path.capitalized}_${es.key.capitalized}'.canonicalize,
            es.value,
          ),
        );
      }
    }

    return result;
  }

  /// Processes text style configurations with namespaces.
  ///
  /// This method handles nested text style definitions by creating appropriate
  /// namespaces for each level.
  ///
  /// Parameters:
  /// * [setting] - The map of text style definitions to process
  /// * [result] - The list to store processed text styles
  /// * [path] - The current namespace path
  ///
  /// Returns:
  /// * A list of [YamlTextStyle] objects with namespaced names
  static List<YamlTextStyle> _getTextStyleNamespaces(
      Map<String, dynamic> setting, List<YamlTextStyle> result, String path) {
    for (var es in setting.entries) {
      if (es.value is Map && !es.value.keys.contains('typeface')) {
        result.addAll(
          _getTextStyleNamespaces(
            es.value,
            [],
            '${path.capitalized}_${es.key.capitalized}'.canonicalize,
          ),
        );
      } else {
        result.add(
          YamlTextStyle(
            key: '${path.capitalized}_${es.key.capitalized}'.canonicalize,
            color: es.value['color'] ?? '000000',
            size: es.value['size'] ?? 12.0,
            weight: es.value['weight'] ?? 400,
            height: es.value['height'] ?? 0,
            typeface: <String, String>{
              ...es.value['typeface'],
            },
          ),
        );
      }
    }

    return result;
  }

  static List<YamlI18n> processTranslationsMap(
      Map<String, dynamic> translationsMap) {
    List<YamlI18n> translations = [];

    try {
      for (var t in translationsMap.entries) {
        var values = t.value.entries.map((v) {
          return YamlI18n(v.key, t.key, v.value);
        });
        translations.addAll(List.from(values));
      }
    } catch (e) {
      print(e);
    }

    return translations;
  }

  static List<YamlI18n> _processTranslations(YamlNode configNode, String type,
      [String? namespace]) {
    List<YamlI18n> translations = [];

    try {
      final translationsNode = configNode.value[type];

      if (translationsNode is! YamlMap) {
        return translations;
      }

      var str = jsonEncode(translationsNode);

      Map<String, dynamic> translationsMap = json.decode(str);

      if (translationsMap.isNotEmpty &&
          namespace != null &&
          namespace.isNotEmpty == true) {
        // Apply the namespace within every locale. Wrapping only the first
        // locale discards all subsequent translations in the same file.
        translationsMap = translationsMap.map((locale, values) {
          Map<String, dynamic> result = Map<String, dynamic>.from(values);
          for (final segment in namespace.split('.').reversed) {
            result = {segment: result};
          }
          return MapEntry(locale, result);
        });
      }

      for (var t in translationsMap.entries) {
        var values =
            t.value.entries.map((v) => YamlI18n(v.key, t.key, v.value));
        translations.addAll(List.from(values));
      }
    } catch (e) {
      print(e);
    }

    return translations;
  }

  static void _validateContents(YamlDocument document) {
    final YamlNode rootNode = document.contents;

    if (rootNode.value == null) {
      throw InvalidYamlException('rootNode value was null.');
    }

    if (rootNode.value == null || rootNode.value is! YamlMap) {
      throw InvalidYamlException(
          'rootNode.value was ${rootNode.value?.runtimeType}, expected YamlMap');
    }

    if (!(rootNode.value as YamlMap).containsKey('configuration')) {
      throw InvalidYamlException('No "configuration" key exists');
    } else if ((rootNode.value as YamlMap)['configuration'] is! YamlMap) {
      throw InvalidYamlException(
          'configuration.value was ${(rootNode.value as YamlMap)['configuration']?.runtimeType}, expected YamlMap');
    }

    if (!(rootNode.value as YamlMap).containsKey('id')) {
      throw InvalidYamlException('No "id" key exists');
    } else if ((rootNode.value as YamlMap)['id'] is! String) {
      throw InvalidYamlException(
          'Invalid ID specified. Must be non-empty value of type String');
    }
  }

  static YamlDocument? _validate(String? yamlString) {
    // First step validation (not empty or null)
    _inputValidate(yamlString);

    // Ensure the input can be decoded with convert.dart
    dynamic decoded = _decodeValidate(yamlString);

    // Ensure decoded value is not empty map
    _notEmptyMapValidate(decoded);

    // Ensure package:yaml is able to convert to YamlDocument
    YamlDocument document = _loadYamlValidate(yamlString!);

    // Ensure the contents of the document include the required fields.
    _validateContents(document);

    return document;
  }

  static YamlDocument _loadYamlValidate(String yamlString) {
    try {
      return loadYamlDocument(yamlString);
    } on Exception catch (e) {
      throw InvalidYamlException('Unable to loadYamlDocument: ${e.toString()}');
    }
  }

  static void _inputValidate(String? yamlString) {
    if (yamlString == null) {
      throw InvalidYamlException('input was null');
    }

    if (yamlString.isEmpty) {
      throw InvalidYamlException('input was empty');
    }
  }

  static dynamic _decodeValidate(String? yamlString) {
    try {
      return jsonDecode(jsonEncode(loadYamlNode(yamlString!)));
    } on Exception catch (e) {
      throw InvalidYamlException(
          'Unable to decode input into JSON: ${e.toString()}');
    }
  }

  static void _notEmptyMapValidate(dynamic x) {
    if (x is! Map || x.isEmpty) {
      throw InvalidYamlException(
          'Input was not decoded into a map. Was: ${x?.runtimeType}');
    } else if (x.isEmpty) {
      throw InvalidYamlException('Input was an empty map.');
    }
  }
}

class I18nParser {
  static Map<String, dynamic> parse({
    required List<YamlI18n> strings,
  }) {
    Map<String, dynamic> map = {};

    if (strings.isEmpty) {
      return map;
    }

    for (var f in strings) {
      map[f.locale] ??= {};
      map[f.locale][f.name] ??= f.value;
    }

    List<String> locales = map.keys.toList();

    var r = locales.map((e) {
      // Each locale must be visited into an independent map. Reusing one map
      // causes a later locale to replace an earlier locale before deep merge.
      return visitTranslations(e, Map.from(map[e]), null, {}, []);
    }).reduce((value, element) => deepMapMerge(value, element));

    return r;
  }

  static void _translatePrimitive(
    String locale,
    dynamic input,
    dynamic parent,
    Map<String, dynamic> result,
    List<String> path,
  ) {
    if (input is! String && input is! num) {
      throw Exception(
          'Non-primitive type passed to _translatePrimitive: ${input.runtimeType}');
    }

    String valueKey = path.map((e) => e.capitalized).join('_').canonicalize;

    if (valueKey.contains('MapMap')) {
      valueKey = valueKey.replaceAll('MapMap', 'Map');
    }

    if (input is String) {
      if (path.isNotEmpty && RegExp(r'\(rich\)').hasMatch(path.last)) {
        var content = RegExp(r'\((.*?)\)');

        if (content.hasMatch(input)) {
          var match = content.firstMatch(input);

          result[valueKey.replaceAll('Rich', '')] = {
            locale: input.substring(match!.start + 1, match.end - 1),
          };
        }
      } else {
        result[valueKey] = {
          locale: input.replaceAll(RegExp(r'\${(.*?)}'), '%s'),
        };
      }
    } else {
      result[valueKey] = {
        locale: '$input',
      };
    }
  }

  static void _translateMap(
    String locale,
    Map<dynamic, dynamic> input,
    dynamic parent,
    Map<String, dynamic> result,
    List<String> path,
  ) {
    for (var entry in input.entries) {
      var translations = visitTranslations(
        locale,
        entry.value,
        input,
        {},
        [
          ...(path.isNotEmpty ? [...path, '_'] : path),
          entry.key,
        ],
      );

      result.addAll(
        translations,
      );
    }
  }

  static void _translateList(
    String locale,
    List<dynamic> input,
    dynamic parent,
    Map<String, dynamic> result,
    List<String> path,
  ) {
    for (var i = 0; i < input.length; i++) {
      var entry = input[i];
      var newPath = [
        ...path,
        '_',
        '$i',
      ];

      var entryTranslations = visitTranslations(
        locale,
        entry,
        input,
        {},
        newPath,
      );

      result.addAll(entryTranslations);
    }
  }

  static Map<String, dynamic> visitTranslations(
    String locale,
    dynamic input,
    dynamic parent,
    Map<String, dynamic> result,
    List<String> path,
  ) {
    if (input is Map<dynamic, dynamic>) {
      _translateMap(locale, input, parent, result, path);
    } else if (input is List) {
      _translateList(locale, input, parent, result, path);
    } else if (input is String || input is num) {
      _translatePrimitive(locale, input, parent, result, path);
    } else {
      throw Exception(
          'Unsupported setting found in Strings : ${input.runtimeType}');
    }

    return result;
  }

  static Map<String, dynamic> deepMapMerge(
    Map<String, dynamic> original,
    Map<String, dynamic> newMap,
  ) {
    for (var key in newMap.keys) {
      if (newMap[key] is Map && original[key] is Map) {
        original[key] = deepMapMerge(original[key], newMap[key]);
      } else {
        original[key] = newMap[key];
      }
    }

    return original;
  }
}
