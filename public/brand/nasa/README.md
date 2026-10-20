# OSGARD WORLD — Earth imagery provenance

All runtime Earth textures in this directory are local, same-origin resources served from OSGARD WORLD. NASA is **not** a partner or sponsor of OSGARD. Do not use NASA logos or imply endorsement.

| File | Resolution | Bytes | Source and acquisition |
| --- | --- | ---: | --- |
| earth-day-4096.jpg | 4096 × 2048 | 943204 | NASA Blue Marble: Next Generation, July 2004; high-quality downsample from 5400×2700 original |
| earth-day-2048.jpg | 2048 × 1024 | 265361 | Same July 2004 NASA Blue Marble source |
| earth-night-2048.jpg | 2048 × 1024 | 133814 | NASA Black Marble 2016 grayscale night-lights composite; downsample from 3600×1800 |
| earth-clouds-2048.jpg | 2048 × 1024 | 829367 | NASA Blue Marble cloud composite (static dataset, **not live weather**) |

### NASA source references
- July Blue Marble map: https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/july/world.200407.3x5400x2700.jpg
- NASA Blue Marble Next Generation: https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/
- NASA Black Marble 2016: https://science.nasa.gov/earth/earth-observatory/earth-at-night/maps/
- NASA Blue Marble cloud source: https://eoimages.gsfc.nasa.gov/images/imagerecords/57000/57747/cloud_combined_2048.jpg
- NASA imagery guidelines: https://www.nasa.gov/nasa-brand-center/images-and-media/

### Source-derived copies
- Day albedo: `MaxwellLee/physics-lab/assets/textures/earth_{2048,4096}.jpg`. Its SOURCES.md describes NASA originals and bicubic downsampling.
- Night lights and cloud composite: `Depal-Jakub/orbital-bloom/public/assets/earth-{night,clouds}-2048.jpg`. Its ASSET_INVENTORY.md traces each copy to NASA.

### Rendering policy
- Globe uses real static satellite composites of Earth. Date of maps is **historical**; do not present the image as current satellite data or geolocation.
- CPU/GPU fallback uses a separate procedural vector visualization if image loading or WebGL fails.
- Night light colors are artistically graded for readability. Lighting and ray-marched cloud depth are **cinematic approximations**, not weather analysis, physical radiative-transfer simulation, or 4K offline film output.
- Quality modes: Eco (2K source maps with reduced DPR/FPS, lightweight clouds), Auto (2K satellite + lower-cost cloud depth), Ultra (4K satellite + enhanced cloud depth).
- A deployment-time audit verifies Git-object checksums, correct JPEG dimensions, source provenance and compressed-asset budget.

### Asset integrity (Git blob SHA-1)
- earth-day-4096.jpg: `72b93d9af3c889617c1022d9541a57ce7e826aa2`
- earth-day-2048.jpg: `7ba17362d3ba4d515705bcbf839a5b65052e5d34`
- earth-night-2048.jpg: `4dcedcc464b9046fc1c40d9ed648784d3bfc7890`
- earth-clouds-2048.jpg: `86d8b2d16dbafbcb1aa5cd996cbab2b0afc9606b`
