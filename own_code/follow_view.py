#!/usr/bin/env python3

"""Visualize the ego vehicle with a chase camera and optional LiDAR top view.

This helper attaches sensors to the hero vehicle and displays them in a Pygame window.
It avoids modifying the CARLA spectator so it won't fight with other visualization
tools.

Example:
    python own_code/follow_view.py --lidar
"""

from __future__ import annotations

import argparse
import queue
import sys
import time
from typing import Optional, List

import json
import math
from pathlib import Path
import numpy as np

try:
  import carla
except ImportError as exc:  # pragma: no cover - runtime guard
  print('Error: CARLA Python API not found in PYTHONPATH. '
        'Source setup_env.sh before running this script.', file=sys.stderr)
  raise exc


def find_hero(world: carla.World, role_name: str) -> Optional[carla.Actor]:
  actors = world.get_actors().filter('vehicle.*')
  for actor in actors:
    if actor.attributes.get('role_name') == role_name:
      return actor
  return None


def attach_lidar(world: carla.World, hero: carla.Actor, height: float, rotation: float,
                 range_m: float, channels: int, points_per_second: int,
                 lower_fov: float, upper_fov: float, rotation_frequency: float) -> carla.Sensor:
  blueprint_library = world.get_blueprint_library()
  lidar_bp = blueprint_library.find('sensor.lidar.ray_cast')
  lidar_bp.set_attribute('range', str(range_m))
  lidar_bp.set_attribute('channels', str(channels))
  lidar_bp.set_attribute('points_per_second', str(points_per_second))
  lidar_bp.set_attribute('lower_fov', str(lower_fov))
  lidar_bp.set_attribute('upper_fov', str(upper_fov))
  lidar_bp.set_attribute('rotation_frequency', str(rotation_frequency))

  lidar_transform = carla.Transform(
      carla.Location(z=hero.bounding_box.extent.z + height),
      carla.Rotation(yaw=rotation))

  return world.spawn_actor(lidar_bp, lidar_transform, attach_to=hero)


def attach_chase_camera(world: carla.World, hero: carla.Actor, distance: float, height: float,
                        pitch: float, width: int, height_px: int,
                        fov: float) -> carla.Sensor:
  blueprint_library = world.get_blueprint_library()
  camera_bp = blueprint_library.find('sensor.camera.rgb')
  camera_bp.set_attribute('image_size_x', str(width))
  camera_bp.set_attribute('image_size_y', str(height_px))
  camera_bp.set_attribute('fov', str(fov))

  transform = carla.Transform(carla.Location(x=-distance, z=height), carla.Rotation(pitch=pitch))
  return world.spawn_actor(camera_bp, transform, attach_to=hero)


def lidar_listener(lidar_queue: queue.Queue):

  def _callback(data: carla.SensorData):
    lidar_queue.put(data)

  return _callback


def lidar_to_surface(data: carla.LidarMeasurement, window_size: int,
                     meters_per_pixel: float) -> 'pygame.Surface':
  import pygame

  points = np.frombuffer(data.raw_data, dtype=np.float32)
  points = np.reshape(points, (len(points) // 4, 4))
  xs = points[:, 0]
  ys = points[:, 1]

  half_size = window_size // 2
  scale = 1.0 / meters_per_pixel
  u = (half_size + xs * scale).astype(np.int32)
  v = (half_size - ys * scale).astype(np.int32)

  mask = (u >= 0) & (u < window_size) & (v >= 0) & (v < window_size)
  surface_array = np.zeros((window_size, window_size, 3), dtype=np.uint8)
  surface_array[v[mask], u[mask]] = (0, 255, 0)

  pygame_surface = pygame.surfarray.make_surface(surface_array.swapaxes(0, 1))
  return pygame_surface


def run_visualizer(args: argparse.Namespace) -> None:
  client = carla.Client(args.host, args.port)
  client.set_timeout(5.0)
  world = client.get_world()

  hero: Optional[carla.Actor] = None
  for _ in range(120):
    hero = find_hero(world, args.role_name)
    if hero:
      break
    time.sleep(0.5)

  if hero is None:
    print(f"Could not find actor with role_name '{args.role_name}'. "
          "Start your simulation first.", file=sys.stderr)
    return

  lidar_sensor: Optional[carla.Sensor] = None
  camera_sensor: Optional[carla.Sensor] = None
  lidar_queue: queue.Queue = queue.Queue()
  camera_queue: queue.Queue = queue.Queue()

  prediction_file = Path(args.prediction_file).resolve()
  prediction_timestamp: Optional[float] = None
  prediction_points: List[carla.Location] = []

  try:
    if args.lidar:
      lidar_sensor = attach_lidar(world, hero, args.lidar_height, args.lidar_yaw, args.lidar_range,
                                  args.lidar_channels, args.lidar_points_per_second,
                                  args.lidar_lower_fov, args.lidar_upper_fov,
                                  args.lidar_rotation_frequency)
      lidar_sensor.listen(lidar_listener(lidar_queue))

    if args.camera:
      camera_sensor = attach_chase_camera(world, hero, args.camera_distance, args.camera_height,
                                          args.camera_pitch, args.camera_width, args.camera_height_px,
                                          args.camera_fov)
      camera_sensor.listen(camera_listener(camera_queue))

    if not args.camera and not args.lidar:
      print('Nothing to visualize: enable --camera and/or --lidar.')
      return

    import pygame
    pygame.init()

    window_width = 0
    window_height = 0
    if args.camera:
      window_width += args.camera_width
      window_height = max(window_height, args.camera_height_px)
    if args.lidar:
      window_width += args.lidar_window
      window_height = max(window_height, args.lidar_window)
    window = pygame.display.set_mode((window_width, window_height), pygame.HWSURFACE | pygame.DOUBLEBUF)
    pygame.display.set_caption('TransFuser++ Viewer')
    clock = pygame.time.Clock()

    print('Viewer running. Close the window or press Ctrl+C to exit.')

    while True:
      import pygame
      for event in pygame.event.get():
        if event.type == pygame.QUIT:
          raise KeyboardInterrupt

      offset_x = 0
      if args.camera:
        try:
          camera_data = camera_queue.get_nowait()
          camera_surface = camera_to_surface(camera_data)
          updated_points, prediction_timestamp = load_prediction_points(prediction_file, prediction_timestamp)
          if updated_points is not None:
            prediction_points = updated_points
          if prediction_points:
            overlay_predictions(camera_surface, prediction_points, camera_sensor, args.camera_width,
                                args.camera_height_px, args.camera_fov)
          window.blit(camera_surface, (offset_x, 0))
        except queue.Empty:
          pass
        offset_x += args.camera_width

      if args.lidar:
        try:
          lidar_data = lidar_queue.get_nowait()
          lidar_surface = lidar_to_surface(lidar_data, args.lidar_window, args.lidar_meters_per_pixel)
          window.blit(lidar_surface, (offset_x, 0))
        except queue.Empty:
          pass

      pygame.display.flip()
      clock.tick(args.display_fps)

  except KeyboardInterrupt:
    print('Stopping viewer...')
  finally:
    if lidar_sensor is not None:
      lidar_sensor.stop()
      lidar_sensor.destroy()
    if camera_sensor is not None:
      camera_sensor.stop()
      camera_sensor.destroy()
    import pygame
    pygame.quit()


def camera_listener(camera_queue: queue.Queue):

  def _callback(data: carla.Image):
    camera_queue.put(data)

  return _callback


def camera_to_surface(data: carla.Image) -> 'pygame.Surface':
  import numpy as np
  import pygame

  array = np.frombuffer(data.raw_data, dtype=np.uint8)
  array = np.reshape(array, (data.height, data.width, 4))
  array = array[:, :, :3][:, :, ::-1]
  surface = pygame.surfarray.make_surface(array.swapaxes(0, 1))
  return surface


def load_prediction_points(path: Path, last_timestamp: Optional[float]) -> tuple[Optional[List[carla.Location]], Optional[float]]:
  try:
    with path.open('r', encoding='utf-8') as prediction_file:
      data = json.load(prediction_file)
  except FileNotFoundError:
    return None, last_timestamp
  except json.JSONDecodeError:
    return None, last_timestamp

  timestamp = data.get('timestamp')
  if last_timestamp is not None and timestamp == last_timestamp:
    return None, last_timestamp

  points = []
  for point_data in data.get('points', []):
    try:
      points.append(carla.Location(x=float(point_data['x']), y=float(point_data['y']), z=float(point_data.get('z', 0.0))))
    except (KeyError, ValueError, TypeError):
      continue

  return points, timestamp


def get_world_to_camera_matrix(transform: carla.Transform) -> np.ndarray:
  matrix = np.array(transform.get_matrix())
  return np.linalg.inv(matrix)


def project_point(world_point: carla.Location, world_to_camera: np.ndarray, width: int, height: int,
                  fov: float) -> Optional[tuple[int, int]]:
  world_vec = np.array([world_point.x, world_point.y, world_point.z, 1.0])
  camera_vec = world_to_camera @ world_vec

  # Ignore points behind the camera
  if camera_vec[2] <= 0.0:
    return None

  focal = width / (2.0 * math.tan(math.radians(fov) / 2.0))
  x = (camera_vec[0] * focal / camera_vec[2]) + width / 2.0
  y = -(camera_vec[1] * focal / camera_vec[2]) + height / 2.0

  if not (0 <= x < width and 0 <= y < height):
    return None

  return int(x), int(y)


def overlay_predictions(surface: 'pygame.Surface',
                        points: List[carla.Location],
                        camera_sensor: carla.Sensor,
                        width: int,
                        height_px: int,
                        fov: float) -> None:
  import pygame

  if not points:
    return

  try:
    world_to_camera = get_world_to_camera_matrix(camera_sensor.get_transform())
  except np.linalg.LinAlgError:
    return

  pixel_points: List[Optional[tuple[int, int]]] = []
  for point in points:
    pixel_points.append(project_point(point, world_to_camera, width, height_px, fov))

  color_line = (0, 180, 255)
  color_point = (0, 255, 200)

  previous: Optional[tuple[int, int]] = None
  for pixel in pixel_points:
    if pixel is not None:
      pygame.draw.circle(surface, color_point, pixel, 6)
      if previous is not None:
        pygame.draw.line(surface, color_line, previous, pixel, 3)
      previous = pixel
    else:
      previous = None


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description='Follow the CARLA ego vehicle and show LiDAR.')
  parser.add_argument('--host', default='127.0.0.1', help='CARLA host (default: 127.0.0.1)')
  parser.add_argument('--port', type=int, default=2000, help='CARLA world port (default: 2000)')
  parser.add_argument('--role-name', default='hero', help='Target actor role name (default: hero)')
  parser.add_argument('--camera', action='store_true', help='Enable chase camera visualization.')
  parser.add_argument('--camera-width', type=int, default=1920, help='Chase camera width.')
  parser.add_argument('--camera-height-px', type=int, default=1080, help='Chase camera height.')
  parser.add_argument('--camera-distance', type=float, default=6.5, help='Camera distance behind the car.')
  parser.add_argument('--camera-height', type=float, default=2.5, help='Camera height relative to the car.')
  parser.add_argument('--camera-pitch', type=float, default=-10.0, help='Camera pitch angle.')
  parser.add_argument('--camera-fov', type=float, default=90.0, help='Camera field of view.')

  parser.add_argument('--lidar', action='store_true', help='Enable LiDAR visualization.')
  parser.add_argument('--lidar-window', type=int, default=1600, help='LiDAR window size in pixels.')
  parser.add_argument('--lidar-meters-per-pixel',
                      type=float,
                      default=0.25,
                      help='Scaling for LiDAR top view.')
  parser.add_argument('--lidar-range', type=float, default=60.0, help='LiDAR range in meters.')
  parser.add_argument('--lidar-height',
                      type=float,
                      default=1.8,
                      help='LiDAR height above vehicle roof in meters.')
  parser.add_argument('--lidar-yaw', type=float, default=0.0, help='LiDAR yaw rotation.')
  parser.add_argument('--lidar-channels', type=int, default=64, help='Number of LiDAR channels.')
  parser.add_argument('--lidar-points-per-second',
                      type=int,
                      default=600000,
                      help='LiDAR point generation rate.')
  parser.add_argument('--lidar-lower-fov', type=float, default=-30.0, help='LiDAR lower FOV.')
  parser.add_argument('--lidar-upper-fov', type=float, default=10.0, help='LiDAR upper FOV.')
  parser.add_argument('--lidar-rotation-frequency',
                      type=float,
                      default=20.0,
                      help='LiDAR rotations per second.')
  parser.add_argument('--display-fps', type=int, default=30, help='Display update rate.')
  parser.add_argument('--prediction-file',
                      default='own_code/runtime/predictions.json',
                      help='Path to live prediction file written by the agent.')
  return parser.parse_args()


def main() -> None:
  args = parse_args()
  run_visualizer(args)


if __name__ == '__main__':
  main()
