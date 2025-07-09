function overlay_image = get_heatmap_overlay(ref_img, img, category, inputParams)
    % GET_HEATMAP_OVERLAY - Change detection using heatmap overlay
    % This function implements change detection by creating a heatmap overlay
    % showing the intensity of changes between two aligned images
    %
    % Inputs:
    %   ref_img - Reference RGB image (uint8, 3 channels)
    %   img - Comparison RGB image (uint8, 3 channels)
    %   category - Category for terrain mask ('all', 'city', 'water', 'forrest', 'ice', 'desert', 'farmland')
    %   inputParams - Optional struct with parameters
    %
    % Output:
    %   overlay_image - RGB image with heatmap overlay (uint8, 3 channels)

    %% 1. INPUT VALIDATION
    fprintf('Starting get_heatmap_overlay function...\n');

    [is_valid, message] = input_validation(ref_img, img, category);

    if ~is_valid
        fprintf('Input validation failed with error:\n%s\n', message);
        return;
    end

    %% 2. PARAMETER PROCESSING
    if exist('inputParams', 'var') && isstruct(inputParams)

        if isfield(inputParams, 'threshold')
            thr = inputParams.threshold;
            use_otsu_threshold = false;
            fprintf('Using explicit threshold: %.3f\n', thr);
        else
            use_otsu_threshold = true;
        end

        alpha = inputParams.alpha;
        gaussian_sigma = inputParams.gaussian_sigma;
        colormap_name = inputParams.colormap_name;
    else
        alpha = 0.6;
        gaussian_sigma = 1.0;
        colormap_name = 'jet';
        use_otsu_threshold = true;
    end

    %% 3. CATEGORY-BASED MASK GENERATION
    fprintf('Generating terrain mask for category: %s\n', category);

    try
        terrain_mask = get_terrain_mask(ref_img, category);
        fprintf('Terrain mask generated successfully.\n');
    catch ME
        fprintf('Warning: get_terrain_mask function not available. Using partial image mask.\n');
        fprintf('Error: %s\n', ME.message);
        % Create a partial mask as fallback (exclude left half)
        terrain_mask = true(size(rgb2gray(ref_img)));
        % terrain_mask(:, 1:size(terrain_mask, 2) / 2) = false;
    end

    %% 4. CHANGE DETECTION
    fprintf('Running change detection algorithm...\n');

    % Convert images to grayscale
    ref_img_gray = rgb2gray(ref_img);
    img_gray = rgb2gray(img);

    % get the mask of black pixels in the rotated image
    black_mask = img_gray == 0;

    % set the pixels in reference image to black
    ref_img_gray(black_mask) = 0;

    % Compute smoothed difference
    diff_image_smooth = get_smoothed_grayscale_diffs(ref_img_gray, img_gray, gaussian_sigma);

    %% 5. THRESHOLD DETERMINATION
    if use_otsu_threshold
        thr = determine_otsu_threshold(diff_image_smooth);
        fprintf('Using Otsu-determined threshold: %.4f\n', thr);
    end

    %% 6. HEATMAP OVERLAY GENERATION
    fprintf('Creating heatmap overlay...\n');

    % Apply terrain mask - only consider changes in relevant areas
    masked_diff = diff_image_smooth;
    masked_diff(~terrain_mask) = 0;

    % Get colormap for heatmap visualization
    cmap = get_heatmap_colormap(colormap_name);

    % Create heatmap overlay
    overlay_image = create_heatmap_overlay(img, masked_diff, thr, alpha, cmap);

    fprintf('Heatmap overlay generation completed successfully!\n');
end

function [is_valid, message] = input_validation(ref_img, img, category)
    is_valid = false;
    message = '';

    % Validate reference image
    if ~isa(ref_img, 'uint8') || size(ref_img, 3) ~= 3
        message = 'Reference image must be uint8 RGB image with 3 channels';
        return;
    end

    % Validate comparison image
    if ~isa(img, 'uint8') || size(img, 3) ~= 3
        message = 'Comparison image must be uint8 RGB image with 3 channels';
        return;
    end

    % Check image dimensions match
    if ~isequal(size(ref_img), size(img))
        message = 'Reference and comparison images must have the same dimensions';
        return;
    end

    % Check category is valid
    valid_categories = {'all', 'city', 'water', 'forrest', 'ice', 'desert', 'farmland'};

    if ~ismember(category, valid_categories)
        message = sprintf('Invalid category: %s. Must be one of: %s', category, strjoin(valid_categories, ', '));
        return;
    end

    is_valid = true;
    message = 'Input validation passed';
end

function thr = determine_otsu_threshold(diff_image)
    % Determine the Otsu threshold for the difference image
    % Input: diff_image - difference image
    % Output: thr - Otsu threshold

    % Normalize values between 0 and 1 for graythresh
    min_pixel_value = min(diff_image(:));
    max_pixel_value = max(diff_image(:));

    if max_pixel_value > min_pixel_value
        diff_normalized = (diff_image - min_pixel_value) / (max_pixel_value - min_pixel_value);
    else
        diff_normalized = zeros(size(diff_image));
    end

    % Find Otsu threshold
    otsu_level = graythresh(diff_normalized);

    % Convert back to original scale
    thr = otsu_level * (max_pixel_value - min_pixel_value) + min_pixel_value;
end

function diff_image_smooth = get_smoothed_grayscale_diffs(ref_img_gray, img_gray, gaussian_sigma)
    % Get the smoothed grayscale difference between two images
    % Input: ref_img_gray - reference grayscale image
    %        img_gray - comparison grayscale image
    %        gaussian_sigma - sigma for Gaussian smoothing
    % Output: diff_image_smooth - smoothed difference image

    % Compute absolute difference
    diff_image = abs(double(ref_img_gray) - double(img_gray));

    % Apply Gaussian smoothing to reduce noise
    diff_image_smooth = imgaussfilt(diff_image, gaussian_sigma, 'FilterSize', 5);
end

function cmap = get_heatmap_colormap(colormap_name)
    % Get a suitable colormap for heatmap visualization
    % Input: colormap_name - name of the colormap
    % Output: cmap - colormap matrix

    try

        switch lower(colormap_name)
            case 'hot'
                cmap = hot(256);
            case 'jet'
                cmap = jet(256);
            case 'parula'
                cmap = parula(256);
            case 'turbo'
                cmap = turbo(256);
            case 'plasma'
                % Custom plasma-like colormap for better visibility
                cmap = [linspace(0, 1, 256)', linspace(0, 0.8, 256)', linspace(0.8, 0.2, 256)'];
            otherwise
                fprintf('Unknown colormap %s, using jet as default\n', colormap_name);
                cmap = jet(256);
        end

    catch
        % Fallback to jet colormap
        cmap = jet(256);
    end

end

function overlay_image = create_heatmap_overlay(base_image, diff_image, threshold, alpha, colormap_matrix)
    % Create heatmap overlay on faint base image
    % Input: base_image - original RGB image
    %        diff_image - difference intensity image
    %        threshold - threshold for significant changes
    %        alpha - blending factor for heatmap
    %        colormap_matrix - colormap for heatmap
    % Output: overlay_image - faint base image with prominent heatmap overlay

    % Convert base image to double [0,1]
    base_normalized = double(base_image) / 255;

    % Faint background opacity for areas without changes
    faint_base_opacity = 0.4;

    % Normalize difference image to [0, 1] range for colormap indexing
    max_diff = max(diff_image(:));

    if max_diff > 0
        diff_normalized = diff_image / max_diff;
    else
        diff_normalized = zeros(size(diff_image));
    end

    % Create a mask for areas above threshold
    significant_mask = diff_image > threshold;

    % Convert normalized differences to colormap indices
    colormap_indices = max(1, min(256, round(diff_normalized * 255) + 1));

    % Create RGB heatmap
    [rows, cols] = size(diff_image);
    heatmap_rgb = zeros(rows, cols, 3);

    for i = 1:rows

        for j = 1:cols

            if significant_mask(i, j)
                color_idx = colormap_indices(i, j);
                heatmap_rgb(i, j, :) = colormap_matrix(color_idx, :);
            end

        end

    end

    % Create intensity-based alpha mask for heatmap visibility
    heatmap_alpha = diff_normalized .* significant_mask;

    % Scale alpha to ensure strong visibility (minimum 0.6 for any significant change)
    min_visible_alpha = 0.6;
    heatmap_alpha(significant_mask) = min_visible_alpha + heatmap_alpha(significant_mask) * (alpha - min_visible_alpha);

    % Initialize output image
    overlay_image = zeros(size(base_normalized));

    % Apply alpha blending
    for c = 1:3
        % Areas with significant changes: blend base image (faint) with heatmap (strong)
        % Areas without changes: show base image at faint opacity
        overlay_image(:, :, c) = base_normalized(:, :, c) .* faint_base_opacity .* (1 - significant_mask) + ...
            base_normalized(:, :, c) .* (1 - heatmap_alpha) .* significant_mask + ...
            heatmap_rgb(:, :, c) .* heatmap_alpha;
    end

    % Ensure output values are in valid range [0,1]
    overlay_image = max(0, min(1, overlay_image));

    % Convert back to uint8
    overlay_image = uint8(overlay_image * 255);
end
