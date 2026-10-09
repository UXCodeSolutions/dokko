import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';
import 'dokko_button.dart';

class DokkoTableColumn {
  final String title;
  final double? width;
  final int? flex;
  final Widget Function(dynamic item)? customRender;

  const DokkoTableColumn({
    required this.title,
    this.width,
    this.flex,
    this.customRender,
  });
}

class DokkoTable<T> extends StatefulWidget {
  final List<DokkoTableColumn> columns;
  final List<T> data;
  final String Function(T item, int columnIndex) cellValue;
  final void Function(T item)? onRowTap;
  final bool selectable;
  final int totalItems;
  final int currentPage;
  final void Function(int page)? onPageChanged;

  const DokkoTable({
    super.key,
    required this.columns,
    required this.data,
    required this.cellValue,
    this.onRowTap,
    this.selectable = false,
    this.totalItems = 0,
    this.currentPage = 1,
    this.onPageChanged,
  });

  @override
  State<DokkoTable<T>> createState() => _DokkoTableState<T>();
}

class _DokkoTableState<T> extends State<DokkoTable<T>> {
  final Set<int> _selectedIndices = {};
  int? _hoveredRowIndex;

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          color: DokkoTokens.surface2,
          padding: const EdgeInsets.symmetric(vertical: DokkoTokens.space12, horizontal: DokkoTokens.space16),
          child: Row(
            children: [
              if (widget.selectable)
                const SizedBox(width: 32), // Checkbox spacer
              ...widget.columns.map((col) => _buildHeaderCell(col)),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ListView.builder(
            itemCount: widget.data.length,
            itemBuilder: (context, index) {
              final item = widget.data[index];
              final isSelected = _selectedIndices.contains(index);
              final isHovered = _hoveredRowIndex == index;

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredRowIndex = index),
                onExit: (_) => setState(() => _hoveredRowIndex = null),
                cursor: widget.onRowTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: () {
                    if (widget.onRowTap != null) {
                      widget.onRowTap!(item);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isHovered || isSelected ? DokkoTokens.surface : Colors.transparent,
                      border: Border(
                        top: index == 0 ? BorderSide.none : const BorderSide(color: DokkoTokens.line),
                      ),
                    ),
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: DokkoTokens.space16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.selectable)
                          SizedBox(
                            width: 32,
                            child: (isHovered || isSelected || _selectedIndices.isNotEmpty)
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      _toggleSelection(index);
                                    },
                                    activeColor: DokkoTokens.accentDefault,
                                    side: const BorderSide(color: DokkoTokens.text3),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ...widget.columns.asMap().entries.map((entry) {
                          final colIndex = entry.key;
                          final col = entry.value;
                          return _buildDataCell(col, item, colIndex);
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Pagination
        if (widget.totalItems > 25)
          Container(
            padding: const EdgeInsets.all(DokkoTokens.space12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DokkoTokens.line)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${((widget.currentPage - 1) * 25) + 1} - ${((widget.currentPage) * 25).clamp(0, widget.totalItems)} de ${widget.totalItems}',
                  style: const TextStyle(color: DokkoTokens.text2, fontSize: 12),
                ),
                const SizedBox(width: DokkoTokens.space16),
                DokkoButton(
                  label: 'Anterior',
                  variant: DokkoButtonVariant.secondary,
                  isDisabled: widget.currentPage == 1,
                  onPressed: () {
                    if (widget.onPageChanged != null) {
                      widget.onPageChanged!(widget.currentPage - 1);
                    }
                  },
                ),
                const SizedBox(width: DokkoTokens.space8),
                DokkoButton(
                  label: 'Siguiente',
                  variant: DokkoButtonVariant.secondary,
                  isDisabled: (widget.currentPage * 25) >= widget.totalItems,
                  onPressed: () {
                    if (widget.onPageChanged != null) {
                      widget.onPageChanged!(widget.currentPage + 1);
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderCell(DokkoTableColumn col) {
    Widget text = Text(
      col.title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        color: DokkoTokens.text2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    if (col.width != null) {
      return SizedBox(width: col.width, child: text);
    }
    return Expanded(flex: col.flex ?? 1, child: text);
  }

  Widget _buildDataCell(DokkoTableColumn col, T item, int colIndex) {
    Widget content;
    if (col.customRender != null) {
      content = col.customRender!(item);
    } else {
      content = Text(
        widget.cellValue(item, colIndex),
        style: const TextStyle(color: DokkoTokens.text, fontSize: 13),
      );
    }

    if (col.width != null) {
      return SizedBox(width: col.width, child: content);
    }
    return Expanded(flex: col.flex ?? 1, child: content);
  }
}
