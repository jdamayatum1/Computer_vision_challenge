% TEST_RED_OVERLAY - Test script for get_red_overlay function using Dubai images
% This script tests the red overlay change detection algorithm using Dubai dataset
% with a rotation of -8.9 degrees applied to the second image

clear all;
close all;
clc;

fprintf('=== Testing get_red_overlay function with Dubai images ===\n');

%% Configuration
% Base path to the datasets (adjust if needed)
base_path = 'C:\Users\ASUS\MATLAB\Projects\CV-Challenge\Datasets\Datasets\Dubai';

% Define image paths - using Dubai images from different years
image_paths = {
               fullfile(base_path, '12_1995.jpg'), % Reference image
               fullfile(base_path, '12_2000.jpg') % Comparison image (will be rotated)
               };

% Test parameters
category = 'desert'; % Dubai category
rotation_angle = -8.9; % Rotation to apply to second image

% Input parameters for red overlay
inputParams = struct();
% Test both explicit threshold and Otsu's method
test_otsu = true; % Set to false to use explicit threshold (0.12)

if ~test_otsu
    inputParams.threshold = 0.12; % Explicit threshold for comparison
    fprintf('Using explicit threshold: 0.12\n');
else
    fprintf('Using Otsu''s method to determine threshold automatically\n');
    % Don't set threshold - let Otsu's method determine it
end

inputParams.alpha = 0.6; % Semi-transparent red overlay
inputParams.gaussian_sigma = 1.2; % Gaussian smoothing for noise reduction

%% Verify image files exist
fprintf('Verifying image files...\n');

for i = 1:length(image_paths)

    if ~exist(image_paths{i}, 'file')
        error('Image file not found: %s', image_paths{i});
    else
        fprintf('  ✓ Found: %s\n', image_paths{i});
    end

end

%% Add source directory to path
addpath('../src/');
addpath('../src/overlay/');

%% Load and preprocess images
fprintf('\n=== Loading and preprocessing images ===\n');

% Load images
fprintf('Loading reference image...\n');
ref_img = imread(image_paths{1});
fprintf('Loading comparison image...\n');
img_original = imread(image_paths{2});

% Apply rotation to the second image
fprintf('Applying rotation of %.1f degrees to comparison image...\n', rotation_angle);
img_rotated = imrotate(img_original, rotation_angle, 'bilinear', 'crop');

% Ensure images are the same size (crop if needed after rotation)
[ref_h, ref_w, ~] = size(ref_img);
[img_h, img_w, ~] = size(img_rotated);

if ref_h ~= img_h || ref_w ~= img_w
    fprintf('Resizing images to match dimensions...\n');
    % Resize to match reference image dimensions
    img_rotated = imresize(img_rotated, [ref_h, ref_w]);
end

fprintf('Image preprocessing complete.\n');
fprintf('Reference image size: %dx%d\n', ref_h, ref_w);
fprintf('Comparison image size: %dx%d\n', size(img_rotated, 1), size(img_rotated, 2));

%% Run the test
fprintf('\n=== Running get_red_overlay function ===\n');
fprintf('Parameters:\n');
fprintf('  Category: %s\n', category);

if isfield(inputParams, 'threshold')
    fprintf('  Threshold: %.3f (explicit)\n', inputParams.threshold);
else
    fprintf('  Threshold: Will be determined by Otsu''s method\n');
end

fprintf('  Rotation applied: %.1f degrees\n', rotation_angle);
fprintf('  Alpha blending: %.1f\n', inputParams.alpha);
fprintf('  Gaussian sigma: %.1f\n', inputParams.gaussian_sigma);

try
    % Call the refactored function
    tic;
    overlay_image = get_red_overlay(ref_img, img_rotated, category, inputParams);
    elapsed_time = toc;

    fprintf('\n=== Test Results ===\n');
    fprintf('Processing completed successfully!\n');
    fprintf('Elapsed time: %.2f seconds\n', elapsed_time);
    fprintf('Output image size: %dx%d\n', size(overlay_image, 1), size(overlay_image, 2));

    %% Display results
    fprintf('\n=== Displaying Results ===\n');

    % Create figure for visualization
    figure('Name', 'Red Overlay Test Results - Dubai', 'Position', [100, 100, 1200, 700]);

    % Create subplot areas and store axes handles for synchronization
    ax1 = subplot(2, 3, 1);
    imshow(ref_img);
    title('Reference 1995');

    ax2 = subplot(2, 3, 2);
    imshow(img_original);
    title('Original 2000');

    ax3 = subplot(2, 3, 3);
    imshow(img_rotated);
    title(sprintf('Rotated 2000 (%.1f°)', rotation_angle));

    ax4 = subplot(2, 3, 4);
    imshow(overlay_image);
    title('Red Overlay Result');

    % Display summary
    subplot(2, 3, 5);
    axis off;

    summary_text = sprintf(['Test Summary:\n\n' ...
                                'Category: %s\n' ...
                                'Rotation: %.1f°\n' ...
                                'Alpha: %.1f\n\n' ...
                                'Processing Time: %.2fs\n\n' ...
                                'Red areas show\n' ...
                            'detected changes'], ...
        category, rotation_angle, inputParams.alpha, elapsed_time);

    text(0.1, 0.9, summary_text, 'VerticalAlignment', 'top', 'FontSize', 10, 'FontName', 'FixedWidth');

    % Link axes for synchronized zoom and pan (excluding summary)
    linkaxes([ax1, ax2, ax3, ax4], 'xy');
    fprintf('Axes synchronized for coordinated zoom and pan.\n');

    fprintf('Visualization complete. Check the figure window.\n');

    %% Save results (optional)
    save_results = input('\nSave results to file? (y/n): ', 's');

    if strcmpi(save_results, 'y')
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        results_file = sprintf('red_overlay_test_results_%s.mat', timestamp);
        save(results_file, 'overlay_image', 'inputParams', 'ref_img', 'img_rotated');
        fprintf('Results saved to: %s\n', results_file);

        % Save figure
        fig_file = sprintf('red_overlay_test_visualization_%s.png', timestamp);
        saveas(gcf, fig_file);
        fprintf('Visualization saved to: %s\n', fig_file);
    end

catch ME
    fprintf('\n❌ Test FAILED with error:\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack trace:\n');

    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end

    rethrow(ME);
end

fprintf('\n=== Red overlay test completed successfully! ===\n');
