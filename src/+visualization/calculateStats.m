%% Statistics Calculation Functions

function stats = calculateStats(ref_img, img, mask_ref_img, mask_img, mask_diff)
    % Calculate statistics for change detection analysis
    %
    % Inputs:
    %   ref_img - Reference image (grayscale or RGB)
    %   img - Comparison image (grayscale or RGB)
    %   mask_ref_img - Mask for reference image
    %   mask_img - Mask for comparison image
    %   mask_diff - Mask for difference/change areas
    %
    % Outputs:
    %   stats - Statistics struct with various metrics

    % Initialize stats structure
    stats = struct();

    % Basic image information
    stats.image_size = size(ref_img);
    stats.total_pixels = numel(mask_ref_img);

    stats.img_ref_mask = mask_ref_img;
    stats.img_img_mask = mask_img;
    stats.img_diff_mask = mask_diff;

    % Mask statistics
    stats.mask_ref_pixels = sum(mask_ref_img(:));
    stats.mask_img_pixels = sum(mask_img(:));
    stats.mask_diff_pixels = sum(mask_diff(:));

    % Coverage percentages
    stats.mask_ref_coverage = (stats.mask_ref_pixels / stats.total_pixels);
    stats.mask_img_coverage = (stats.mask_img_pixels / stats.total_pixels);
    stats.mask_diff_coverage = (stats.mask_diff_pixels / stats.total_pixels);

    % Change detection metrics (placeholders for user implementation)
    stats.change_intensity_mean = 0;
    stats.change_intensity_std = 0;
    stats.change_intensity_max = 0;
    stats.change_intensity_min = 0;

    % Regional statistics (placeholders for user implementation)
    stats.total_change_area = 0;
    stats.largest_change_region = 0;
    stats.num_change_regions = 0;

    % Validation metrics (placeholders for user implementation)
    stats.false_positive_rate = 0;
    stats.false_negative_rate = 0;
    stats.accuracy = 0;
    stats.precision = 0;
    stats.recall = 0;

    % Temporal information
    stats.computation_time = 0;
    stats.timestamp = datetime('now');

    % Additional metadata
    stats.algorithm_version = '1.0';
    stats.parameters_used = struct();

    fprintf('Statistics calculated successfully.\n');
    fprintf('Total pixels: %d\n', stats.total_pixels);
    fprintf('Reference mask coverage: %.2f%%\n', stats.mask_ref_coverage);
    fprintf('Comparison mask coverage: %.2f%%\n', stats.mask_img_coverage);
    fprintf('Change mask coverage: %.2f%%\n', stats.mask_diff_coverage);
end
