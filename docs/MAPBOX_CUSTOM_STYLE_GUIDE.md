# Custom Mapbox Style Guide for MicroFlow Pro

## Why a Custom Style?

The default Mapbox styles (Streets, Dark) look generic. Apps like Uber, Ola, and Zomato use **custom styles** that:
- Remove visual clutter (hide unnecessary labels, POIs)
- Use brand colors for roads and highlights
- Mute background colors so markers/trails pop
- Create a distinctive "this is OUR app" feel

## How to Create Your Custom Style (10 minutes)

### Step 1: Open Mapbox Studio
Go to https://studio.mapbox.com/ and sign in with your Mapbox account.

### Step 2: Create New Style
Click "New Style" → Choose "Navigation Night" as the base (this is what Uber uses).

### Step 3: Customize Colors

Apply these changes for a premium MicroFlow Pro look:

| Layer | Property | Value | Why |
|-------|----------|-------|-----|
| Background | Color | `#0A0A0F` | Deep obsidian base |
| Road - primary | Color | `#2D2B55` | Subtle indigo roads |
| Road - primary | Outline | `#1A1835` | Darker road edges |
| Road - secondary | Color | `#1E1C3A` | Muted secondary roads |
| Road - motorway | Color | `#4F46E5` (your primary) | Brand color highways |
| Water | Color | `#0C1929` | Deep navy water |
| Land | Color | `#0F0F18` | Near-black land |
| Building | Color | `#16152B` | Subtle building outlines |
| Building | Extrusion height | Enable 3D | 3D buildings |
| Labels - place | Color | `#6366F1` (your indigo) | Brand-colored city names |
| Labels - road | Color | `#4A4870` | Muted road labels |
| Labels - POI | Visibility | Hidden | Remove clutter |
| Labels - transit | Visibility | Hidden | Remove bus stops etc |

### Step 4: Publish & Get Style URL
Click "Publish" → Copy the Style URL. It looks like:
```
mapbox://styles/YOUR_USERNAME/STYLE_ID
```

### Step 5: Use in the App

**For the Staff Map (Mapbox native):**
In `staff_map_page.dart`, add your custom style to the styles list:
```dart
static const _styles = [
  'mapbox://styles/YOUR_USERNAME/STYLE_ID', // Custom MicroFlow
  MapboxStyles.STANDARD,
  MapboxStyles.DARK,
  MapboxStyles.SATELLITE_STREETS,
];
```

**For the Manager Map (flutter_map with Mapbox raster tiles):**
The raster tile URL format for custom styles:
```
https://api.mapbox.com/styles/v1/YOUR_USERNAME/STYLE_ID/tiles/{z}/{x}/{y}@2x?access_token=YOUR_TOKEN
```

## Quick Alternative: Use Navigation Night

If you don't want to create a custom style, `navigation-night-v1` is already 
the closest to Uber's look. The manager map now defaults to this.

For the staff map, you can use:
```dart
styleUri: 'mapbox://styles/mapbox/navigation-night-v1'
```

## Style Recommendations by Portal

| Portal | Recommended Style | Why |
|--------|-------------------|-----|
| Staff Agent | Standard (3D buildings) | Agent needs to see surroundings clearly |
| Branch Manager | Navigation Night | Dark, focused on markers, premium feel |
| Executive Admin | Navigation Night | Same as manager, consistent |

## Pro Tips

1. **Hide POI labels** — They add noise. Your markers ARE the POIs.
2. **Enable 3D buildings** — Adds depth even on the raster tile version.
3. **Use @2x tiles** — Always request retina tiles for crisp rendering.
4. **Mute land use colors** — Parks, industrial areas etc should be barely visible.
5. **Keep water visible** — It's a natural landmark that helps orientation.
