"""Build the clip-to-SkillCorner time mapping using reviewed video anchors."""
import csv
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MATCH_ID = '2017461'
RAW = ROOT / 'data' / 'raw' / MATCH_ID
OUT = ROOT / 'data' / 'processed' / 'mv_clip'
VIDEO = ROOT / 'MV_Clip.mp4'
FFMPEG = shutil.which('ffmpeg')
FFPROBE = shutil.which('ffprobe')


def seconds(timestamp):
    parts = timestamp.split(':')
    return sum(float(p) * 60 ** i for i, p in enumerate(reversed(parts)))


def write_csv(path, rows):
    if not rows:
        raise ValueError(f'No records for {path.name}')
    with path.open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def checksums(extra):
    result = subprocess.check_output(
        [FFMPEG, '-v', 'error', '-i', str(VIDEO), *extra,
         '-an', '-f', 'framemd5', '-'], text=True)
    return [line.split(',')[-1].strip() for line in result.splitlines()
            if line.strip() and not line.startswith('#')]


def main():
    if not FFMPEG or not FFPROBE:
        raise RuntimeError('Install ffmpeg and ffprobe first.')
    OUT.mkdir(parents=True, exist_ok=True)
    config = json.loads((OUT / 'time_alignment.json').read_text())
    metadata = json.loads((OUT / 'MV_Clip_metadata.json').read_text())
    fps = metadata['tracking_fps']
    offset = config['skillcorner_start_seconds_estimated']
    probe = json.loads(subprocess.check_output(
        [FFPROBE, '-v', 'error', '-select_streams', 'v:0',
         '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json',
         str(VIDEO)], text=True))
    source_pts = [float(r['best_effort_timestamp_time']) for r in probe['frames']]
    original = checksums([])
    resampled = checksums(['-vf', f'fps={fps}'])
    source_lookup = {}
    for i, checksum in enumerate(original):
        source_lookup.setdefault(checksum, []).append(i)
    # This clip has unique decoded frames. Fail rather than guess if changed.
    if any(len(source_lookup[x]) != 1 for x in resampled):
        raise RuntimeError('Repeated video frames require a PTS-based selection audit.')
    source_indices = [source_lookup[x][0] for x in resampled]
    if len(source_indices) != metadata['frame_count']:
        raise RuntimeError('Frame count differs from the McByte export.')

    period_frames = []
    with (RAW / f'{MATCH_ID}_tracking_extrapolated.jsonl').open() as f:
        for line in f:
            record = json.loads(line)
            if record['period'] == 1 and record['timestamp']:
                t = seconds(record['timestamp'])
                if offset - 1 <= t <= offset + source_pts[source_indices[-1]] + 1:
                    record['_seconds'] = t
                    period_frames.append(record)
    if not period_frames:
        raise RuntimeError('No SkillCorner frames near the proposed clip time.')

    mapping = []
    matched_records = {}
    for i, src_index in enumerate(source_indices):
        source_time = source_pts[src_index]
        estimated = offset + source_time
        sc = min(period_frames, key=lambda r: abs(r['_seconds'] - estimated))
        delta = sc['_seconds'] - estimated
        if abs(delta) > 0.051:
            raise RuntimeError('SkillCorner frame gap exceeds half a sample.')
        frame = i + 1
        matched_records[frame] = sc
        mapping.append({
            'frame': frame,
            'clip_time_seconds': round(i / fps, 6),
            'source_frame_zero_based': src_index,
            'source_time_seconds': source_time,
            'period': 1,
            'match_time_seconds_estimated': round(estimated, 6),
            'skillcorner_frame': sc['frame'],
            'skillcorner_timestamp': sc['timestamp'],
            'skillcorner_match_seconds': sc['_seconds'],
            'nearest_sample_delta_seconds': round(delta, 6),
            'alignment_status': config['status'],
        })
    write_csv(OUT / 'frame_time_mapping.csv', mapping)

    with (OUT / 'MV_Clip_tracks.csv').open() as f:
        tracks = list(csv.DictReader(f))
    lookup = {r['frame']: r for r in mapping}
    joined = []
    for track in tracks:
        frame = int(track['frame'])
        if frame not in lookup:
            raise RuntimeError(f'Track references unmapped frame {frame}')
        joined.append({**track, **lookup[frame]})
    write_csv(OUT / 'tracks_time_synced.csv', joined)

    match = json.loads((RAW / f'{MATCH_ID}_match.json').read_text())
    players = {p['id']: p for p in match['players']}
    player_rows, ball_rows = [], []
    for mapped in mapping:
        sc = matched_records[mapped['frame']]
        base = {k: mapped[k] for k in ['frame', 'period', 'source_time_seconds',
                'match_time_seconds_estimated', 'skillcorner_frame',
                'skillcorner_timestamp']}
        for player in sc['player_data']:
            identity = players.get(player['player_id'], {})
            player_rows.append({**base, 'player_id': player['player_id'],
                'player_name': identity.get('short_name'),
                'team_id': identity.get('team_id'), 'shirt_number': identity.get('number'),
                'pitch_x': player['x'], 'pitch_y': player['y'],
                'is_detected': player['is_detected']})
        ball_rows.append({**base, **sc['ball_data']})
    write_csv(OUT / 'skillcorner_clip_players.csv', player_rows)
    write_csv(OUT / 'skillcorner_clip_ball.csv', ball_rows)
    metadata['match_clock_offset_seconds'] = offset
    metadata['time_alignment'] = config
    (OUT / 'MV_Clip_metadata_synced.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Saved {len(mapping)} mapped frames, {len(joined)} boxes, '
          f'{len(player_rows)} SkillCorner player positions.')
    print(f'First/last SkillCorner timestamps: {mapping[0]["skillcorner_timestamp"]} '
          f'– {mapping[-1]["skillcorner_timestamp"]}')


if __name__ == '__main__':
    main()
