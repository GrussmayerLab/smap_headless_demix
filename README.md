# Running the multicolor processing pipeline

`pipeline/process_multiC_locs.m` takes SMAP localization fits for a ratiometric
two-color acquisition, registers the two channels, classifies each
localization's color, corrects drift, and saves the result. It supports two
acquisition modalities:

- **`onecam`** — the two spectral channels are split side-by-side on one
  sensor (a single merged loc file per position already contains both).
- **`twocam`** — the same optical split instead lands on two synchronized
  cameras (one merged loc file per position, per camera). Frame numbers must
  line up 1:1 between the two cameras.

## Repository layout: SMAP vs. our code

- **`SMAP/`** is a vendored, unmodified copy of the official
  [jries/SMAP](https://github.com/jries/SMAP) toolbox (Ries, J. *Nat Methods*
  2020) — its own git repository, own license (GPLv3), own README. No SMAP
  source file has been changed; don't edit any `.m` file in here, and don't
  rely on it for anything project-specific. If you need to update it, do so
  through its own git remote, not by hand.
- Everything else under `tools/` is code written for this project, on top of
  SMAP — it calls SMAP's classes (`interfaces.LocalizationData`,
  `Process.Register.RegisterLocs2`, `savesml`, ...) but is not part of SMAP
  itself:
  - `pipeline/` — the entry-point script (`process_multiC_locs.m`) and the
    registration/matching/color-classification/filtering functions it calls
  - `fitting/` — batch-fitting entry scripts and merge utilities
  - `analysis/`, `utils/` — smaller supporting/analysis functions
  - `legacy/` — superseded scripts kept for reference, not wired into
    anything current
  - `config/` — SMAP CSV-import column-mapping definitions
  - `tests/` — the test suite and synthetic data generators for the code
    above (see "Running the test suite" below)
  - `setup_paths.m` — adds `SMAP/` and the folders above to the MATLAB path;
    also ours, not part of SMAP

## Installing

1. **MATLAB toolboxes.** SMAP itself requires Optimization, Image Processing,
   Curve Fitting, and Statistics and Machine Learning (see
   [SMAP/README.md](SMAP/README.md)); our pipeline additionally uses
   Statistics and Machine Learning (GMM color classification) and Image
   Processing (affine registration fit) directly, so the same set covers both.
2. **Micro-Manager and Bio-Formats.** Install Micro-Manager 1.4.22
   ([micro-manager.org](https://micro-manager.org)) and Bio-Formats
   ([openmicroscopy.org/bio-formats/downloads](https://www.openmicroscopy.org/bio-formats/downloads))
   — required to read the raw TIFF stacks.
3. **One-time SMAP setup.** From MATLAB, run `SMAP/SMAP.m` once (change folder
   if prompted). In the menu, go to *SMAP → Preferences…*, open the
   *Directories* tab, point it at your Micro-Manager and
   `bioformats_package.jar` locations, and *Save and exit*. This is SMAP's own
   persistent configuration, independent of anything below — you only need to
   do it once per machine. Full details:
   [SMAP/README.md](SMAP/README.md), and for a walkthrough,
   [SMAP/Documentation/pdf/Getting_Started.pdf](SMAP/Documentation/pdf/Getting_Started.pdf)
   or [SMAP/Documentation/pdf/SMAP_UserGuide.pdf](SMAP/Documentation/pdf/SMAP_UserGuide.pdf).
4. **Point `setup_paths.m` at Bio-Formats.** Our scripts add Bio-Formats to
   the MATLAB path themselves (separate from SMAP's own preferences above).
   `setup_paths.m` checks `E:\Program Files\bfmatlab` and `E:\GitHub\bfmatlab`
   by default — if yours lives elsewhere, add it to the
   `bioformats_candidates` list in [setup_paths.m](setup_paths.m).
5. **Data layout.** Organize your data as one subfolder per imaging position
   under a root folder, each containing:
   - the raw `.tif`/`.tiff` stack(s)
   - a `merge/` subfolder with the merged SMAP fit output (`*_sml.mat`, or
     `*.csv` if using `p.csv_import = true`)

GPU fitting (optional, faster) needs Windows + an NVIDIA GPU with CUDA;
without it SMAP's fitters fall back to CPU automatically.

## Running it

1. Fit your raw camera images into localizations using the SMAP GUI (run
   `SMAP/SMAP.m`, load your data, and fit as usual), then run the merging
   script (`fitting/merge_SMAP_locs_mat.m`, or `merge_SMAP_locs_csv.m` if
   working from CSV) to combine the per-acquisition fit files into the single
   merged file per position (`merge/*_sml.mat` or `merge/*.csv`) that
   `process_multiC_locs.m` expects — see "Data layout" above.
2. Open `tools/pipeline/process_multiC_locs.m` in MATLAB.
3. Near the top, set the modality flag:
   ```matlab
   p.modality = 'onecam'; % or 'twocam'
   ```
4. Check the parameters just below it match your experiment — most commonly:
   - `p.pixelsize` — camera pixel size in nm
   - `p.photon_ratios` — the `[lower upper]` intensity-ratio bands used to
     assign each localization to a color channel
   - `p.n_colors` / `p.specificity` — number of color components and the GMM
     classification confidence threshold
5. Run the script (`process_multiC_locs` from the command line).
6. You'll be prompted for the root data folder (camera A). In `twocam` mode
   you'll then be prompted a second time for the matching root folder for
   camera B — pick the folder whose position subfolders share the same names
   as camera A's (e.g. both have a `Pos0/`, `Pos1/`, ...).
7. The script iterates over every position subfolder, registers the two
   channels, classifies colors, corrects drift, and writes the result into a
   `results/` subfolder next to the merged input file (rendered images,
   `p.mat` with the processing parameters, and the final localization table).

`setup_paths.m` (called automatically at the top of the script) adds SMAP and
all the `tools/` subfolders to the MATLAB path — you don't need to run it
separately or add anything to the path by hand.

### `twocam` mode specifics

Camera B's localizations are shifted into the same coordinate convention SMAP's
registration code already expects for a single-sensor dual-view split (camera
B placed immediately to the right of camera A, at exactly camera A's frame
width). Everything past that point — registration, cross-channel matching,
color classification, drift correction — runs identically to `onecam` mode;
no separate code path was needed for it.

## Running the test suite

```matlab
cd tools/tests
run_tests
```

This runs all `matlab.unittest` tests under `tools/tests/`, including an
end-to-end test that drives the real `register_2channel.m` (registration,
matching, color classification, drift correction, save) on synthetic data —
no SMAP GUI needs to be open. Expect it to take about a minute; most of that
is the end-to-end registration test.

Synthetic test fixtures (line-pattern and dual-view loc generators) live under
`tools/tests/fixtures/` and are documented at the top of each generator file.
