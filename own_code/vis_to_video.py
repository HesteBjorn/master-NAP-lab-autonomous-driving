#!/usr/bin/env python3
"""
Convert a folder of sequential debug frames into a video.

Example:
    python own_code/vis_to_video.py \
      --frames outputs/debug_visualizations/route_00 \
      --fps 12 \
      --output outputs/debug_visualizations/route_00.mp4
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description='Turn debug PNG frames into a video.')
  parser.add_argument('--frames',
                      required=True,
                      help='Directory containing frame PNGs named like 0000.png, 0001.png, ...')
  parser.add_argument('--output',
                      help='Target video file (default: <frames>.mp4 in the parent directory).')
  parser.add_argument('--fps', type=int, default=10, help='Playback framerate for the output video.')
  parser.add_argument('--pattern',
                      default='%04d.png',
                      help='ffmpeg filename pattern (default: %%04d.png).')
  parser.add_argument('--keep-frames',
                      action='store_true',
                      help='Do not delete the PNG frames after the video is created.')
  return parser.parse_args()


def ensure_ffmpeg_available() -> None:
  if shutil.which('ffmpeg') is None:
    print('Error: ffmpeg not found in PATH. Install ffmpeg to use this script.', file=sys.stderr)
    sys.exit(1)


def main() -> None:
  args = parse_args()
  ensure_ffmpeg_available()

  frame_dir = Path(args.frames).expanduser().resolve()
  if not frame_dir.is_dir():
    print(f'Error: frame directory "{frame_dir}" does not exist.', file=sys.stderr)
    sys.exit(1)

  png_files = sorted(frame_dir.glob('*.png'))
  if not png_files:
    print(f'Error: no PNG files found in "{frame_dir}".', file=sys.stderr)
    sys.exit(1)
  start_number = None
  try:
    start_number = int(png_files[0].stem)
  except ValueError:
    start_number = None

  if args.output:
    output_path = Path(args.output).expanduser().resolve()
  else:
    output_path = (frame_dir.parent / f'{frame_dir.name}.mp4').resolve()

  output_path.parent.mkdir(parents=True, exist_ok=True)

  ffmpeg_cmd = ['ffmpeg', '-y', '-framerate', str(args.fps)]
  if start_number is not None:
    ffmpeg_cmd += ['-start_number', str(start_number)]
  ffmpeg_cmd += [
      '-i',
      f'{frame_dir}/{args.pattern}',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      str(output_path),
  ]

  print('Running:', ' '.join(ffmpeg_cmd))
  subprocess.run(ffmpeg_cmd, check=True)

  if not args.keep_frames:
    print(f'Deleting PNG frames under "{frame_dir}".')
    for png in frame_dir.glob('*.png'):
      png.unlink()

  print(f'Video saved to {output_path}')


if __name__ == '__main__':
  main()
