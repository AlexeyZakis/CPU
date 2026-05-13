#!/usr/bin/env python3
"""
Render selected VCD signals to one large high-resolution waveform image.

Two usage styles are supported.

1) Simple mode:
    ./render_vcd_waveform.py svg
    ./render_vcd_waveform.py png
    ./render_vcd_waveform.py pdf
    ./render_vcd_waveform.py svg dec
    ./render_vcd_waveform.py png hex --vcd-dir . --vcd-name dump.vcd --gtkw-dir . --gtkw-name test_signals.gtkw

2) Explicit mode:
    ./render_vcd_waveform.py dump.vcd test_signals.gtkw -o waves.svg
    ./render_vcd_waveform.py dump.vcd test_signals.gtkw -o waves.png --radix dec
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib
matplotlib.use("Agg")

import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle


# ============================================================
# Default parameters.
# Change these constants if you want to redefine default paths,
# names, output settings, or rendering behavior.
# ============================================================

# -------------------- Input/output defaults --------------------
# Used in simple mode when --vcd-dir is not passed.
# Does not affect explicit mode if the VCD path is given as a positional argument.
DEFAULT_VCD_DIR = "."

# Used in simple mode when --vcd-name is not passed.
# Also used as the default VCD path in explicit parser, but main() enters simple mode
# when there are no arguments, so in normal explicit usage this is overridden.
DEFAULT_VCD_NAME = "../build/dump.vcd"

# Used in simple mode when --gtkw-dir is not passed.
# Does not affect explicit mode if the GTKWave path is given as a positional argument.
DEFAULT_GTKW_DIR = "."

# Used in simple mode when --gtkw-name is not passed.
# In explicit mode it is used only if you pass a VCD positional argument but omit GTKWave.
DEFAULT_GTKW_NAME = "test_signals.gtkw"

# Used in simple mode when --out-dir is not passed.
# In explicit mode output is normally controlled by -o/--output.
DEFAULT_OUT_DIR = "result"

# Base output file name used in simple mode: DEFAULT_OUT_NAME.DEFAULT_FORMAT.
# In explicit mode it is used only for the default -o value.
DEFAULT_OUT_NAME = "waves"

# Default output format for simple mode: pdf, svg, or png.
# Does not matter if the format is passed positionally, for example: ./script.py png.
# In explicit mode the output format is taken from the -o/--output file suffix.
DEFAULT_FORMAT = "pdf"

# Default radix for bus values: hex, dec, or bin.
# It is used unless a positional radix or --radix is passed.
# It affects only multi-bit bus labels; one-bit signals are drawn as waveforms.
DEFAULT_RADIX = "hex"


# -------------------- Simple-mode rendering defaults --------------------
# Figure width in inches for simple mode.
# Works when running without positional VCD/GTKWave paths, for example ./script.py or ./script.py pdf.
# Can be overridden by --width. Larger values make time segments visually wider.
# If DEFAULT_AUTO_EXPAND_WIDTH_TO_FIT_VALUES is True, the final width may be increased,
# but never above DEFAULT_MAX_AUTO_EXPAND_WIDTH_IN.
DEFAULT_WIDTH_SIMPLE = 100.0

# Height of one signal row in inches for simple mode.
# Works in simple mode and can be overridden by --row-height.
# Increase it if rows, signal names, or bus values look too dense vertically.
DEFAULT_ROW_HEIGHT_SIMPLE = 0.5

# DPI used for simple mode.
# For PNG it directly affects raster output size and memory usage.
# For PDF/SVG the output is vector, but this value is still used by this script
# to estimate text and segment widths. Very high values with very wide figures can
# still cause high memory usage in matplotlib.
DEFAULT_DPI_SIMPLE = 300

# Maximum number of labeled bus segments per signal in simple mode.
# If a bus has more segments than this, individual values are not printed;
# instead the row shows "N changes". This prevents unreadable huge labels.
# Can be overridden by --max-labels.
DEFAULT_MAX_LABELS_SIMPLE = 10000


# -------------------- Explicit-mode rendering defaults --------------------
# Figure width in inches for explicit mode, used with positional paths:
# ./script.py dump.vcd test_signals.gtkw -o waves.pdf
# Can be overridden by --width. Same auto-expansion rules as DEFAULT_WIDTH_SIMPLE.
DEFAULT_WIDTH_EXPLICIT = 34.0

# Height of one signal row in inches for explicit mode.
# Can be overridden by --row-height.
DEFAULT_ROW_HEIGHT_EXPLICIT = 0.34

# DPI used for explicit mode.
# Same meaning as DEFAULT_DPI_SIMPLE, but for explicit mode.
DEFAULT_DPI_EXPLICIT = 200

# Maximum number of labeled bus segments per signal in explicit mode.
# Can be overridden by --max-labels-per-signal.
DEFAULT_MAX_LABELS_EXPLICIT = 180


# -------------------- Bus value fitting / auto-sizing --------------------
# Minimum desired width of a bus value cell in pixels.
# IMPORTANT: this works only when DEFAULT_AUTO_EXPAND_WIDTH_TO_FIT_VALUES = True,
# because the script must be allowed to enlarge the whole figure to honor it.
# When auto-expansion is False, this value is ignored and short cells display "..."
# if the real value does not fit.
DEFAULT_MIN_CELL_WIDTH_PX = 75

# Smallest font size used for bus values and for "..." fallback.
# Works when fitting values into bus cells. If even "..." at this size does not fit,
# the value is not drawn at all for that segment.
DEFAULT_MIN_FONT_SIZE = 4.8

# Normal font size for bus values.
# Works for multi-bit bus labels only. Signal names use DEFAULT_SIGNAL_NAME_FONT_SIZE.
# If a value does not fit at this size, the script tries to draw "..." instead.
DEFAULT_BASE_FONT_SIZE = 6.2

# Horizontal padding inside a bus value cell, in pixels.
# It reduces the usable text width inside each bus rectangle.
# Larger values make text less likely to touch cell borders, but make "..." appear sooner.
DEFAULT_LABEL_PADDING_PX = 12.0

# Horizontal offset of signal names from the right border of the name table.
# This is NOT pixels; it is an axes-coordinate offset. The right border is 0.0.
# Values slightly below zero, for example -0.004, create a small right padding.
# 0.0 means the text right edge touches the table border.
DEFAULT_SIGNAL_NAME_RIGHT_PADDING_AXES = -0.004

# Approximate character width multiplier used for text width estimation.
# Works because renderer=None is used to avoid memory-heavy canvas drawing.
# Increase it if the script still thinks text fits when it visually does not.
# Decrease it if "..." appears too early.
DEFAULT_CHAR_WIDTH_FACTOR = 0.64

# If False: the figure width is fixed, and bus values that do not fit become "...".
# If True: the script tries to enlarge the figure so values fit, using
# DEFAULT_MIN_CELL_WIDTH_PX and the measured value text width.
# Turning this on can create very wide figures for VCD files with short segments.
DEFAULT_AUTO_EXPAND_WIDTH_TO_FIT_VALUES = False

# Safety cap for automatic width expansion, in inches.
# Works only when DEFAULT_AUTO_EXPAND_WIDTH_TO_FIT_VALUES = True.
# Prevents matplotlib/Tk/X11 memory errors caused by extremely wide figures.
DEFAULT_MAX_AUTO_EXPAND_WIDTH_IN = 100.0


# -------------------- Layout --------------------
# Left margin in inches. This is the space reserved for the signal-name table.
# Increase it if signal names are clipped. Decrease it to reduce empty space on the left.
DEFAULT_LEFT_MARGIN_IN = 3.8

# Right margin in inches. This is empty space after the waveform area.
# Increase it if rightmost labels/ticks are clipped. Decrease it to use more width for data.
DEFAULT_RIGHT_MARGIN_IN = 0.5

# Top margin in inches. Needed because the time axis label and tick labels are on top.
# Increase it if "time" or top tick labels are clipped.
DEFAULT_TOP_MARGIN_IN = 0.65

# Bottom margin in inches. Since the time axis was moved to the top, this can be small.
# Increase it only if the bottom edge of the waveform/table is clipped.
DEFAULT_BOTTOM_MARGIN_IN = 0.25


# -------------------- Drawing style --------------------
# Signal-name font size. Works only for names in the left table.
DEFAULT_SIGNAL_NAME_FONT_SIZE = 7.0

# Font size for unknown one-bit values such as x/z.
DEFAULT_UNKNOWN_FONT_SIZE = 6.0

# Font size for the "N changes" fallback when a bus has too many segments to label.
DEFAULT_TOO_MANY_CHANGES_FONT_SIZE = 5.5

# Height of a bus rectangle relative to row_height.
# 0.56 means the rectangle occupies 56% of the row height.
DEFAULT_BUS_HEIGHT_FRACTION = 0.56

# Vertical offset for one-bit digital 0/1 levels relative to row_height.
# Larger values make digital high/low levels farther apart.
DEFAULT_DIGITAL_LEVEL_FRACTION = 0.23

# Background color of the whole figure and axes.
COLOR_BG = "#121417"

# Main foreground text color: signal names, bus values, axis labels and ticks.
COLOR_FG = "#E6E6E6"

# Grid and table line color. Used for vertical time grid and signal-name table borders.
COLOR_GRID = "#515761"

# Border color for multi-bit bus rectangles.
COLOR_BUS_EDGE = "#9FB3C8"

# Line color for one-bit digital waveforms.
COLOR_DIGITAL = "#7CC6FE"

# Text color for unknown one-bit values: x/z.
COLOR_UNKNOWN = "#FFB86C"

# Fill color for multi-bit bus rectangles.
COLOR_BUS_FILL = "#1A1F26"


@dataclass
class SignalDef:
    code: str
    name: str
    width: int


@dataclass
class Segment:
    t0: int
    t1: int
    value: str


def strip_bus_suffix(name: str) -> str:
    return re.sub(r"\[[^\]]+\]$", "", name)


def parse_gtkw_signals(path: Path) -> List[str]:
    signals: List[str] = []

    for raw_line in path.read_text(errors="replace").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("[") or line.startswith("@") or line.startswith("*"):
            continue
        if line.startswith("{") or line.startswith("+") or line.startswith("-"):
            continue

        if "." in line and not line.startswith("#"):
            signals.append(line)

    seen = set()
    unique: List[str] = []
    for sig in signals:
        if sig not in seen:
            seen.add(sig)
            unique.append(sig)

    return unique


def parse_vcd_header(path: Path) -> Tuple[Dict[str, SignalDef], Dict[str, str]]:
    code_to_def: Dict[str, SignalDef] = {}
    name_to_code: Dict[str, str] = {}
    scope: List[str] = []

    with path.open("r", errors="replace") as f:
        for line in f:
            parts = line.strip().split()
            if not parts:
                continue

            if parts[0] == "$scope" and len(parts) >= 3:
                scope.append(parts[2])

            elif parts[0] == "$upscope":
                if scope:
                    scope.pop()

            elif parts[0] == "$var" and len(parts) >= 5:
                width = int(parts[2])
                code = parts[3]
                local_name = parts[4]

                if len(parts) >= 6 and parts[5].startswith("["):
                    local_name += parts[5]

                full_name = ".".join(scope + [local_name])
                normalized_name = strip_bus_suffix(full_name)

                sig = SignalDef(code=code, name=full_name, width=width)
                code_to_def[code] = sig

                name_to_code[full_name] = code
                name_to_code[normalized_name] = code

            elif parts[0] == "$enddefinitions":
                break

    return code_to_def, name_to_code


def find_code(signal: str, name_to_code: Dict[str, str]) -> Optional[str]:
    if signal in name_to_code:
        return name_to_code[signal]

    no_bus = strip_bus_suffix(signal)
    if no_bus in name_to_code:
        return name_to_code[no_bus]

    wanted_tail = no_bus.split(".")[-1]
    wanted_scope = ".".join(no_bus.split(".")[:-1])
    for name, code in name_to_code.items():
        if strip_bus_suffix(name) == no_bus:
            return code
        if name.endswith(wanted_tail) and wanted_scope in name:
            return code

    return None


def parse_vcd_changes(path: Path, selected_codes: set[str]) -> Tuple[Dict[str, List[Tuple[int, str]]], int]:
    changes: Dict[str, List[Tuple[int, str]]] = {code: [] for code in selected_codes}
    current_time = 0
    max_time = 0

    with path.open("r", errors="replace") as f:
        in_header = True

        for raw in f:
            line = raw.strip()
            if not line:
                continue

            if in_header:
                if line.startswith("$enddefinitions"):
                    in_header = False
                continue

            if line.startswith("#"):
                try:
                    current_time = int(line[1:])
                    max_time = max(max_time, current_time)
                except ValueError:
                    pass
                continue

            if line.startswith("$"):
                continue

            first = line[0]
            if first in "01xXzZ":
                code = line[1:]
                if code in selected_codes:
                    changes[code].append((current_time, first.lower()))
                continue

            if first in "bBrR":
                parts = line.split()
                if len(parts) >= 2:
                    value = parts[0][1:].lower()
                    code = parts[1]
                    if code in selected_codes:
                        changes[code].append((current_time, value))
                continue

    return changes, max_time


def to_segments(changes: List[Tuple[int, str]], max_time: int) -> List[Segment]:
    if not changes:
        return [Segment(0, max_time, "x")]

    compact: List[Tuple[int, str]] = []
    for t, v in changes:
        if compact and compact[-1][0] == t:
            compact[-1] = (t, v)
        else:
            compact.append((t, v))

    if compact[0][0] != 0:
        compact.insert(0, (0, "x"))

    segments: List[Segment] = []
    for i, (t, v) in enumerate(compact):
        t1 = compact[i + 1][0] if i + 1 < len(compact) else max_time
        if t1 > t:
            segments.append(Segment(t, t1, v))

    return segments


def format_value(value: str, width: int, radix: str) -> str:
    if value in {"x", "z"}:
        return value
    if any(ch in value for ch in "xz"):
        return value

    if width <= 1 and len(value) == 1:
        return value

    if radix == "bin":
        return value

    try:
        intval = int(value, 2)
    except ValueError:
        return value

    if radix == "dec":
        return str(intval)

    return format(intval, "X")


def estimate_text_width_px(text: str, fontsize: float, dpi: int) -> float:
    return max(1.0, len(text)) * fontsize * (dpi / 72.0) * DEFAULT_CHAR_WIDTH_FACTOR


def measure_text_width_px(
    text: str,
    fontsize: float,
    dpi: int,
    fig=None,
    renderer=None,
) -> float:
    # fig and renderer are kept in the signature so call sites stay simple.
    # They are intentionally ignored: exact renderer measurement requires
    # fig.canvas.draw(), which can allocate a huge image buffer for wide figures.
    return estimate_text_width_px(text, fontsize, dpi)


def fit_text_for_segment(
    text: str,
    seg_width_px: float,
    base_fontsize: float,
    dpi: int,
    fig=None,
    renderer=None,
) -> Tuple[str, Optional[float]]:
    if seg_width_px <= 0:
        return "", None

    usable_px = seg_width_px - DEFAULT_LABEL_PADDING_PX
    if usable_px <= 0:
        return "", None

    if measure_text_width_px(text, base_fontsize, dpi, fig, renderer) <= usable_px:
        return text, base_fontsize

    ellipsis = "..."
    if measure_text_width_px(ellipsis, base_fontsize, dpi, fig, renderer) <= usable_px:
        return ellipsis, base_fontsize

    if measure_text_width_px(ellipsis, DEFAULT_MIN_FONT_SIZE, dpi, fig, renderer) <= usable_px:
        return ellipsis, DEFAULT_MIN_FONT_SIZE

    return "", None


def compute_required_figure_width(
    resolved: List[Tuple[str, str, SignalDef]],
    changes: Dict[str, List[Tuple[int, str]]],
    max_time: int,
    requested_width_in: float,
    dpi: int,
    max_labels_per_signal: int,
    radix: str,
) -> float:
    plot_width_px_requested = max(
        1.0,
        requested_width_in * dpi - (DEFAULT_LEFT_MARGIN_IN + DEFAULT_RIGHT_MARGIN_IN) * dpi,
    )

    required_px_per_time = 0.0

    for _, code, sig_def in resolved:
        if sig_def.width <= 1:
            continue

        segments = to_segments(changes.get(code, []), max_time)
        if len(segments) > max_labels_per_signal:
            continue

        for seg in segments:
            duration = max(1, seg.t1 - seg.t0)
            value = format_value(seg.value, sig_def.width, radix)

            required_seg_px = max(
                float(DEFAULT_MIN_CELL_WIDTH_PX),
                estimate_text_width_px(value, DEFAULT_BASE_FONT_SIZE, dpi) + DEFAULT_LABEL_PADDING_PX,
            )
            required_px_per_time = max(required_px_per_time, required_seg_px / duration)

    if required_px_per_time <= 0 or max_time <= 0:
        return requested_width_in

    required_plot_width_px = required_px_per_time * max_time
    actual_plot_width_px = max(plot_width_px_requested, required_plot_width_px)
    actual_total_width_in = (actual_plot_width_px / dpi) + DEFAULT_LEFT_MARGIN_IN + DEFAULT_RIGHT_MARGIN_IN

    return min(max(requested_width_in, actual_total_width_in), DEFAULT_MAX_AUTO_EXPAND_WIDTH_IN)


def draw_waveform(
    vcd_path: Path,
    gtkw_path: Path,
    output_path: Path,
    width: float,
    row_height: float,
    dpi: int,
    max_labels_per_signal: int,
    radix: str,
) -> None:
    requested = parse_gtkw_signals(gtkw_path)
    code_to_def, name_to_code = parse_vcd_header(vcd_path)

    resolved: List[Tuple[str, str, SignalDef]] = []
    missing: List[str] = []

    for sig in requested:
        code = find_code(sig, name_to_code)
        if code is None:
            missing.append(sig)
            continue
        resolved.append((sig, code, code_to_def[code]))

    if not resolved:
        raise SystemExit("No GTKWave signals were found in the VCD.")

    selected_codes = {code for _, code, _ in resolved}
    changes, max_time = parse_vcd_changes(vcd_path, selected_codes)

    if DEFAULT_AUTO_EXPAND_WIDTH_TO_FIT_VALUES:
        width = compute_required_figure_width(
            resolved=resolved,
            changes=changes,
            max_time=max_time,
            requested_width_in=width,
            dpi=dpi,
            max_labels_per_signal=max_labels_per_signal,
            radix=radix,
        )

    height = DEFAULT_TOP_MARGIN_IN + DEFAULT_BOTTOM_MARGIN_IN + max(1, len(resolved)) * row_height

    plt.rcParams.update({
        "figure.facecolor": COLOR_BG,
        "axes.facecolor": COLOR_BG,
        "axes.edgecolor": COLOR_FG,
        "axes.labelcolor": COLOR_FG,
        "xtick.color": COLOR_FG,
        "ytick.color": COLOR_FG,
        "text.color": COLOR_FG,
        "savefig.facecolor": COLOR_BG,
        "savefig.edgecolor": COLOR_BG,
    })

    fig, ax = plt.subplots(figsize=(width, height), dpi=dpi)
    x_max = max_time if max_time > 0 else 1
    ax.set_xlim(0, x_max)
    ax.set_ylim(-0.5, len(resolved) - 0.5)
    ax.set_xlabel("time")
    ax.xaxis.set_label_position("top")
    ax.xaxis.tick_top()
    ax.tick_params(
        axis="x",
        top=True,
        labeltop=True,
        bottom=False,
        labelbottom=False,
    )
    ax.set_yticks([])
    ax.grid(True, axis="x", linewidth=0.4, alpha=0.5, color=COLOR_GRID)

    fig.subplots_adjust(
        left=DEFAULT_LEFT_MARGIN_IN / width,
        right=1 - DEFAULT_RIGHT_MARGIN_IN / width,
        top=1 - DEFAULT_TOP_MARGIN_IN / height,
        bottom=DEFAULT_BOTTOM_MARGIN_IN / height,
    )

    plot_width_px = max(
        1.0,
        (width - DEFAULT_LEFT_MARGIN_IN - DEFAULT_RIGHT_MARGIN_IN) * dpi,
    )
    px_per_time = plot_width_px / max(1, x_max)
    renderer = None

    axes_pos = ax.get_position()
    label_area_left_x = -axes_pos.x0 / axes_pos.width
    label_text_x = DEFAULT_SIGNAL_NAME_RIGHT_PADDING_AXES
    label_box_right_x = 0.0

    for idx, (requested_name, code, sig_def) in enumerate(resolved):
        y = len(resolved) - 1 - idx
        segments = to_segments(changes.get(code, []), max_time)
        width_bits = sig_def.width

        label_rect = Rectangle(
            (label_area_left_x, y - 0.5),
            label_box_right_x - label_area_left_x,
            1.0,
            transform=ax.get_yaxis_transform(),
            fill=False,
            edgecolor=COLOR_GRID,
            linewidth=0.9,
            clip_on=False,
        )
        ax.add_patch(label_rect)

        ax.text(
            label_text_x,
            y,
            requested_name,
            transform=ax.get_yaxis_transform(),
            ha="right",
            va="center",
            fontsize=DEFAULT_SIGNAL_NAME_FONT_SIZE,
            clip_on=False,
            color=COLOR_FG,
        )

        if width_bits <= 1:
            xs: List[int] = []
            ys: List[float] = []

            for seg in segments:
                v = seg.value
                if v == "1":
                    level = y + row_height * DEFAULT_DIGITAL_LEVEL_FRACTION
                elif v == "0":
                    level = y - row_height * DEFAULT_DIGITAL_LEVEL_FRACTION
                else:
                    level = y

                if xs and xs[-1] != seg.t0:
                    xs.append(seg.t0)
                    ys.append(ys[-1])

                xs.extend([seg.t0, seg.t1])
                ys.extend([level, level])

                if v not in {"0", "1"}:
                    ax.text(
                        (seg.t0 + seg.t1) / 2,
                        y,
                        v,
                        ha="center",
                        va="center",
                        fontsize=DEFAULT_UNKNOWN_FONT_SIZE,
                        clip_on=True,
                        color=COLOR_UNKNOWN,
                    )

            ax.plot(xs, ys, linewidth=0.9, color=COLOR_DIGITAL)
        else:
            for seg in segments:
                rect = Rectangle(
                    (seg.t0, y - row_height * (DEFAULT_BUS_HEIGHT_FRACTION / 2.0)),
                    max(0, seg.t1 - seg.t0),
                    row_height * DEFAULT_BUS_HEIGHT_FRACTION,
                    fill=True,
                    facecolor=COLOR_BUS_FILL,
                    edgecolor=COLOR_BUS_EDGE,
                    linewidth=0.55,
                )
                ax.add_patch(rect)

            if len(segments) <= max_labels_per_signal:
                for seg in segments:
                    if seg.t1 <= seg.t0:
                        continue
                    value = format_value(seg.value, width_bits, radix)
                    seg_width_px = (seg.t1 - seg.t0) * px_per_time
                    show_text, fontsize = fit_text_for_segment(
                        value,
                        seg_width_px,
                        base_fontsize=DEFAULT_BASE_FONT_SIZE,
                        dpi=dpi,
                        fig=fig,
                        renderer=renderer,
                    )
                    if not show_text or fontsize is None:
                        continue
                    text_x = seg.t0 + min(
                        (seg.t1 - seg.t0) * 0.08,
                        DEFAULT_LABEL_PADDING_PX / max(px_per_time, 1e-9),
                    )
                    ax.text(
                        text_x,
                        y,
                        show_text,
                        ha="left",
                        va="center",
                        fontsize=fontsize,
                        clip_on=True,
                        color=COLOR_FG,
                    )
            else:
                label = f"{len(segments)} changes"
                ax.text(
                    0,
                    y,
                    label,
                    ha="left",
                    va="center",
                    fontsize=DEFAULT_TOO_MANY_CHANGES_FONT_SIZE,
                    clip_on=True,
                    color=COLOR_FG,
                )

        ax.plot(
            [label_box_right_x, 1.0],
            [y - 0.5, y - 0.5],
            transform=ax.get_yaxis_transform(),
            linewidth=0.9,
            alpha=1.0,
            color=COLOR_GRID,
            clip_on=False,
            solid_capstyle="butt",
        )

    suffix = output_path.suffix.lower()
    if suffix in {".svg", ".pdf"}:
        fig.savefig(output_path)
    else:
        fig.savefig(output_path, dpi=dpi)

    if missing:
        miss_path = output_path.with_suffix(output_path.suffix + ".missing.txt")
        miss_path.write_text("\n".join(missing) + "\n")


def positive_float(value: str) -> float:
    x = float(value)
    if x <= 0:
        raise argparse.ArgumentTypeError("value must be > 0")
    return x


def positive_int(value: str) -> int:
    x = int(value)
    if x <= 0:
        raise argparse.ArgumentTypeError("value must be > 0")
    return x


def build_simple_mode_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Render VCD waveforms in simple mode.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("format", nargs="?", choices=["svg", "png", "pdf"], default=DEFAULT_FORMAT)
    p.add_argument("radix_pos", nargs="?", choices=["hex", "dec", "bin"], help="Optional radix.")
    p.add_argument("--vcd-dir", default=DEFAULT_VCD_DIR)
    p.add_argument("--vcd-name", default=DEFAULT_VCD_NAME)
    p.add_argument("--gtkw-dir", default=DEFAULT_GTKW_DIR)
    p.add_argument("--gtkw-name", default=DEFAULT_GTKW_NAME)
    p.add_argument("--out-dir", default=DEFAULT_OUT_DIR)
    p.add_argument("--out-name", default=DEFAULT_OUT_NAME)
    p.add_argument("--width", type=positive_float, default=DEFAULT_WIDTH_SIMPLE)
    p.add_argument("--row-height", type=positive_float, default=DEFAULT_ROW_HEIGHT_SIMPLE)
    p.add_argument("--dpi", type=positive_int, default=DEFAULT_DPI_SIMPLE)
    p.add_argument("--radix", choices=["hex", "dec", "bin"], default=DEFAULT_RADIX)
    p.add_argument("--max-labels", type=positive_int, default=DEFAULT_MAX_LABELS_SIMPLE)
    return p


def build_explicit_mode_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Render VCD waveforms in explicit mode.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("vcd", nargs="?", default=str(Path(DEFAULT_VCD_DIR) / DEFAULT_VCD_NAME))
    p.add_argument("gtkw", nargs="?", default=str(Path(DEFAULT_GTKW_DIR) / DEFAULT_GTKW_NAME))
    p.add_argument("-o", "--output", type=Path, default=Path(DEFAULT_OUT_DIR) / f"{DEFAULT_OUT_NAME}.{DEFAULT_FORMAT}")
    p.add_argument("--width", type=positive_float, default=DEFAULT_WIDTH_EXPLICIT)
    p.add_argument("--row-height", type=positive_float, default=DEFAULT_ROW_HEIGHT_EXPLICIT)
    p.add_argument("--dpi", type=positive_int, default=DEFAULT_DPI_EXPLICIT)
    p.add_argument("--max-labels-per-signal", type=positive_int, default=DEFAULT_MAX_LABELS_EXPLICIT)
    p.add_argument("--radix", choices=["hex", "dec", "bin"], default=DEFAULT_RADIX)
    return p


def print_global_help() -> None:
    print(
        f"""Usage:

Simple mode:
    ./render_vcd_waveform.py
    ./render_vcd_waveform.py svg
    ./render_vcd_waveform.py png
    ./render_vcd_waveform.py pdf
    ./render_vcd_waveform.py svg dec
    ./render_vcd_waveform.py png hex --vcd-dir {DEFAULT_VCD_DIR} --vcd-name {DEFAULT_VCD_NAME} --gtkw-dir {DEFAULT_GTKW_DIR} --gtkw-name {DEFAULT_GTKW_NAME}

Explicit mode:
    ./render_vcd_waveform.py dump.vcd test_signals.gtkw -o waves.svg
    ./render_vcd_waveform.py dump.vcd test_signals.gtkw -o waves.png --radix dec

Current defaults:
    VCD:      {Path(DEFAULT_VCD_DIR) / DEFAULT_VCD_NAME}
    GTKWave:  {Path(DEFAULT_GTKW_DIR) / DEFAULT_GTKW_NAME}
    Output:   {Path(DEFAULT_OUT_DIR) / DEFAULT_OUT_NAME}
    Format:   {DEFAULT_FORMAT}
    Radix:    {DEFAULT_RADIX}
"""
    )


def run_simple_mode(argv: List[str]) -> int:
    parser = build_simple_mode_parser()
    args = parser.parse_args(argv)

    radix = args.radix_pos if args.radix_pos is not None else args.radix

    vcd_path = Path(args.vcd_dir) / args.vcd_name
    gtkw_path = Path(args.gtkw_dir) / args.gtkw_name
    out_path = Path(args.out_dir) / f"{args.out_name}.{args.format}"

    if not vcd_path.is_file():
        print(f"VCD file not found: {vcd_path}", file=sys.stderr)
        return 1

    if not gtkw_path.is_file():
        print(f"GTKWave file not found: {gtkw_path}", file=sys.stderr)
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)

    print("Rendering:")
    print(f"  VCD:     {vcd_path}")
    print(f"  GTKWave: {gtkw_path}")
    print(f"  Output:  {out_path}")
    print(f"  Format:  {args.format}")
    print(f"  Radix:   {radix}")

    draw_waveform(
        vcd_path=vcd_path,
        gtkw_path=gtkw_path,
        output_path=out_path,
        width=args.width,
        row_height=args.row_height,
        dpi=args.dpi,
        max_labels_per_signal=args.max_labels,
        radix=radix,
    )

    print(f"Done: {out_path}")
    return 0


def run_explicit_mode(argv: List[str]) -> int:
    parser = build_explicit_mode_parser()
    args = parser.parse_args(argv)

    vcd_path = Path(args.vcd)
    gtkw_path = Path(args.gtkw)

    if not vcd_path.is_file():
        print(f"VCD file not found: {vcd_path}", file=sys.stderr)
        return 1

    if not gtkw_path.is_file():
        print(f"GTKWave file not found: {gtkw_path}", file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)

    draw_waveform(
        vcd_path=vcd_path,
        gtkw_path=gtkw_path,
        output_path=args.output,
        width=args.width,
        row_height=args.row_height,
        dpi=args.dpi,
        max_labels_per_signal=args.max_labels_per_signal,
        radix=args.radix,
    )

    print(f"Saved: {args.output}")
    return 0


def main() -> int:
    argv = sys.argv[1:]

    if not argv:
        return run_simple_mode([])

    if argv[0] in {"-h", "--help", "help"}:
        print_global_help()
        return 0

    if argv[0] in {"svg", "png", "pdf"}:
        return run_simple_mode(argv)

    return run_explicit_mode(argv)


if __name__ == "__main__":
    raise SystemExit(main())
