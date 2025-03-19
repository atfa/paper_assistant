import 'package:flutter/material.dart';

class ResizableColumn extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final VoidCallback onResize;

  const ResizableColumn({
    super.key,
    required this.child,
    required this.initialWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
  });

  @override
  State<ResizableColumn> createState() => _ResizableColumnState();
}

class _ResizableColumnState extends State<ResizableColumn> {
  late double width;
  bool isDragging = false;
  double dragStartX = 0;
  double dragStartWidth = 0;

  @override
  void initState() {
    super.initState();
    width = widget.initialWidth;
  }

  void _startDragging(DragStartDetails details) {
    setState(() {
      isDragging = true;
      dragStartX = details.globalPosition.dx;
      dragStartWidth = width;
    });
  }

  void _drag(DragUpdateDetails details) {
    if (!isDragging) return;

    final delta = details.globalPosition.dx - dragStartX;
    final newWidth = dragStartWidth + delta;

    setState(() {
      width = newWidth.clamp(widget.minWidth, widget.maxWidth);
    });
    widget.onResize();
  }

  void _endDragging(DragEndDetails details) {
    setState(() {
      isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onPanStart: _startDragging,
                onPanUpdate: _drag,
                onPanEnd: _endDragging,
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(1),
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
