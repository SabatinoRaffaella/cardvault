import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

enum _BundleDirection { remove, next, previous }

/// A hold claims the gesture, leaving ordinary vertical page scroll free.
class CheckoutBundleGesture extends StatefulWidget {
  const CheckoutBundleGesture(
      {super.key,
      required this.targetId,
      required this.child,
      this.onRemove,
      this.onNext,
      this.onPrevious,
      this.selected,
      this.selectionLabel = 'Seleziona gruppo',
      this.onToggleSelection});
  final String targetId;
  final Widget child;
  final VoidCallback? onRemove, onNext, onPrevious;
  final bool? selected;
  final String selectionLabel;
  final VoidCallback? onToggleSelection;
  @override
  State<CheckoutBundleGesture> createState() => _CheckoutBundleGestureState();
}

class _CheckoutBundleGestureState extends State<CheckoutBundleGesture> {
  Offset _offset = Offset.zero;
  _BundleDirection? _direction;
  bool _holding = false;
  bool _selectionVisible = false;
  VoidCallback? _removeAtStart;
  static const _threshold = 80.0;

  void _reset() {
    _holding = false;
    _selectionVisible = false;
    _offset = Offset.zero;
    _direction = null;
    _removeAtStart = null;
  }

  @override
  void didUpdateWidget(CheckoutBundleGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId) _reset();
  }

  void _move(LongPressMoveUpdateDetails details) {
    if (!_holding) return;
    final delta = details.offsetFromOrigin;
    if (_direction == null && delta.distance > 18) {
      if (delta.dy < 0 &&
          delta.dy.abs() > delta.dx.abs() * 1.2 &&
          _removeAtStart != null) {
        _direction = _BundleDirection.remove;
      } else if (delta.dx.abs() > delta.dy.abs() * 1.2) {
        if (delta.dx < 0 && widget.onNext != null) {
          _direction = _BundleDirection.next;
        }
        if (delta.dx > 0 && widget.onPrevious != null) {
          _direction = _BundleDirection.previous;
        }
      }
    }
    setState(() {
      _offset = switch (_direction) {
        _BundleDirection.remove => Offset(0, delta.dy.clamp(-160.0, 0.0)),
        _BundleDirection.next => Offset(delta.dx.clamp(-160.0, 0.0), 0),
        _BundleDirection.previous => Offset(delta.dx.clamp(0.0, 160.0), 0),
        null => Offset.zero,
      };
    });
  }

  void _finish(LongPressEndDetails _) {
    if (!_holding) return;
    final action = _offset.distance >= _threshold
        ? switch (_direction) {
            _BundleDirection.remove => _removeAtStart,
            _BundleDirection.next => widget.onNext,
            _BundleDirection.previous => widget.onPrevious,
            null => null,
          }
        : null;
    final keepSelection = action == null && _selectionVisible;
    setState(() {
      _reset();
      _selectionVisible = keepSelection;
    });
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _offset.distance >= _threshold;
    final label = !_holding
        ? 'Tieni premuto per selezionare o trascinare'
        : switch (_direction) {
            _BundleDirection.remove => ready
                ? 'Rilascia per rimuovere una copia'
                : 'Trascina ancora verso l’alto',
            _BundleDirection.next => ready
                ? 'Rilascia per il bundle successivo'
                : 'Trascina ancora a sinistra',
            _BundleDirection.previous => ready
                ? 'Rilascia per il bundle precedente'
                : 'Trascina ancora a destra',
            null => '↑ Rimuovi una copia · ← Cambia bundle',
          };
    return Semantics(
        customSemanticsActions: widget.onToggleSelection == null
            ? null
            : {
                CustomSemanticsAction(label: widget.selectionLabel):
                    widget.onToggleSelection!,
              },
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: _selectionVisible &&
                      _direction == null &&
                      widget.onToggleSelection != null
                  ? Semantics(
                      liveRegion: true,
                      child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 5,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                              onTap: widget.onToggleSelection,
                              child: Row(children: [
                                Checkbox(
                                    tristate: true,
                                    value: widget.selected,
                                    semanticLabel: widget.selectionLabel,
                                    onChanged: (_) =>
                                        widget.onToggleSelection?.call()),
                                Expanded(
                                    child: Text(widget.selectionLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis)),
                                IconButton(
                                    tooltip: 'Chiudi selezione gruppo',
                                    onPressed: () => setState(
                                        () => _selectionVisible = false),
                                    icon: const Icon(Icons.close, size: 18)),
                              ]))))
                  : Center(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ready
                                  ? Theme.of(context).colorScheme.primary
                                  : null)))),
          GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (_) {
                _removeAtStart = widget.onRemove;
                setState(() {
                  _holding = true;
                  _selectionVisible = widget.onToggleSelection != null;
                });
                HapticFeedback.selectionClick();
              },
              onLongPressMoveUpdate: _move,
              onLongPressEnd: _finish,
              onLongPressCancel: () {
                if (_holding) setState(_reset);
              },
              child: AnimatedContainer(
                  duration: _holding || MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transform:
                      Matrix4.translationValues(_offset.dx, _offset.dy, 0),
                  child: widget.child)),
        ]));
  }
}
