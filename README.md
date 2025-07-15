# Computer Vision Challenge

A MATLAB-based toolkit for detecting and visualizing changes in satellite imagery using category-based masks, image registration, and pixel-level change detection. This project provides both a GUI and a set of core functions for batch processing and interactive exploration.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Workflow Summary](#workflow-summary)
- [Detailed Methods](#detailed-methods)
  - [1. Image Loading](#1-image-loading)
  - [2. Image Registration](#2-image-registration)
  - [3. Mask Generation](#3-mask-generation)
  - [4. Change Detection](#4-change-detection)
  - [5. Statistics Calculation](#5-statistics-calculation)
  - [6. Visualization](#6-visualization)
- [Function API](#function-api)
- [GUI Features](#gui-features)
- [Example Usage](#example-usage)
- [Contributors](#contributors)

---

## Overview

This project enables the detection and visualization of changes in satellite images over time. It supports:
- Automatic image alignment (registration)
- Category-based masking (e.g., city, water, forest)
- Pixel-level change detection with configurable parameters
- Multiple visualization modes (timelapse, flicker, absolute difference overlays)
- A MATLAB GUI for interactive exploration

---

## Project Structure

```
Computer_vision_challenge/
├── src/                  # Core MATLAB source code
│   ├── preprocess_images.m
│   ├── +registration/    # Image registration functions
│   ├── +masks/           # Mask generation utilities
│   ├── +visualization/   # Visualization utilities
│   └── ...
├── resources/            # Project resources
├── README.md             # This file
└── SatelliteChangeAppTwo.m # Main GUI entry point
```

---

## Workflow Summary

1. **Image Loading:** User selects a set of satellite images and a reference image.
2. **Image Registration:** All images are aligned to the reference using feature-based registration.
3. **Mask Generation:** Category-specific masks are generated for each image (e.g., city, water).
4. **Change Detection:** Changes are detected within the masked regions using configurable algorithms.
5. **Statistics Calculation:** The number and proportion of changed pixels are computed.
6. **Visualization:** Results are visualized as overlays, timelapses, or flicker comparisons in the GUI.

---

## Detailed Methods

### 1. Image Loading

- Images are loaded from user-specified paths.
- The reference image is selected for alignment and change comparison.
- Supported formats: JPEG, PNG, TIFF.

### 2. Image Registration

- **Purpose:** Align all images to the reference to ensure pixel-wise comparability.
- **Method:** Feature-based registration using SURF (Speeded-Up Robust Features).
    - Keypoints are detected in both the reference and target images.
    - Feature descriptors are matched.
    - A geometric transformation (affine or projective) is estimated.
    - Each image is warped to align with the reference.
- **Fallback:** If registration fails, the original image is used.

### 3. Mask Generation

- **Purpose:** Focus change detection on specific land cover categories.
- **Method:** 
    - Predefined or dynamically generated masks for categories such as city, water, forest, ice, desert, farmland.
    - Masks are binary images where pixels of interest are set to 1.
    - Mask generation can use color thresholding, clustering, or manual annotation (depending on category and dataset).
- **Application:** Masks are applied to each registered image before change detection.

### 4. Change Detection

- **Purpose:** Identify significant changes between the reference and each aligned image.
- **Methods:**
    - **Absolute Difference:** Compute the absolute pixel-wise difference in the masked region.
    - **Thresholding:** Mark pixels as changed if the difference exceeds a user-defined threshold.
    - **Sensitivity:** Additional parameter to control detection strictness.
    - **Change Detection Methods:** Can be selected (e.g., histogram-based, direct difference).
- **Output:** Binary change maps indicating changed pixels.

### 5. Statistics Calculation

- **Purpose:** Quantify the extent of change.
- **Metrics:**
    - **Absolute Change:** Total number of changed pixels in the mask.
    - **Relative Change:** Proportion of changed pixels relative to the mask area.
    - **Per-category statistics:** Calculated for each selected category.

### 6. Visualization

- **Timelapse:** Sequence of processed images shown as an animation.
- **Absolute Difference Overlay:** Changed areas highlighted in red or another color.
- **Flicker:** Rapid toggling between two images for visual comparison.
- **Interactive GUI:** Users can select images, categories, and parameters, and view results in real time.

---

## Function API

### Main Function: `processChangeDetection`

```matlab
[processed_images, gui_params] = processChangeDetection(...
    image_paths, ...
    main_picture_path, ...
    is_new_file_list, ...
    category, ...
    inputParams)
```

**Inputs:**
- `image_paths`: Cell array of absolute image paths.
- `main_picture_path`: Path to the reference image.
- `is_new_file_list`: Boolean flag; if true, images are realigned.
- `category`: String; one of the allowed change categories.
- `inputParams`: Struct with algorithm parameters (e.g., threshold, sensitivity).

**Outputs:**
- `processed_images`: Cell array of RGB images ready for display.
- `gui_params`: Struct with relevant parameters and statistics for the GUI.

**Typical `inputParams` fields:**
- `threshold`: Numeric, change detection threshold.
- `sensitivity`: Numeric, controls detection strictness.
- `rotation_tolerance`: Numeric, registration parameter.
- `change_detection_method`: String, e.g., 'histogram' or 'difference'.

---

## GUI Features

- **Folder and Image Selection:** Choose datasets and reference images.
- **Category Selection:** Select which land cover type to analyze.
- **Parameter Adjustment:** Tune threshold, sensitivity, and other settings.
- **Visualization Modes:** Switch between timelapse, overlay, and flicker.
- **Statistics Display:** View absolute and relative change metrics.
- **Progress Feedback:** Visual indication of processing steps.
- **Interactive Previews:** Compare original, registered, and processed images.

---

## Example Usage

```matlab
image_paths = {
    '/path/to/image1.jpg',
    '/path/to/image2.jpg',
    '/path/to/image3.jpg'
};
main_picture_path = '/path/to/reference_image.jpg';
is_new_file_list = true;
category = 'city';

inputParams.threshold = 0.1;
inputParams.sensitivity = 0.5;
inputParams.rotation_tolerance = 2.0;
inputParams.change_detection_method = 'histogram';

[processed_images, gui_params] = processChangeDetection(...
    image_paths, ...
    main_picture_path, ...
    is_new_file_list, ...
    category, ...
    inputParams);
```
## Contributors
**Group 14:**
-Juan Diego Amaya Cueva
-Otto Dorfer
-Nejla Selimović
-Jakub Skupien
-Dinis Sousa Lopes Carmona
-Orhun Uçak

---