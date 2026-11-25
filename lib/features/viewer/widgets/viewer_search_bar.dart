import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';
import '../viewer_controller.dart';

/// Barra de búsqueda del visor que reemplaza a la barra superior mientras
/// está activa.
class ViewerSearchBar extends StatefulWidget {
  const ViewerSearchBar({
    super.key,
    required this.search,
    required this.onClose,
  });

  final ViewerSearch search;
  final VoidCallback onClose;

  @override
  State<ViewerSearchBar> createState() => _ViewerSearchBarState();
}

class _ViewerSearchBarState extends State<ViewerSearchBar> {
  static const _debounceDelay = Duration(milliseconds: 350);

  late final TextEditingController _textController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.search.query);
  }

  @override
  void didUpdateWidget(covariant ViewerSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search &&
        _textController.text != widget.search.query) {
      _debounceTimer?.cancel();
      _textController.text = widget.search.query;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      widget.search.clear();
      return;
    }
    _debounceTimer = Timer(_debounceDelay, () {
      if (!mounted) return;
      widget.search.search(value);
    });
  }

  void _onSubmitted(String value) {
    final pending = _debounceTimer?.isActive ?? false;
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      widget.search.clear();
      return;
    }
    if (pending || value != widget.search.query) {
      widget.search.search(value);
      return;
    }
    if (widget.search.matchCount > 0) {
      widget.search.next();
    }
  }

  void _close() {
    _debounceTimer?.cancel();
    widget.search.clear();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textTheme = Theme.of(context).textTheme;
    final counterStyle = textTheme.labelMedium?.copyWith(
      color: folio.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Material(
      color: folio.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: folio.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FolioTokens.s4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: FolioTokens.iconBar,
                    ),
                    tooltip: 'Cerrar búsqueda',
                    onPressed: _close,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      autofocus: true,
                      maxLines: 1,
                      style: textTheme.bodyLarge,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: _onSubmitted,
                      decoration: const InputDecoration(
                        hintText: 'Buscar en el documento',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: FolioTokens.s12,
                          vertical: FolioTokens.s8,
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.search,
                    builder: (context, _) {
                      final count = widget.search.matchCount;
                      final current = widget.search.currentIndex;
                      final isSearching = widget.search.isSearching;
                      final hasResults = count > 0;
                      final hasQuery = widget.search.query.isNotEmpty;

                      final Widget status;
                      if (hasResults) {
                        final displayIndex = current >= 0 ? current + 1 : 0;
                        status = Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FolioTokens.s8,
                          ),
                          child: Text(
                            '$displayIndex de $count',
                            style: counterStyle,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        );
                      } else if (isSearching) {
                        status = const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: FolioTokens.s12,
                          ),
                          child: SizedBox(
                            width: FolioTokens.s16,
                            height: FolioTokens.s16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      } else if (hasQuery) {
                        status = Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FolioTokens.s8,
                          ),
                          child: Text(
                            'Sin resultados',
                            style: counterStyle,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        );
                      } else {
                        status = const SizedBox(width: FolioTokens.s4);
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          status,
                          IconButton(
                            icon: const Icon(
                              LucideIcons.chevronUp,
                              size: FolioTokens.iconBar,
                            ),
                            tooltip: 'Resultado anterior',
                            onPressed:
                                hasResults ? widget.search.previous : null,
                          ),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.chevronDown,
                              size: FolioTokens.iconBar,
                            ),
                            tooltip: 'Siguiente resultado',
                            onPressed: hasResults ? widget.search.next : null,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
