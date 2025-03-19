import 'package:flutter/material.dart';

class ResizableColumn extends StatefulWidget {
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final Widget child;
  final ValueChanged<double> onResize;

  const ResizableColumn({
    super.key,
    required this.initialWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.child,
    required this.onResize,
  });

  @override
  State<ResizableColumn> createState() => _ResizableColumnState();
}

class _ResizableColumnState extends State<ResizableColumn> {
  late double width;
  bool isDragging = false;
  bool isHovered = false;

  @override
  void initState() {
    super.initState();
    width = widget.initialWidth;
  }

  @override
  void didUpdateWidget(ResizableColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWidth != widget.initialWidth) {
      width = widget.initialWidth;
    }
  }

  void _handleDrag(DragUpdateDetails details) {
    final newWidth = width + details.delta.dx;
    if (newWidth >= widget.minWidth && newWidth <= widget.maxWidth) {
      setState(() {
        width = newWidth;
      });
      widget.onResize(width);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: -12,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => isHovered = true),
              onExit: (_) => setState(() => isHovered = false),
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => isDragging = true),
                onHorizontalDragUpdate: _handleDrag,
                onHorizontalDragEnd: (_) => setState(() => isDragging = false),
                child: Container(
                  width: 24,
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: isDragging ? 6 : (isHovered ? 4 : 3),
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: isDragging
                            ? Theme.of(context).colorScheme.primary
                            : (isHovered
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                : Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
