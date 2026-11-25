import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

import '../../../core/files/document_ref.dart';
import '../../../core/theme/folio_colors.dart';
import '../viewer_layout.dart';
import '../viewer_controller.dart';
import 'engine_message.dart';
import 'office_engine.dart';

/// Cuerpo del visor para Word, Excel y PowerPoint (motores web empaquetados
/// en `assets/engines/`).
class OfficeDocumentView extends StatefulWidget {
  const OfficeDocumentView({
    super.key,
    required this.document,
    required this.controller,
    required this.onTap,
  });

  final DocumentRef document;
  final ViewerController controller;

  /// Toque simple sobre el contenido (la pantalla alterna las barras).
  final VoidCallback onTap;

  @override
  State<OfficeDocumentView> createState() => _OfficeDocumentViewState();
}

class _OfficeDocumentViewState extends State<OfficeDocumentView> {
  static const String _assetHost = 'appassets.androidplatform.net';

  OfficeEngine? _engine;
  bool _fileExists = true;
  InAppWebViewController? _webController;
  bool _initialized = false;
  String? _lastCanvasHex;

  /// Márgenes fijados al abrir (no cambian al ocultar las barras, para que
  /// el documento no salte).
  EdgeInsets? _insets;

  /// Si el motor no responde en este tiempo, se muestra un error en vez de
  /// dejar el indicador girando (p. ej. si el WebView no se pudo crear).
  static const Duration _watchdogTimeout = Duration(seconds: 45);
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    // Los motores web solo existen en Android (en Linux el WebView es un
    // sustituto vacío: ver packages/inappwebview_linux_stub).
    _engine = defaultTargetPlatform == TargetPlatform.android
        ? OfficeEngine.forKind(widget.document.kind)
        : null;
    if (_engine == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.fail(
          ViewerFailure(
            ViewerFailureKind.unsupported,
            detail: 'Tipo sin motor web: ${widget.document.kind.name}',
          ),
        );
      });
      return;
    }

    _fileExists = File(widget.document.path).existsSync();
    if (_fileExists) _startWatchdog();
    if (!_fileExists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.fail(
          ViewerFailure(
            ViewerFailureKind.missing,
            detail: 'Archivo no encontrado: ${widget.document.path}',
          ),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canvasHex = _toCssHex(context.folio.canvas);
    if (_initialized && _webController != null && canvasHex != _lastCanvasHex) {
      _lastCanvasHex = canvasHex;
      _webController!.evaluateJavascript(
        source: 'window.folio && folio.setCanvas?.(${jsonEncode(canvasHex)})',
      );
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_watchdogTimeout, () {
      if (!mounted || widget.controller.status != ViewerStatus.loading) return;
      debugPrint('OfficeDocumentView: el motor no respondió a tiempo');
      widget.controller.fail(
        const ViewerFailure(
          ViewerFailureKind.engine,
          detail: 'El motor no respondió a tiempo',
        ),
      );
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    widget.controller.attach();
    _webController = null;
    super.dispose();
  }

  String _toCssHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  String _documentUrl() {
    final fileName = p.basename(widget.document.path);
    return 'https://appassets.androidplatform.net/doc/${Uri.encodeComponent(fileName)}';
  }

  void _handleEngineMessage(Object? raw) {
    if (!mounted) return;
    final message = EngineMessage.parse(raw);
    if (message == null) {
      debugPrint('OfficeDocumentView: mensaje inválido del motor: $raw');
      return;
    }

    switch (message) {
      case EngineReady(:final pageCount, :final sections):
        widget.controller.markReady(pageCount: pageCount, sections: sections);
      case EnginePage(:final page):
        widget.controller.setPage(page);
      case EngineTap():
        widget.onTap();
      case EngineError(:final kind, :final detail):
        debugPrint('OfficeDocumentView: error del motor ($kind): $detail');
        widget.controller.fail(ViewerFailure(kind, detail: detail));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvas = context.folio.canvas;
    final engine = _engine;
    if (engine == null || !_fileExists) {
      return ColoredBox(color: canvas, child: const SizedBox.expand());
    }

    final docDir = File(widget.document.path).parent.path;

    return ColoredBox(
      color: canvas,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(engine.entryUrl)),
        initialSettings: InAppWebViewSettings(
          webViewAssetLoader: WebViewAssetLoader(
            domain: _assetHost,
            pathHandlers: [
              AssetsPathHandler(path: '/assets/'),
              InternalStoragePathHandler(path: '/doc/', directory: docDir),
            ],
          ),
          javaScriptEnabled: true,
          supportZoom: true,
          builtInZoomControls: true,
          displayZoomControls: false,
          allowFileAccess: false,
          allowContentAccess: false,
          transparentBackground: true,
          useShouldOverrideUrlLoading: true,
          cacheEnabled: false,
        ),
        shouldOverrideUrlLoading: (webController, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri != null && uri.scheme == 'https' && uri.host == _assetHost) {
            return NavigationActionPolicy.ALLOW;
          }
          return NavigationActionPolicy.CANCEL;
        },
        onWebViewCreated: (webController) {
          _webController = webController;
          widget.controller.attach(
            onGoToPage: (page) {
              _webController?.evaluateJavascript(
                source: 'window.folio && folio.goToPage($page)',
              );
            },
            onSelectSection: (i) => _webController?.evaluateJavascript(
              source: 'window.folio && folio.selectSheet($i)',
            ),
          );
          webController.addJavaScriptHandler(
            handlerName: 'folio',
            callback: (JavaScriptHandlerFunctionData data) {
              _handleEngineMessage(data.args.isNotEmpty ? data.args.first : null);
              return null;
            },
          );
        },
        onLoadStop: (webController, url) {
          if (!mounted || _initialized) return;
          _initialized = true;
          final canvasHex = _toCssHex(context.folio.canvas);
          _lastCanvasHex = canvasHex;
          final payload = jsonEncode({
            'docUrl': _documentUrl(),
            'canvas': canvasHex,
          });
          final insets = _insets ??= ViewerLayout.contentInsets(context);
          final css = documentInsetsJs(insets);
          webController.evaluateJavascript(
            source: '$css window.folio && folio.init($payload)',
          );
        },
        onRenderProcessGone: (webController, detail) {
          if (!mounted) return;
          debugPrint(
            'OfficeDocumentView: el proceso del WebView terminó '
            '(crash: ${detail.didCrash})',
          );
          widget.controller.fail(
            ViewerFailure(
              ViewerFailureKind.engine,
              detail: 'Proceso del WebView terminado (crash: ${detail.didCrash})',
            ),
          );
        },
        onReceivedError: (webController, request, error) {
          if (!mounted) return;
          if (request.isForMainFrame ?? true) {
            debugPrint(
              'OfficeDocumentView: error al cargar (${error.type}): ${error.description}',
            );
            widget.controller.fail(
              ViewerFailure(
                ViewerFailureKind.engine,
                detail: '${error.type}: ${error.description}',
              ),
            );
          }
        },
      ),
    );
  }
}

/// JS que fija los márgenes del contenido (`--inset-top` / `--inset-bottom`,
/// en px CSS = dp) que usa `assets/engines/common/base.css`.
String documentInsetsJs(EdgeInsets insets) {
  final root = 'document.documentElement.style';
  return "$root.setProperty('--inset-top','${insets.top.round()}px');"
      "$root.setProperty('--inset-bottom','${insets.bottom.round()}px');";
}
