% TEST_RED_MASKING - Test script for get_red_overlay function using Dubai images
% This script tests the red masking change detection algorithm using Dubai dataset
% with a rotation of -8.9 degrees applied to the second image

clear all;
close all;
clc;

fprintf('=== Testing get_red_overlay function with Dubai images ===\n');

%% Configuration
% Base path to the datasets (adjust if needed)
base_path = '../challenge/Datasets/Dubai/';

% Define image paths - using Dubai images from different years
image_paths = {
               fullfile(base_path, '12_1995.jpg'), % Before image
               fullfile(base_path, '12_2000.jpg') % After image (will be rotated)
               };

% Reference image (main picture for alignment)
main_picture_path = fullfile(base_path, '12_1995.jpg');

% Test parameters
is_new_file_list = true; % Force preprocessing
category = 'city'; % Dubai is a city development

% Input parameters with rotation
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

inputParams.rotation_angle = -8.9; % Rotate by -8.9 degrees as requested
inputParams.dx = 0; % No horizontal translation
inputParams.dy = 0; % No vertical translation
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

if ~exist(main_picture_path, 'file')
    error('Main picture not found: %s', main_picture_path);
else
    fprintf('  ✓ Reference image: %s\n', main_picture_path);
end

%% Add source directory to path
addpath('src/');

%% Run the test
fprintf('\n=== Running get_red_overlay function ===\n');
fprintf('Parameters:\n');
fprintf('  Category: %s\n', category);

if isfield(inputParams, 'threshold')
    fprintf('  Threshold: %.3f (explicit)\n', inputParams.threshold);
else
    fprintf('  Threshold: Will be determined by Otsu''s method\n');
end

fprintf('  Rotation: %.1f degrees\n', inputParams.rotation_angle);
fprintf('  Alpha blending: %.1f\n', inputParams.alpha);
fprintf('  Gaussian sigma: %.1f\n', inputParams.gaussian_sigma);

try
    % Call the main function
    tic;
    [processed_images, gui_params] = get_red_overlay( ...
        image_paths, ...
        main_picture_path, ...
        is_new_file_list, ...
        category, ...
        inputParams);
    elapsed_time = toc;

    fprintf('\n=== Test Results ===\n');
    fprintf('Processing completed successfully!\n');
    fprintf('Elapsed time: %.2f seconds\n', elapsed_time);
    fprintf('Number of processed images: %d\n', length(processed_images));

    % Display statistics
    fprintf('\n=== Change Detection Statistics ===\n');
    fprintf('Average change: %.2f%%\n', gui_params.avg_change_percentage);
    fprintf('Maximum change: %.2f%%\n', gui_params.max_change_percentage);
    fprintf('Minimum change: %.2f%%\n', gui_params.min_change_percentage);

    % Display individual image results
    fprintf('\nIndividual Results:\n');

    for i = 1:length(gui_params.detected_changes)
        fprintf('  Image %d: %.2f%% change, confidence: %.3f\n', ...
            i, gui_params.detected_changes(i) * 100, gui_params.confidence_scores(i));
    end

    %% Display results
    fprintf('\n=== Displaying Results ===\n');

    % Create figure for visualization
    figure('Name', 'Red Masking Test Results - Dubai', 'Position', [100, 100, 1200, 800]);

    % Load original images for comparison
    img1 = imread(image_paths{1});
    img2 = imread(image_paths{2});

    % Create subplot areas and store axes handles for synchronization
    ax1 = subplot(2, 3, 1);
    imshow(img1);
    title('Original 1995 (Reference)');

    ax2 = subplot(2, 3, 2);
    imshow(img2);
    title('Original 2000 (Before Rotation)');

    % Display terrain mask if available
    ax3 = subplot(2, 3, 3);

    if isfield(gui_params, 'terrain_mask')
        imshow(gui_params.terrain_mask);
        title(sprintf('Terrain Mask (%s)', category));
    else
        text(0.5, 0.5, 'No terrain mask available', 'HorizontalAlignment', 'center');
        title('Terrain Mask (Not Available)');
    end

    % Display processed images with red overlay and store axes handles
    axes_to_link = [ax1, ax2, ax3]; % Initialize with first three axes

    for i = 1:min(length(processed_images), 2) % Show up to 2 processed images
        ax_processed = subplot(2, 3, 3 + i);
        imshow(processed_images{i});
        title(sprintf('Processed Image %d\nChange: %.2f%%', i, gui_params.detected_changes(i) * 100));
        axes_to_link = [axes_to_link, ax_processed]; % Add to axes list
    end

    %% Link axes for synchronized zoom and pan
    linkaxes(axes_to_link, 'xy');
    fprintf('Axes synchronized for coordinated zoom and pan.\n');

    % Display summary in the last subplot
    subplot(2, 3, 6);
    axis off;
    % Handle threshold display in summary
    if isfield(inputParams, 'threshold')
        threshold_text = sprintf('%.3f (explicit)', inputParams.threshold);
    else
        threshold_text = sprintf('%.3f (Otsu)', gui_params.threshold);
    end

    summary_text = sprintf(['Test Summary:\n\n' ...
                                'Category: %s\n' ...
                                'Rotation: %.1f°\n' ...
                                'Threshold: %s\n' ...
                                'Alpha: %.1f\n\n' ...
                                'Avg Change: %.2f%%\n' ...
                                'Max Change: %.2f%%\n' ...
                            'Processing Time: %.2fs'], ...
        category, inputParams.rotation_angle, threshold_text, inputParams.alpha, ...
        gui_params.avg_change_percentage, gui_params.max_change_percentage, elapsed_time);

    text(0.1, 0.9, summary_text, 'VerticalAlignment', 'top', 'FontSize', 10, 'FontName', 'FixedWidth');

    fprintf('Visualization complete. Check the figure window.\n');

    %% Save results (optional)
    save_results = input('\nSave results to file? (y/n): ', 's');

    if strcmpi(save_results, 'y')
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        results_file = sprintf('test_results_%s.mat', timestamp);
        save(results_file, 'processed_images', 'gui_params', 'inputParams', 'image_paths');
        fprintf('Results saved to: %s\n', results_file);

        % Save figure
        fig_file = sprintf('test_visualization_%s.png', timestamp);
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

fprintf('\n=== Test completed successfully! ===\n');
