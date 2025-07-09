function overlay_image = get_red_overlay(ref_img, img, category, inputParams)
    % GET_RED_OVERLAY - Change detection using red mask overlay
    % This function implements change detection by highlighting changed areas in red
    % between two aligned images
    %
    % Inputs:
    %   ref_img - Reference RGB image (uint8, 3 channels)
    %   img - Comparison RGB image (uint8, 3 channels)
    %   category - Category for terrain mask ('all', 'city', 'water', 'forrest', 'ice', 'desert', 'farmland')
    %   inputParams - Optional struct with parameters
    %
    % Output:
    %   overlay_image - RGB image with red overlay highlighting changes (uint8, 3 channels)

    %% 1. INPUT VALIDATION
    fprintf('Starting get_red_overlay function...\n');

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

        alpha = helpers('getfield_default', inputParams, 'alpha', 0.5);
        gaussian_sigma = helpers('getfield_default', inputParams, 'gaussian_sigma', 1.0);
    else
        alpha = 0.5;
        gaussian_sigma = 1.0;
        use_otsu_threshold = true;
    end

    %% 3. CATEGORY-BASED MASK GENERATION
    fprintf('Generating terrain mask for category: %s\n', category);

    try
        % Call classifyImageByColor to get category-specific masks
        [~, ~, ~, masks] = classifyImageByColor(reference_image);

        % Map category names and select appropriate mask
        terrain_mask = get_category_mask(masks, category);
        fprintf('Terrain mask generated successfully using HSV classification.\n');
        terrain_mask = get_terrain_mask(ref_img, category);
        fprintf('Terrain mask generated successfully.\n');
    catch ME
        fprintf('Warning: get_terrain_mask function not available. Using partial image mask.\n');
        fprintf('Error: %s\n', ME.message);
        % Create a partial mask as fallback (exclude left half)
        terrain_mask = true(size(rgb2gray(ref_img)));
        terrain_mask(:, 1:size(terrain_mask, 2) / 2) = false;
    end

    %% 4. CHANGE DETECTION
    fprintf('Running change detection algorithm...\n');

    % Convert images to grayscale
    ref_img_gray = rgb2gray(ref_img);
    img_gray = rgb2gray(img);

    % Compute smoothed difference
    diff_image_smooth = get_smoothed_grayscale_diffs(ref_img_gray, img_gray, gaussian_sigma);

    %% 5. THRESHOLD DETERMINATION
    if use_otsu_threshold
        thr = determine_otsu_threshold(diff_image_smooth);
        fprintf('Using Otsu-determined threshold: %.4f\n', thr);
    end

    %% 6. RED OVERLAY GENERATION
    fprintf('Creating red overlay...\n');

    % Create binary change mask
    change_mask = diff_image_smooth > thr;

    % Apply terrain mask - only consider changes in relevant areas
    masked_change = change_mask & terrain_mask;

    % Create red overlay visualization
    overlay_image = img;

    % Create red overlay for changed areas
    red_overlay = cat(3, ones(size(masked_change)), zeros(size(masked_change)), zeros(size(masked_change)));

    % Apply alpha blending
    overlay_image = double(overlay_image) / 255; % Convert to double [0,1]

    for c = 1:3
        overlay_image(:, :, c) = overlay_image(:, :, c) .* (1 - alpha * masked_change) + ...
            red_overlay(:, :, c) .* (alpha * masked_change);
    end

    % Convert back to uint8
    overlay_image = uint8(overlay_image * 255);

    fprintf('Red overlay generation completed successfully!\n');
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
