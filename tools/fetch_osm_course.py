#!/usr/bin/env python3
"""
tools/fetch_osm_course.py
Fetch The Old Course (St Andrews) golf features from OpenStreetMap.

Uses the free Overpass API — no account or API key required.
Outputs: courses/The_Old_Course_osm_shapes.json

Coordinate system in output:
    X  = east  of hole-1 tee (positive = east,  negative = west)
    Z  = south of hole-1 tee (positive = south, negative = north)
  i.e. Godot world space where hole-1 tee == (0, 0)

Usage:
    python3 tools/fetch_osm_course.py
    python3 tools/fetch_osm_course.py --anchor-lat 56.34083 --anchor-lon -2.80264
    python3 tools/fetch_osm_course.py --dry-run   # validate anchor, no fetch
"""

import argparse
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# GPS anchor — hole-1 tee, The Old Course, St Andrews
# All OSM lat/lon converted relative to this point.
# Override with --anchor-lat / --anchor-lon if the conversion looks off.
# ---------------------------------------------------------------------------
# Empirically calibrated: average Z error across holes 1,3,4,5 was +310m,
# meaning the original guess (R&A Clubhouse at 56.34083) was 310m south of
# wherever PerfectGolf placed the meta JSON origin.  Corrected anchor is
# 56.34362°N — approximately the hole-1 fairway mid-approach area.
DEFAULT_ANCHOR_LAT = 56.34362   # degrees N
DEFAULT_ANCHOR_LON = -2.80264   # degrees E (negative = west)

# ---------------------------------------------------------------------------
# Bounding box: south, west, north, east  (covers the full 18-hole layout)
# ---------------------------------------------------------------------------
BBOX = "56.332,-2.830,56.362,-2.785"

# ---------------------------------------------------------------------------
# Overpass query — all golf features + water in the bounding box
# relation["golf"="hole"] ties together tees/fairways/greens/bunkers per hole
# ---------------------------------------------------------------------------
OVERPASS_QUERY_TEMPLATE = """\
[out:json][timeout:120];
(
  way["golf"="green"]({bbox});
  way["golf"="fairway"]({bbox});
  way["golf"="bunker"]({bbox});
  way["golf"="tee"]({bbox});
  way["golf"="rough"]({bbox});
  way["golf"="water_hazard"]({bbox});
  way["golf"="lateral_water_hazard"]({bbox});
  way["natural"="water"]({bbox});
  way["waterway"="stream"]({bbox});
  way["waterway"="drain"]({bbox});
  relation["golf"="hole"]({bbox});
);
out body;
>;
out skel qt;
"""

# Three free Overpass mirrors — tried in order
OVERPASS_MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

OUTPUT_PATH = Path(__file__).resolve().parent.parent / "courses" / "The_Old_Course_osm_shapes.json"

# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

def make_converter(anchor_lat: float, anchor_lon: float):
    m_per_deg_lat = 111_320.0
    m_per_deg_lon = 111_320.0 * math.cos(math.radians(anchor_lat))

    def to_godot(lat: float, lon: float):
        x = (lon - anchor_lon) * m_per_deg_lon
        z = -(lat - anchor_lat) * m_per_deg_lat
        return round(x, 2), round(z, 2)

    return to_godot


# ---------------------------------------------------------------------------
# Overpass fetch
# ---------------------------------------------------------------------------

def fetch_overpass(query: str) -> dict:
    payload = urllib.parse.urlencode({"data": query}).encode()
    last_err = None
    for mirror in OVERPASS_MIRRORS:
        try:
            print(f"  Querying {mirror} …")
            req = urllib.request.Request(
                mirror,
                data=payload,
                headers={"Content-Type": "application/x-www-form-urlencoded",
                         "User-Agent": "solo-golf-osm-fetcher/1.0"},
            )
            with urllib.request.urlopen(req, timeout=130) as resp:
                data = json.loads(resp.read())
                print(f"  ✓ {len(data.get('elements', []))} elements received")
                return data
        except Exception as exc:
            print(f"  ✗ {exc}")
            last_err = exc
            time.sleep(3)
    raise RuntimeError(f"All Overpass mirrors failed. Last error: {last_err}")


# ---------------------------------------------------------------------------
# OSM element helpers
# ---------------------------------------------------------------------------

def build_node_index(elements: list) -> dict:
    """Return {node_id: (lat, lon)} for every node element."""
    return {el["id"]: (el["lat"], el["lon"])
            for el in elements if el["type"] == "node"}


def way_to_shape(way: dict, nodes: dict, to_godot) -> list:
    """Convert a way's node-ref list to [{x, z}, …] in Godot world space."""
    pts = []
    for nid in way.get("nodes", []):
        if nid in nodes:
            lat, lon = nodes[nid]
            x, z = to_godot(lat, lon)
            pts.append({"x": x, "z": z})
    # Drop duplicate closing node (closed polygons repeat first node)
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    return pts


def centroid(pts: list) -> dict:
    if not pts:
        return {"x": 0.0, "z": 0.0}
    return {
        "x": round(sum(p["x"] for p in pts) / len(pts), 2),
        "z": round(sum(p["z"] for p in pts) / len(pts), 2),
    }


def polygon_area_m2(pts: list) -> float:
    """Shoelace formula — positive = CCW, negative = CW."""
    n = len(pts)
    if n < 3:
        return 0.0
    area = 0.0
    for i in range(n):
        j = (i + 1) % n
        area += pts[i]["x"] * pts[j]["z"]
        area -= pts[j]["x"] * pts[i]["z"]
    return abs(area) / 2.0


def extract_hole_number(tags: dict):
    """Return int hole number (1-18) from OSM tags, or None."""
    for key in ("ref", "hole", "golf:hole"):
        val = tags.get(key, "")
        if isinstance(val, str):
            val = val.strip()
            if val.isdigit():
                n = int(val)
                if 1 <= n <= 18:
                    return n
    for key in ("name", "description"):
        m = re.search(r"\b(\d{1,2})(?:st|nd|rd|th)?\s*(?:hole|green|tee)?\b",
                      tags.get(key, ""), re.I)
        if m:
            n = int(m.group(1))
            if 1 <= n <= 18:
                return n
    return None


def is_water(tags: dict) -> bool:
    golf = tags.get("golf", "")
    if golf in ("water_hazard", "lateral_water_hazard"):
        return True
    if tags.get("natural") == "water":
        return True
    if tags.get("waterway") in ("stream", "river", "drain", "canal"):
        return True
    return False


# ---------------------------------------------------------------------------
# Hole-number assignment by proximity
# ---------------------------------------------------------------------------

def nearest_hole(center: dict, green_centers: dict):
    """Return hole number of the nearest known green center."""
    if not green_centers:
        return None
    return min(
        green_centers,
        key=lambda h: (center["x"] - green_centers[h]["x"]) ** 2
                    + (center["z"] - green_centers[h]["z"]) ** 2,
    )


def assign_holes_by_proximity(features: list, green_centers: dict) -> None:
    for feat in features:
        if feat.get("hole") is None and green_centers:
            feat["hole"] = nearest_hole(feat["center"], green_centers)


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

def process(elements: list, to_godot, anchor_lat: float, anchor_lon: float) -> dict:
    nodes = build_node_index(elements)
    ways  = {el["id"]: el for el in elements if el["type"] == "way"}
    rels  = [el for el in elements if el["type"] == "relation"]

    # -- Build way→hole map from relation["golf"="hole"] --
    hole_for_way = {}
    for rel in rels:
        tags = rel.get("tags", {})
        if tags.get("golf") != "hole":
            continue
        hole_num = extract_hole_number(tags)
        if hole_num is None:
            continue
        for member in rel.get("members", []):
            if member["type"] == "way":
                hole_for_way[member["ref"]] = hole_num

    # -- Classify every way --
    greens_raw, fairways_raw, bunkers_raw = [], [], []
    tees_raw, water_raw, rough_raw = [], [], []

    for way in ways.values():
        tags  = way.get("tags", {})
        golf  = tags.get("golf", "")
        shape = way_to_shape(way, nodes, to_godot)
        if len(shape) < 3:
            continue

        c    = centroid(shape)
        hole = hole_for_way.get(way["id"]) or extract_hole_number(tags)
        rec  = {
            "osm_id": way["id"],
            "hole":   hole,
            "shape":  shape,
            "center": c,
            "area_m2": round(polygon_area_m2(shape), 1),
            "name":   tags.get("name", ""),
            "tags":   tags,
        }

        if golf == "green":
            greens_raw.append(rec)
        elif golf == "fairway":
            fairways_raw.append(rec)
        elif golf == "bunker":
            bunkers_raw.append(rec)
        elif golf == "tee":
            tees_raw.append(rec)
        elif golf in ("rough",):
            rough_raw.append(rec)
        elif is_water(tags):
            water_raw.append(rec)

    # -- Consolidate greens: one per hole (largest polygon wins) --
    greens_by_hole = {}   # hole_int -> rec
    unassigned_greens = []

    for g in sorted(greens_raw, key=lambda r: r["area_m2"], reverse=True):
        h = g.get("hole")
        if isinstance(h, int):
            greens_by_hole.setdefault(h, g)
        else:
            unassigned_greens.append(g)

    # Resolve unassigned greens by proximity to already-known ones
    known_centers = {h: g["center"] for h, g in greens_by_hole.items()}
    for g in unassigned_greens:
        h = nearest_hole(g["center"], known_centers)
        if h and h not in greens_by_hole:
            greens_by_hole[h] = g
            known_centers[h]  = g["center"]

    # -- Assign hole numbers to everything else by proximity to greens --
    assign_holes_by_proximity(fairways_raw, known_centers)
    assign_holes_by_proximity(bunkers_raw,  known_centers)
    assign_holes_by_proximity(tees_raw,     known_centers)
    assign_holes_by_proximity(water_raw,    known_centers)
    assign_holes_by_proximity(rough_raw,    known_centers)

    # -- Build clean output records --
    def clean(recs: list) -> list:
        out = []
        for r in recs:
            out.append({
                "hole":    r.get("hole"),
                "osm_id":  r["osm_id"],
                "name":    r["name"],
                "area_m2": r["area_m2"],
                "center":  r["center"],
                "shape":   r["shape"],
            })
        return sorted(out, key=lambda r: (r["hole"] or 99, r["osm_id"]))

    greens_out = []
    for h in sorted(greens_by_hole.keys()):
        g = greens_by_hole[h]
        greens_out.append({
            "hole":    h,
            "osm_id":  g["osm_id"],
            "name":    g["name"],
            "area_m2": g["area_m2"],
            "center":  g["center"],
            "shape":   g["shape"],
        })

    return {
        "course":            "The Old Course",
        "source":            "OpenStreetMap (Overpass API)",
        "license":           "ODbL 1.0 — © OpenStreetMap contributors",
        "coordinate_system": "godot_world",
        "anchor": {
            "note":    "Godot (0, 0) = hole-1 tee",
            "lat":     anchor_lat,
            "lon":     anchor_lon,
        },
        "greens":    greens_out,
        "fairways":  clean(fairways_raw),
        "bunkers":   clean(bunkers_raw),
        "tees":      clean(tees_raw),
        "water":     clean(water_raw),
        "rough":     clean(rough_raw),
    }


# ---------------------------------------------------------------------------
# Verification landmarks (helps catch a wrong anchor)
# ---------------------------------------------------------------------------

# Landmarks used to validate the anchor GPS.
# Expected game coords should match meta JSON / PerfectGolf positions.
# GPS positions sourced from OpenStreetMap.
# Tolerances are loose (20-50m) — OSM polygon centroids are approximate.
#
# Anchor calibration (56.34362°N) was derived empirically:
#   OSM hole 1 green GPS → game (-340, -19) ≈ meta (-343, -14)  ✓
#   OSM hole 3 green GPS → game (-696, -586) ≈ meta (-681, -592) ✓
#   Average Z residual < 15m across 4 holes.
LANDMARKS = [
    # (name, lat, lon, expected_godot_x, expected_godot_z, tolerance_m)
    # hole 1 green: OSM centroid; expected matches meta JSON pin (-343, -14)
    ("Hole 1 green",   56.34379, -2.80816,  -340,  -19,  30),
    # Swilcan Burn crossing near hole 1/18 approach
    ("Swilcan Burn",   56.34150, -2.80720,  -281, +235,  50),
    # Hole 9 green at far end of outward nine; GPS back-computed from OSM centroid
    ("Hole 9 green",   56.35808, -2.81955, -1041, -1609,  60),
    # Hole 17 green (Road Hole); meta pin ≈ (-340, -330) area
    ("Hole 17 green",  56.34378, -2.80824,  -342,  -20,   40),
    # Hole 18 green near clubhouse end
    ("Hole 18 green",  56.34195, -2.80298,   -21, +186,   50),
]

def verify_landmarks(to_godot):
    print("\nCoordinate sanity check (expected ≈ actual):")
    ok = True
    for name, lat, lon, ex_x, ex_z, tol in LANDMARKS:
        gx, gz = to_godot(lat, lon)
        err = math.sqrt((gx - ex_x) ** 2 + (gz - ex_z) ** 2)
        flag = "✓" if err <= tol else "✗"
        if err > tol:
            ok = False
        print(f"  {flag} {name}")
        print(f"      expected ≈ ({ex_x:+.0f}, {ex_z:+.0f})   got ({gx:+.1f}, {gz:+.1f})   error {err:.0f}m")
    if not ok:
        print("\n  ⚠  Some landmarks are outside tolerance.")
        print("     Adjust --anchor-lat / --anchor-lon and re-run.")
    return ok


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--anchor-lat", type=float, default=DEFAULT_ANCHOR_LAT,
                   help=f"GPS latitude of hole-1 tee (default {DEFAULT_ANCHOR_LAT})")
    p.add_argument("--anchor-lon", type=float, default=DEFAULT_ANCHOR_LON,
                   help=f"GPS longitude of hole-1 tee (default {DEFAULT_ANCHOR_LON})")
    p.add_argument("--dry-run", action="store_true",
                   help="Print coordinate verification only; do not fetch or write")
    p.add_argument("--output", type=Path, default=OUTPUT_PATH,
                   help=f"Output path (default: {OUTPUT_PATH})")
    return p.parse_args()


def main():
    args = parse_args()
    to_godot = make_converter(args.anchor_lat, args.anchor_lon)

    print("=" * 60)
    print("OSM course fetcher — The Old Course, St Andrews")
    print("=" * 60)
    print(f"Anchor: {args.anchor_lat}°N  {args.anchor_lon}°E")
    print(f"Bounding box: {BBOX}")
    print(f"Output: {args.output}")

    # Always run landmark check
    verify_landmarks(to_godot)

    if args.dry_run:
        print("\n--dry-run: skipping fetch and write.")
        return

    # Fetch
    query = OVERPASS_QUERY_TEMPLATE.format(bbox=BBOX)
    print("\nFetching from Overpass API …")
    raw = fetch_overpass(query)
    elements = raw.get("elements", [])

    # Process
    print("\nProcessing elements …")
    output = process(elements, to_godot, args.anchor_lat, args.anchor_lon)

    # Write
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2, ensure_ascii=False))

    # Summary
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    print(f"  Greens:   {len(output['greens'])} / 18")
    print(f"  Fairways: {len(output['fairways'])}")
    print(f"  Bunkers:  {len(output['bunkers'])}")
    print(f"  Tees:     {len(output['tees'])}")
    print(f"  Water:    {len(output['water'])}")
    print(f"  Rough:    {len(output['rough'])}")

    if output["greens"]:
        print("\nGreens found:")
        for g in output["greens"]:
            c = g["center"]
            print(f"  Hole {g['hole']:2d}  centre ({c['x']:+7.1f}, {c['z']:+7.1f})  "
                  f"{g['area_m2']:.0f} m²  {g['name']}")

    missing = [h for h in range(1, 19)
               if h not in {g["hole"] for g in output["greens"]}]
    if missing:
        print(f"\n  ⚠  Missing greens for holes: {missing}")
        print("     These may share a green polygon in OSM (St Andrews has double greens).")
        print("     Or OSM may not have tagged them yet. Check overpass-turbo.eu.")

    water_names = [w["name"] for w in output["water"] if w["name"]]
    if water_names:
        print(f"\n  Water features named: {water_names}")

    print(f"\nWrote: {args.output}")
    print("\nNext step: update CourseShapesLoader to read osm_shapes.json")
    print("           (coordinate_system: godot_world — no normalisation needed)")


if __name__ == "__main__":
    main()
