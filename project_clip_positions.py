"""Render a review overlay; requires numpy, Pillow, ffmpeg and ffprobe."""
import csv
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
DATA = ROOT / 'data' / 'processed' / 'mv_clip'
VIDEO = ROOT / 'MV_Clip.mp4'
RAW = ROOT / 'data' / 'raw' / '2017461'


def table(name):
    with (DATA / name).open() as f:
        return list(csv.DictReader(f))


def save_csv(name, rows):
    with (DATA / name).open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def project(h, xy):
    q = np.c_[np.asarray(xy, dtype=float), np.ones(len(xy))] @ h.T
    return q[:, :2] / q[:, 2:]


def normalize(xy):
    xy = np.asarray(xy, dtype=float)
    centre = xy.mean(axis=0)
    scale = np.sqrt(2) / np.linalg.norm(xy - centre, axis=1).mean()
    t = np.array([[scale, 0, -scale * centre[0]],
                  [0, scale, -scale * centre[1]], [0, 0, 1]])
    return project(t, xy), t


def homography(src, dst):
    a, ta = normalize(src)
    b, tb = normalize(dst)
    rows = []
    for (x, y), (u, v) in zip(a, b):
        rows.extend([[-x, -y, -1, 0, 0, 0, u*x, u*y, u],
                     [0, 0, 0, -x, -y, -1, v*x, v*y, v]])
    rows = np.asarray(rows)
    if np.linalg.matrix_rank(rows) < 8:
        raise ValueError('Degenerate calibration anchors.')
    _, _, vt = np.linalg.svd(rows)
    h = np.linalg.inv(tb) @ vt[-1].reshape(3, 3) @ ta
    h /= h[2, 2]
    if not np.isfinite(h).all() or abs(np.linalg.det(h)) < 1e-12:
        raise ValueError('Invalid homography.')
    return h


def proxy(record, width, height):
    c = record['image_corners_projection']
    xy = [(c['x_' + key], c['y_' + key]) for key in
          ['top_left', 'bottom_left', 'bottom_right', 'top_right']]
    return homography(xy, [(0, 0), (0, height), (width, height), (width, 0)])


def interpolated_correction(frame, fitted):
    keys = sorted(fitted)
    lower = max(k for k in keys if k <= frame)
    upper = min(k for k in keys if k >= frame)
    if lower == upper:
        return fitted[lower]
    weight = (frame - lower) / (upper - lower)
    return (1 - weight) * fitted[lower] + weight * fitted[upper]


def clipped_line(draw, p0, p1, width, height, colour):
    # Liang-Barsky clipping prevents outside-FOV lines crossing the whole image.
    x, y = p0
    dx, dy = p1 - p0
    lo, hi = 0., 1.
    for p, q in [(-dx, x), (dx, width - 1 - x), (-dy, y), (dy, height - 1 - y)]:
        if abs(p) < 1e-12:
            if q < 0:
                return
        else:
            t = q / p
            if p < 0:
                lo = max(lo, t)
            else:
                hi = min(hi, t)
            if lo > hi:
                return
    draw.line([(x + lo*dx, y + lo*dy), (x + hi*dx, y + hi*dy)],
              fill=colour, width=2)


def pitch_lines(draw, h, length, width, image_width, image_height):
    goal = length / 2
    paths = [
        [(goal, 20.16), (goal-16.5, 20.16), (goal-16.5, -20.16), (goal, -20.16)],
        [(goal, 9.16), (goal-5.5, 9.16), (goal-5.5, -9.16), (goal, -9.16)],
        [(0, -width/2), (0, width/2)],
    ]
    paths.append([(9.15*np.cos(t), 9.15*np.sin(t))
                  for t in np.linspace(0, 2*np.pi, 120)])
    for path in paths:
        for start, end in zip(path, path[1:]):
            samples = np.linspace(start, end, 100)
            q = np.c_[samples, np.ones(len(samples))] @ h.T
            for a, b in zip(q, q[1:]):
                if a[2] <= 0 or b[2] <= 0:
                    continue
                p0, p1 = a[:2]/a[2], b[:2]/b[2]
                if np.isfinite([p0, p1]).all():
                    clipped_line(draw, p0, p1, image_width, image_height, (120, 245, 80))


def main():
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('ffmpeg not found.')
    config = json.loads((DATA / 'spatial_calibration.json').read_text())
    alignment = json.loads((DATA / 'time_alignment.json').read_text())
    if alignment['skillcorner_start_seconds_estimated'] != config['time_alignment_seconds_used']:
        raise RuntimeError('Timing changed: review spatial anchors before re-rendering.')
    width, height = config['image_width'], config['image_height']
    timeline = {int(r['frame']): r for r in table('frame_time_mapping.csv')}
    wanted = {int(r['skillcorner_frame']) for r in timeline.values()}
    records = {}
    with (RAW / '2017461_tracking_extrapolated.jsonl').open() as f:
        for line in f:
            r = json.loads(line)
            if r['frame'] in wanted:
                records[r['frame']] = r
    match = json.loads((RAW / '2017461_match.json').read_text())
    players = {p['id']: p for p in match['players']}
    box_rows = table('MV_Clip_tracks.csv')
    boxes = {f: [] for f in timeline}
    for row in box_rows:
        boxes[int(row['frame'])].append(row)
    fitted, residuals = {}, []
    for key in config['keyframes']:
        frame = key['frame']
        r = records[int(timeline[frame]['skillcorner_frame'])]
        baseline = proxy(r, width, height)
        xy, observed = [], []
        for anchor in key['anchors']:
            p = next(p for p in r['player_data']
                     if players[p['player_id']]['team_id'] == anchor['team_id']
                     and players[p['player_id']]['number'] == anchor['shirt_number'])
            xy.append([p['x'], p['y']])
            observed.append([anchor['image_x'], anchor['image_y']])
        estimated = project(baseline, xy)
        correction = homography(estimated, observed)
        fitted[frame] = correction
        errors = np.linalg.norm(project(correction, estimated) - observed, axis=1)
        for anchor, error in zip(key['anchors'], errors):
            residuals.append({'frame': frame, **anchor, 'fit_residual_pixels': round(float(error), 3)})
    save_csv('calibration_fit_residuals.csv', residuals)
    font_path = '/System/Library/Fonts/Supplemental/Arial.ttf'
    font = ImageFont.truetype(font_path, 16) if Path(font_path).exists() else ImageFont.load_default()
    projected_rows, transforms = [], []
    previews = DATA / 'projection_previews'
    previews.mkdir(exist_ok=True)
    fps = json.loads((DATA / 'MV_Clip_metadata.json').read_text())['tracking_fps']
    with tempfile.TemporaryDirectory(prefix='mv_projection_') as tmp:
        tmp = Path(tmp)
        source = tmp / 'source'
        rendered = tmp / 'rendered'
        source.mkdir(); rendered.mkdir()
        subprocess.run([ffmpeg, '-v', 'error', '-y', '-i', str(VIDEO), '-vf', f'fps={fps}',
                        '-q:v', '2', '-start_number', '1', str(source / '%06d.jpg')], check=True)
        if len(list(source.glob('*.jpg'))) != len(timeline):
            raise RuntimeError('Unexpected source frame count.')
        for frame, mapped in timeline.items():
            r = records[int(mapped['skillcorner_frame'])]
            baseline = proxy(r, width, height)
            h = interpolated_correction(frame, fitted) @ baseline
            # Choose the positive homogeneous half-plane containing visible players.
            denoms = [float((h @ [p['x'], p['y'], 1])[2])
                      for p in r['player_data'] if p['is_detected']]
            if np.median(denoms) < 0:
                h = -h
            transforms.append({'frame': frame, 'skillcorner_frame': r['frame'],
                               'pitch_to_image_homography': h.tolist()})
            img = Image.open(source / f'{frame:06d}.jpg').convert('RGB')
            if img.size != (width, height):
                raise RuntimeError('Source image dimensions changed.')
            draw = ImageDraw.Draw(img)
            pitch_lines(draw, h, match['pitch_length'], match['pitch_width'], width, height)
            for box in boxes[frame]:
                x, y, bw, bh = [float(box[k]) for k in ['x', 'y', 'width', 'height']]
                u, v = x + bw/2, y + bh
                draw.line([(u-4, v-4), (u+4, v+4)], fill='white', width=2)
                draw.line([(u-4, v+4), (u+4, v-4)], fill='white', width=2)
            for p in r['player_data']:
                identity = players[p['player_id']]
                q = h @ [p['x'], p['y'], 1]
                u, v = q[:2]/q[2]
                visible = bool(p['is_detected'] and q[2] > 0 and 0 <= u < width and 90 <= v < height-45)
                projected_rows.append({
                    'frame': frame, 'source_time_seconds': mapped['source_time_seconds'],
                    'skillcorner_frame': r['frame'], 'player_id': p['player_id'],
                    'player_name': identity['short_name'], 'team_id': identity['team_id'],
                    'shirt_number': identity['number'], 'pitch_x': p['x'], 'pitch_y': p['y'],
                    'image_x': round(float(u), 3), 'image_y': round(float(v), 3),
                    'is_detected': p['is_detected'], 'drawn_in_preview': visible,
                    'projection_status': config['status']})
                if visible:
                    colour = (40, 235, 255) if identity['team_id'] == 868 else (255, 174, 50)
                    draw.ellipse((u-6, v-6, u+6, v+6), outline='black', width=4)
                    draw.ellipse((u-5, v-5, u+5, v+5), outline=colour, width=2)
                    draw.text((u+8, v-13), str(identity['number']), fill=colour,
                              font=font, stroke_width=1, stroke_fill='black')
            draw.rectangle((0, height-38, width, height), fill=(18, 23, 31))
            draw.text((10, height-29), f'ALIGNMENT PREVIEW | frame {frame:03d} | '
                      'cyan: Victory / orange: Auckland | white x: McByte feet', fill='white', font=font)
            img.save(rendered / f'{frame:06d}.jpg', quality=93)
            if frame in [1, 13, 26, 38, 51, 63, 76, 88, 101, 107, 113]:
                img.save(previews / f'frame_{frame:03d}.jpg', quality=95)
        output_video = DATA / 'MV_Clip_alignment_preview.mp4'
        subprocess.run([ffmpeg, '-v', 'error', '-y', '-framerate', str(fps),
                        '-start_number', '1', '-i', str(rendered / '%06d.jpg'), '-i', str(VIDEO),
                        '-map', '0:v:0', '-map', '1:a?', '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
                        '-c:a', 'aac', '-shortest', str(output_video)], check=True)
    save_csv('skillcorner_clip_projected.csv', projected_rows)
    (DATA / 'camera_homographies.json').write_text(json.dumps(transforms, indent=2) + '\n')
    validation = json.loads((DATA / 'spatial_validation_anchors.json').read_text())
    lookup = {(r['frame'], r['team_id'], r['shirt_number']): r for r in projected_rows}
    review_rows = []
    for anchor in validation['anchors']:
        p = lookup[anchor['frame'], anchor['team_id'], anchor['shirt_number']]
        error = np.hypot(p['image_x']-anchor['image_x'], p['image_y']-anchor['image_y'])
        review_rows.append({'frame': anchor['frame'], 'team_id': anchor['team_id'],
            'shirt_number': anchor['shirt_number'], 'observed_ground_x': anchor['image_x'],
            'observed_ground_y': anchor['image_y'], 'projected_x': p['image_x'],
            'projected_y': p['image_y'], 'review_error_pixels': round(float(error), 3),
            'review_type': 'player_ground_contact_not_used_in_fit'})
    save_csv('projection_validation.csv', review_rows)
    errors = [r['review_error_pixels'] for r in review_rows]
    summary = {'status': 'preliminary_review', 'n_manual_fit_anchors': len(residuals),
        'n_review_anchors': len(errors),
        'review_frames': sorted({r['frame'] for r in review_rows}),
        'median_review_error_pixels': round(float(np.median(errors)), 1),
        'p90_review_error_pixels': round(float(np.percentile(errors, 90)), 1),
        'max_review_error_pixels': round(max(errors), 1),
        'limitations': 'Approximate manual ground contacts and provisional identities. '
        'Review points excluded from fitting but selected by the same reviewer. '
        'McByte identity assignment has not been finalized.'}
    (DATA / 'projection_review.json').write_text(json.dumps(summary, indent=2) + '\n')
    fit_errors = [r['fit_residual_pixels'] for r in residuals]
    print(f'Saved {len(projected_rows)} projected player positions, {len(transforms)} camera transforms.')
    print(f'Manual seed fit residual median: {np.median(fit_errors):.1f} px; '
          f'max: {max(fit_errors):.1f} px. These are calibration fit errors, not validation errors.')
    print(output_video)


if __name__ == '__main__':
    main()
