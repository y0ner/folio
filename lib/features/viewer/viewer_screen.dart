import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/files/doc_kind.dart';
import '../../core/files/document_ref.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';
import 'office/office_document_view.dart';
import 'pdf/pdf_document_view.dart';
import 'viewer_controller.dart';
import 'widgets/document_info_sheet.dart';
import 'widgets/go_to_page_dialog.dart';
import 'widgets/page_indicator.dart';
import 'widgets/section_bar.dart';
import 'widgets/viewer_error_view.dart';
import 'widgets/viewer_top_bar.dart';

/// Pantalla del visor: barras, modo inmersivo, indicador, carga y errores
/// alrededor del cuerpo correspondiente a cada tipo de documento.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.document,
    @visibleForTesting this.controller,
  });

  final DocumentRef document;
  final ViewerController? controller;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  static const _loadingDelay = Duration(milliseconds: 300);

  late ViewerController _controller;
  late bool _ownsController;
  bool _fileExists = false;
  bool _barsVisible = true;
  bool _showLoading = false;
  bool _lastSystemUiVisible = true;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _initController();
    _checkFileAndStartLoading();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _initController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ViewerController();
    _controller.addListener(_onControllerChanged);
  }

  void _checkFileAndStartLoading() {
    _fileExists = File(widget.document.path).existsSync();
    if (!_fileExists) {
      _controller.fail(const ViewerFailure(ViewerFailureKind.missing));
      return;
    }
    _scheduleLoadingIndicator();
  }

  void _scheduleLoadingIndicator() {
    _loadingTimer?.cancel();
    _showLoading = false;
    if (_controller.status != ViewerStatus.loading) return;
    _loadingTimer = Timer(_loadingDelay, () {
      if (!mounted || _controller.status != ViewerStatus.loading) return;
      setState(() => _showLoading = true);
    });
  }

  void _onControllerChanged() {
    if (_controller.status != ViewerStatus.loading) {
      _loadingTimer?.cancel();
      _loadingTimer = null;
      _showLoading = false;
    }
    _syncSystemUiMode();
  }

  @override
  void didUpdateWidget(covariant ViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
    }
    if (oldWidget.document.path != widget.document.path) {
      _checkFileAndStartLoading();
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _effectiveBarsVisible =>
      _controller.status != ViewerStatus.ready || _barsVisible;

  void _syncSystemUiMode() {
    final visible = _effectiveBarsVisible;
    if (visible == _lastSystemUiVisible) return;
    _lastSystemUiVisible = visible;
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _toggleChrome() {
    if (_controller.status != ViewerStatus.ready) return;
    setState(() {
      _barsVisible = !_barsVisible;
    });
    _syncSystemUiMode();
  }

  Future<void> _shareDocument() async {
    if (!File(widget.document.path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo ya no está en el dispositivo.'),
        ),
      );
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(widget.document.path)]),
      );
    } catch (error, stackTrace) {
      debugPrint('Error al compartir documento: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el archivo.')),
      );
    }
  }

  Future<void> _openDocumentInfo(int pageCount) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DocumentInfoSheet(
        document: widget.document,
        pageCount: pageCount,
      ),
    );
  }

  Future<void> _openGoToPageDialog(int pageCount) async {
    final page = await showDialog<int>(
      context: context,
      builder: (_) => GoToPageDialog(pageCount: pageCount),
    );
    if (page != null && mounted) {
      _controller.goToPage(page);
    }
  }

  Widget _buildDocumentBody() {
    final doc = widget.document;
    return switch (doc.kind) {
      DocKind.pdf => PdfDocumentView(
          document: doc,
          controller: _controller,
          onTap: _toggleChrome,
        ),
      _ => OfficeDocumentView(
          document: doc,
          controller: _controller,
          onTap: _toggleChrome,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final status = _controller.status;
        final failure = _controller.failure;
        final isReady = status == ViewerStatus.ready;
        final showBars = _effectiveBarsVisible;
        final hasSections = isReady && _controller.sections.length > 1;
        final hasPageIndicator =
            !hasSections && isReady && _controller.pageCount > 1;
        final isMissing =
            status == ViewerStatus.failed &&
            failure?.kind == ViewerFailureKind.missing;

        return Scaffold(
          backgroundColor: folio.canvas,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              if (_fileExists) Positioned.fill(child: _buildDocumentBody()),
              if (status == ViewerStatus.loading && _showLoading)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: FolioTokens.s12),
                          Text(
                            'Abriendo documento…',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (status == ViewerStatus.failed)
                Positioned.fill(
                  child: ViewerErrorView(
                    failure: failure ??
                        const ViewerFailure(ViewerFailureKind.engine),
                    onShare: _shareDocument,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              if (hasPageIndicator)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: FolioTokens.s16,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: _ChromeOverlay(
                        visible: showBars,
                        hiddenOffset: const Offset(0, 1.5),
                        child: PageIndicator(
                          currentPage: _controller.currentPage,
                          pageCount: _controller.pageCount,
                          onTap: () =>
                              _openGoToPageDialog(_controller.pageCount),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasSections)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ChromeOverlay(
                    visible: showBars,
                    hiddenOffset: const Offset(0, 1),
                    child: SectionBar(
                      sections: _controller.sections,
                      currentSection: _controller.currentSection,
                      onSelectSection: _controller.selectSection,
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ChromeOverlay(
                  visible: showBars,
                  hiddenOffset: const Offset(0, -1),
                  child: ViewerTopBar(
                    document: widget.document,
                    canGoToPage: isReady && _controller.pageCount > 1,
                    onBack: () => Navigator.of(context).maybePop(),
                    onShare: isMissing ? null : _shareDocument,
                    onShowInfo: () => _openDocumentInfo(_controller.pageCount),
                    onGoToPage: () =>
                        _openGoToPageDialog(_controller.pageCount),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChromeOverlay extends StatelessWidget {
  const _ChromeOverlay({
    required this.visible,
    required this.hiddenOffset,
    required this.child,
  });

  final bool visible;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : hiddenOffset,
      duration: FolioTokens.normal,
      curve: FolioTokens.curve,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: FolioTokens.normal,
        curve: FolioTokens.curve,
        child: IgnorePointer(
          ignoring: !visible,
          child: child,
        ),
      ),
    );
  }
}
