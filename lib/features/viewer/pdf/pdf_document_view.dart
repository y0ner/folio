import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/files/document_ref.dart';
import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';
import '../viewer_controller.dart';
import 'pdf_password_dialog.dart';
import 'pdf_scroll_thumb.dart';
import 'pdf_search.dart';

/// Cuerpo del visor para PDF basado en `pdfrx`.
class PdfDocumentView extends StatefulWidget {
  const PdfDocumentView({
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
  State<PdfDocumentView> createState() => _PdfDocumentViewState();
}

class _PdfDocumentViewState extends State<PdfDocumentView> {
  // PdfViewerController en pdfrx 3.0.0 no tiene dispose(); su ciclo de vida
  // lo gestiona internamente el widget PdfViewer.
  final _pdfController = PdfViewerController();
  late final List<PdfViewerPagePaintCallback> _pagePaintCallbacks = [
    _paintSearchMatches,
  ];

  PdfViewerSearch? _search;
  bool _passwordAttempted = false;
  bool _passwordCancelled = false;
  bool _reportedFailure = false;

  @override
  void didUpdateWidget(covariant PdfDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.path != widget.document.path) {
      _passwordAttempted = false;
      _passwordCancelled = false;
      _reportedFailure = false;
      _search?.clear();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.attach();
      if (_pdfController.isReady) {
        _attachViewerController(_pdfController);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.attach();
    _search?.dispose();
    _search = null;
    super.dispose();
  }

  void _attachViewerController(PdfViewerController pdfController) {
    widget.controller.attach(
      onGoToPage: (page) => unawaited(pdfController.goToPage(pageNumber: page)),
      search: _search,
    );
  }

  void _paintSearchMatches(Canvas canvas, Rect pageRect, PdfPage page) {
    _search?.paintMatches(canvas, pageRect, page);
  }

  Future<String?> _providePassword() async {
    if (!mounted) return null;
    final wrongPassword = _passwordAttempted;
    _passwordAttempted = true;
    final password = await PdfPasswordDialog.show(
      context,
      incorrectPassword: wrongPassword,
    );
    if (password == null) {
      _passwordCancelled = true;
    }
    return password;
  }

  bool _handleGeneralTap(
    BuildContext context,
    PdfViewerController pdfController,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type == PdfViewerGeneralTapType.doubleTap) {
      unawaited(
        pdfController.zoomUpOnLocalPosition(
          localPosition: details.localPosition,
          loop: true,
        ),
      );
      return true;
    }
    if (details.type != PdfViewerGeneralTapType.tap) {
      return false;
    }
    // Si hay texto seleccionado o se toca sobre la selección, dejamos que
    // pdfrx limpie la selección sin alternar las barras.
    if (pdfController.textSelectionDelegate.hasSelectedText ||
        details.tapOn == PdfViewerPart.selectedText) {
      return false;
    }
    widget.onTap();
    return true;
  }

  void _handleLinkTap(PdfLink link) {
    final dest = link.dest;
    // Solo navegamos enlaces internos del PDF; los externos se ignoran.
    if (dest == null) return;
    unawaited(_pdfController.goToDest(dest));
  }

  void _handleDocumentLoadFinished(
    PdfDocumentRef documentRef,
    bool loadSucceeded,
  ) {
    if (loadSucceeded || !mounted || _reportedFailure) return;
    _reportedFailure = true;
    final error = documentRef.resolveListenable().error;
    debugPrint('PdfDocumentView: error al cargar el PDF: $error');
    if (error is PdfPasswordException || _passwordCancelled) {
      widget.controller.fail(
        ViewerFailure(
          ViewerFailureKind.encrypted,
          detail: error?.toString(),
        ),
      );
    } else {
      widget.controller.fail(
        ViewerFailure(
          ViewerFailureKind.corrupt,
          detail: '$error',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return DefaultSelectionStyle(
      selectionColor: folio.accent.withValues(alpha: 0.3),
      child: PdfViewer.file(
        widget.document.path,
        controller: _pdfController,
        passwordProvider: _providePassword,
        params: PdfViewerParams(
          backgroundColor: folio.canvas,
          layoutStrategy: const SequentialPagesLayout(
            spacing: FolioTokens.s12,
            margin: FolioTokens.s12,
          ),
          sizeDelegateProvider: const PdfViewerSizeDelegateProviderSmart(
            smartMaxScale: double.infinity,
            maxPagesVisible: 1.0,
          ),
          pageDropShadow: BoxShadow(
            // Única excepción permitida a la regla de Colors.*: no hay token
            // de sombra de página en FolioColors.
            color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          textSelectionParams: const PdfTextSelectionParams(enabled: true),
          matchTextColor: folio.accent.withValues(alpha: 0.25),
          activeMatchTextColor: folio.accent.withValues(alpha: 0.55),
          pagePaintCallbacks: _pagePaintCallbacks,
          linkHandlerParams: PdfLinkHandlerParams(
            onLinkTap: _handleLinkTap,
            linkColor: Colors.transparent,
            enableAutoLinkDetection: false,
          ),
          onGeneralTap: _handleGeneralTap,
          viewerOverlayBuilder: (context, size, handleLinkTap) => [
            FolioPdfScrollThumb(controller: _pdfController),
          ],
          errorBannerBuilder: (context, error, stackTrace, documentRef) =>
              const SizedBox.shrink(),
          onDocumentLoadFinished: _handleDocumentLoadFinished,
          onViewerReady: (document, pdfController) {
            _search?.dispose();
            _search = PdfViewerSearch(pdfController);
            _attachViewerController(pdfController);
            widget.controller.markReady(pageCount: document.pages.length);
          },
          onPageChanged: (pageNumber) {
            if (pageNumber != null) {
              widget.controller.setPage(pageNumber);
            }
          },
        ),
      ),
    );
  }
}
