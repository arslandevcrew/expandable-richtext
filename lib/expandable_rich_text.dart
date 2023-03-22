library expandable_richtext;

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:expandable_richtext/text_parser.dart';
import 'package:expandable_richtext/text_segment.dart';

typedef StringCallback = void Function(String value);

class ExpandableRichText extends StatefulWidget {
  ExpandableRichText(
    this.text, {
    Key? key,
    this.expandText,
    this.collapseText,
    this.expanded = false,
    this.onExpandedChanged,
    this.onToggleTextTap,
    this.toggleTextColor,
    this.showEllipsis = true,
    this.toggleTextStyle,
    this.urlStyle,
    this.onUrlTap,
    this.hashtagStyle,
    this.onHashtagTap,
    this.mentionStyle,
    this.onMentionTap,
    this.customTagStyle,
    this.customTagStyles,
    this.onCustomTagTap,
    this.expandOnTextTap = false,
    this.collapseOnTextTap = false,
    this.style,
    this.textDirection,
    this.textAlign,
    this.textScaleFactor,
    this.maxLines = 2,
    this.animation = false,
    this.animationDuration,
    this.animationCurve,
  }) : super(key: key);

  final String text;

  /// text to show to expand text e.g 'see more'
  final String? expandText;

  /// text to show to collapse text e.g 'see less'
  final String? collapseText;

  /// control text toggle
  final bool expanded;

  /// listen for text collapse and expand event
  final ValueChanged<bool>? onExpandedChanged;

  /// listen for click on toggle text(expandText/collapseText)
  VoidCallback? onToggleTextTap;
  final Color? toggleTextColor;

  ///control show '...' with toggle text
  final bool showEllipsis;
  final TextStyle? toggleTextStyle;
  final TextStyle? urlStyle;
  final StringCallback? onUrlTap;
  final TextStyle? hashtagStyle;
  final StringCallback? onHashtagTap;
  final TextStyle? mentionStyle;
  final StringCallback? onMentionTap;

  /// single style to apply on all custom tags
  final TextStyle? customTagStyle;

  ///multiple styles to apply on multiple custom tags
  final Map<String, TextStyle>? customTagStyles;
  final StringCallback? onCustomTagTap;

  /// control to expand text on tap on whole text
  final bool expandOnTextTap;

  /// control to collapse text on tap on whole text
  final bool collapseOnTextTap;

  /// default text style
  final TextStyle? style;
  final TextDirection? textDirection;
  final TextAlign? textAlign;
  final double? textScaleFactor;
  final int maxLines;

  /// expand and collapse animation
  final bool animation;
  final Duration? animationDuration;
  final Curve? animationCurve;

  /// listen to call widget function [_toggleText] if programmatically want to toggle text
  late VoidCallback? toggle;

  @override
  State<ExpandableRichText> createState() => _ExpandableRichTextState();
}

class _ExpandableRichTextState extends State<ExpandableRichText> {
  bool _expanded = false;
  late TapGestureRecognizer _toggleTextGestureRecognizer;
  List<TextSegment> _textSegments = [];
  final List<TapGestureRecognizer> _textSegmentsTapGestureRecognizers = [];
  late TextStyle effectiveTextStyle;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
    _toggleTextGestureRecognizer = TapGestureRecognizer()
      ..onTap = _onTapToggleText;
    _updateText();
  }

  @override
  Widget build(BuildContext context) {
    widget.toggle = _toggleText;
    final defaultTextStyle = DefaultTextStyle.of(context);
    effectiveTextStyle = widget.style ?? defaultTextStyle.style;

    if (widget.expandText == null) {
      ///simple text without expand and collapse
      return RichText(text: _contentTextSpan());
    } else {
      final toggleTextSpan = _toggleTextSpan();
      final contentTextSpan = _contentTextSpan();

      Widget expandableRichText = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        assert(constraints.hasBoundedWidth);
        final double maxWidth = constraints.maxWidth;

        final textAlign =
            widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
        final textDirection =
            widget.textDirection ?? Directionality.of(context);
        final textScaleFactor =
            widget.textScaleFactor ?? MediaQuery.textScaleFactorOf(context);
        final locale = Localizations.maybeLocaleOf(context);

        TextPainter textPainter = TextPainter(
          text: toggleTextSpan,
          textAlign: textAlign,
          textDirection: textDirection,
          textScaleFactor: textScaleFactor,
          maxLines: widget.maxLines,
          locale: locale,
        );
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final toggleTextSize = textPainter.size;

        textPainter.text = contentTextSpan;
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final contentTextSize = textPainter.size;

        TextSpan textSpan;
        if (textPainter.didExceedMaxLines) {
          final position = textPainter.getPositionForOffset(Offset(
            contentTextSize.width - toggleTextSize.width,
            contentTextSize.height,
          ));
          final endOffset = (textPainter.getOffsetBefore(position.offset) ?? 0);
          final recognizer =
              (_expanded ? widget.collapseOnTextTap : widget.expandOnTextTap)
                  ? _toggleTextGestureRecognizer
                  : null;
          final text = _expanded
              ? contentTextSpan
              : TextSpan(
                  children: _buildTextSpans(
                      parseText(widget.text.substring(0, max(endOffset, 0))),
                      effectiveTextStyle,
                      recognizer));
          textSpan = TextSpan(
            style: effectiveTextStyle,
            children: <TextSpan>[
              text,
              toggleTextSpan,
            ],
          );
        } else {
          textSpan = contentTextSpan;
        }
        final richText = RichText(
          text: textSpan,
          softWrap: true,
          textDirection: textDirection,
          textAlign: textAlign,
          textScaleFactor: textScaleFactor,
          overflow: TextOverflow.clip,
        );

        if (widget.animation) {
          return AnimatedSize(
            duration:
                widget.animationDuration ?? const Duration(milliseconds: 200),
            curve: widget.animationCurve ?? Curves.fastLinearToSlowEaseIn,
            alignment: Alignment.topLeft,
            child: richText,
          );
        }
        return richText;
      });
      return expandableRichText;
    }
  }

  @override
  void didUpdateWidget(covariant ExpandableRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _updateText();
  }

  @override
  void dispose() {
    super.dispose();
    _toggleTextGestureRecognizer.dispose();
    for (var recognizer in _textSegmentsTapGestureRecognizers) {
      recognizer.dispose();
    }
  }

  void _onTapToggleText() {
    if (widget.onToggleTextTap != null) {
      widget.onToggleTextTap!();
      return;
    }
    _toggleText();
  }

  /// change the state of [_expanded] to show/hide text
  void _toggleText() {
    final toggledExpanded = !_expanded;
    setState(() => _expanded = toggledExpanded);
    widget.onExpandedChanged?.call(toggledExpanded);
  }

  void _updateText() {
    for (var recognizer in _textSegmentsTapGestureRecognizers) {
      recognizer.dispose();
    }
    _textSegmentsTapGestureRecognizers.clear();
    _textSegments.clear();
    _textSegments = parseText(widget.text);
    addTextSegmentTapGestures();
  }

  /// get span for toggle text used for expand and collapse
  TextSpan _toggleTextSpan() {
    final linkText =
        (_expanded ? widget.collapseText : widget.expandText) ?? '';
    final linkTextStyle = effectiveTextStyle.merge(widget.toggleTextStyle);

    return TextSpan(
      children: [
        if (!_expanded)
          TextSpan(
            text: '\u2026 ',
            style: widget.showEllipsis ? linkTextStyle : effectiveTextStyle,
            recognizer:
                widget.showEllipsis ? _toggleTextGestureRecognizer : null,
          ),
        if (linkText.isNotEmpty)
          TextSpan(
            style: effectiveTextStyle,
            children: <TextSpan>[
              if (_expanded)
                const TextSpan(
                  text: ' ',
                ),
              TextSpan(
                text: linkText,
                style: linkTextStyle,
                recognizer: _toggleTextGestureRecognizer,
              ),
            ],
          ),
      ],
    );
  }

  /// get text span for given text
  /// if text has no special formatting then return simple span
  /// else apply style for each text segment
  TextSpan _contentTextSpan() {
    return _textSegments.isNotEmpty
        ? TextSpan(
            children: _buildTextSpans(_textSegments, effectiveTextStyle, null))
        : TextSpan(text: widget.text);
  }

  List<TextSpan> _buildTextSpans(List<TextSegment> segments,
      TextStyle textStyle, TapGestureRecognizer? textTapRecognizer) {
    final spans = <TextSpan>[];
    var index = 0;
    for (var segment in segments) {
      TextStyle? style;
      TapGestureRecognizer? recognizer;

      if (segment.isUrl) {
        style = textStyle.merge(widget.urlStyle);
        if (widget.onUrlTap != null) {
          recognizer = _textSegmentsTapGestureRecognizers[index++];
        }
      } else if (segment.isMention) {
        style = textStyle.merge(widget.mentionStyle);
        if (widget.onMentionTap != null) {
          recognizer = _textSegmentsTapGestureRecognizers[index++];
        }
      } else if ((segment.isHashtag)) {
        style = textStyle.merge(widget.hashtagStyle);
        if (widget.onHashtagTap != null) {
          recognizer = _textSegmentsTapGestureRecognizers[index++];
        }
      } else if (segment.isTag) {
        if (widget.customTagStyles != null) {
          final s = widget.customTagStyles![segment.tagName];
          if (s != null) {
            style = textStyle.merge(s);
          }
        } else {
          style = textStyle.merge(widget.customTagStyle);
        }
        if (widget.onCustomTagTap != null) {
          recognizer = _textSegmentsTapGestureRecognizers[index++];
        }
      }

      final span = TextSpan(
        text: segment.text,
        style: style ?? textStyle,
        recognizer: recognizer ?? textTapRecognizer,
      );
      spans.add(span);
    }
    return spans;
  }

  void addTextSegmentTapGestures() {
    for (var element in _textSegments) {
      if (element.isUrl && widget.onUrlTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            widget.onUrlTap!(element.name!);
          };

        _textSegmentsTapGestureRecognizers.add(recognizer);
      } else if ((element.isHashtag) && widget.onHashtagTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            widget.onHashtagTap!(element.name!);
          };

        _textSegmentsTapGestureRecognizers.add(recognizer);
      } else if (element.isMention && widget.onMentionTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            widget.onMentionTap!(element.name!);
          };

        _textSegmentsTapGestureRecognizers.add(recognizer);
      } else if (element.isTag && widget.onCustomTagTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            widget.onCustomTagTap!(element.name!);
          };
        _textSegmentsTapGestureRecognizers.add(recognizer);
      }
    }
  }
}
