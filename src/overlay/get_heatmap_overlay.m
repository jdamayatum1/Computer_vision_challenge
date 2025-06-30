function [processed_images, gui_params] = get_heatmap_overlay(image_paths, main_picture_path, is_new_file_list, category, inputParams)
    % GET_HEATMAP_OVERLAY - Change detection using heatmap overlay
    % This function implements change detection by creating a heatmap overlay
    % showing the intensity of changes using well-visible colors

    %% 1. INPUT VALIDATION
    fprintf('Starting get_heatmap_overlay function...\n');

    [is_valid, message] = input_validation(image_paths, main_picture_path, category, is_new_file_list);

    if ~is_valid
        fprintf('Input validation failed with error:\n%s\n', message);
        return;
    end

    % Validate and process inputParams
    if exist('inputParams', 'var') && isstruct(inputParams)

        if isfield(inputParams, 'threshold')
            thr = inputParams.threshold;
            use_otsu_threshold = false; % Explicit threshold provided
            fprintf('Using explicit threshold: %.3f\n', thr);
        else
            use_otsu_threshold = true;
        end

        rotation_angle = helpers('getfield_default', inputParams, 'rotation_angle', 0);
        dx = helpers('getfield_default', inputParams, 'dx', 0);
        dy = helpers('getfield_default', inputParams, 'dy', 0);
        alpha = helpers('getfield_default', inputParams, 'alpha', 0.6); % Slightly higher alpha for heatmap visibility
        gaussian_sigma = helpers('getfield_default', inputParams, 'gaussian_sigma', 1.0);
        colormap_name = helpers('getfield_default', inputParams, 'colormap_name', 'jet'); % Default to jet colormap for high visibility
    else
        rotation_angle = 0;
        dx = 0;
        dy = 0;
        alpha = 0.9; % Higher alpha for better heatmap visibility over faint background
        gaussian_sigma = 1.0;
        colormap_name = 'jet';
        use_otsu_threshold = true;
        inputParams = struct();
        inputParams.rotation_angle = rotation_angle;
        inputParams.dx = dx;
        inputParams.dy = dy;
        inputParams.alpha = alpha;
        inputParams.colormap_name = colormap_name;
    end

    %% 2. IMAGE PREPROCESSING
    fprintf('Starting image preprocessing...\n');

    if is_new_file_list
        % Use the helper function to get rotated and preprocessed images
        [images, reference_image] = helpers('get_rotated_images', image_paths, main_picture_path, inputParams);
        fprintf('Images preprocessed using get_rotated_images helper function.\n');
    else
        % Load existing preprocessed image objects from context
        % This would be implemented when context management is available
        fprintf('Loading existing preprocessed images from context...\n');
        [images, reference_image] = helpers('get_rotated_images', image_paths, main_picture_path, inputParams);
    end

    %% 3. CATEGORY-BASED MASK GENERATION
    fprintf('Generating terrain mask for category: %s\n', category);

    % Get the terrain mask using the utility function
    try
        terrain_mask = get_terrain_mask(reference_image, category);
        fprintf('Terrain mask generated successfully.\n');
    catch ME
        fprintf('Warning: get_terrain_mask function not available. Using full image mask.\n');
        fprintf('Error: %s\n', ME.message);
        % Create a full mask as fallback
        terrain_mask = true(size(rgb2gray(reference_image)));
        % make the left half false
        terrain_mask(:, 1:size(terrain_mask, 2) / 2) = false;
    end

    %% 4. CHANGE DETECTION ALGORITHM
    fprintf('Running change detection algorithm...\n');

    % Convert reference image to grayscale
    ref_img_gray = rgb2gray(reference_image);

    % Initialize output arrays
    processed_images = cell(length(images), 1);
    change_stats = zeros(length(images), 1);
    confidence_scores = zeros(length(images), 1);

    % list for storing intermediate images
    intermediate_images = cell(length(images), 1);

    for i = 1:length(images)
        diff_image_smooth = get_smoothed_grayscale_diffs(ref_img_gray, images{i}, gaussian_sigma);
        intermediate_images{i} = diff_image_smooth;
    end

    %% 4.1 THRESHOLD DETERMINATION
    if use_otsu_threshold
        thr = determine_otsu_threshold(intermediate_images);
        fprintf('Using Otsu-determined threshold: %.4f\n', thr);
    end

    %% 4.2 HEATMAP OVERLAY GENERATION
    fprintf('Creating heatmap overlays...\n');

    % Get the colormap for heatmap visualization
    cmap = get_heatmap_colormap(colormap_name);

    for i = 1:length(intermediate_images)
        diff_image_smooth = intermediate_images{i};

        % Apply terrain mask - only consider changes in relevant areas
        masked_diff = diff_image_smooth;
        masked_diff(~terrain_mask) = 0; % Set non-terrain areas to zero

        curr_img_rgb = images{i};

        % Create heatmap overlay visualization
        overlay_image = create_heatmap_overlay(curr_img_rgb, masked_diff, thr, alpha, cmap);

        % Store processed image
        processed_images{i} = overlay_image;

        % Calculate statistics for masked areas
        total_terrain_mask_pixels = sum(terrain_mask(:));
        % Count pixels above threshold in terrain areas
        significant_changes = (diff_image_smooth > thr) & terrain_mask;
        changed_pixels = sum(significant_changes(:));
        change_stats(i) = changed_pixels / total_terrain_mask_pixels; % Relative change in relevant areas

        % Calculate confidence scores based on mean intensity of changes above threshold
        if sum(significant_changes(:)) > 0
            confidence_scores(i) = mean(diff_image_smooth(significant_changes));
        else
            confidence_scores(i) = 0;
        end

    end

    %% 5. STATISTICS CALCULATION
    fprintf('Calculating change statistics...\n');

    total_images = length(images);
    avg_change_percentage = mean(change_stats) * 100;
    max_change_percentage = max(change_stats) * 100;
    min_change_percentage = min(change_stats) * 100;

    %% 6. OUTPUT PREPARATION
    fprintf('Preparing output parameters...\n');

    % Populate gui_params struct with relevant parameters for GUI
    gui_params = struct();
    gui_params.threshold = thr;
    gui_params.rotation_angle = rotation_angle;
    gui_params.dx = dx;
    gui_params.dy = dy;
    gui_params.alpha = alpha;
    gui_params.gaussian_sigma = gaussian_sigma;
    gui_params.colormap_name = colormap_name;
    gui_params.category = category;
    gui_params.detected_changes = change_stats;
    gui_params.confidence_scores = confidence_scores;
    gui_params.total_images = total_images;
    gui_params.avg_change_percentage = avg_change_percentage;
    gui_params.max_change_percentage = max_change_percentage;
    gui_params.min_change_percentage = min_change_percentage;

    % print the whole struct to console
    disp(gui_params);

    fprintf('Heatmap overlay generation completed successfully!\n');
    fprintf('Average change: %.2f%%, Max: %.2f%%, Min: %.2f%%\n', ...
        avg_change_percentage, max_change_percentage, min_change_percentage);

end

function [is_valid, message] = input_validation(image_paths, main_picture_path, category, is_new_file_list)
    is_valid = false;
    message = '';

    % Validate image_paths list
    if ~iscell(image_paths) || isempty(image_paths)
        message = 'image_paths must be a non-empty cell array';
        return;
    end

    % Verify main_picture_path exists
    if ~exist(main_picture_path, 'file')
        message = sprintf('Main picture path does not exist: %s', main_picture_path);
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

function [thr] = determine_otsu_threshold(intermediate_images)
    % determine the otsu threshold for the intermediate images
    % input: intermediate_images - cell array of intermediate images
    % output: thr - otsu threshold

    % create a long vector of all pixels in the intermediate images
    all_pixels = [];

    for i = 1:length(intermediate_images)
        all_pixels = [all_pixels; intermediate_images{i}(:)];
    end

    % normalize all values between 0 and 1 for graythresh
    min_pixel_value = min(all_pixels);
    max_pixel_value = max(all_pixels);

    if max_pixel_value > min_pixel_value
        all_pixels_normalized = (all_pixels - min_pixel_value) / (max_pixel_value - min_pixel_value);
    else
        all_pixels_normalized = zeros(size(all_pixels));
    end

    % find global otsu threshold
    otsu_level = graythresh(all_pixels_normalized);

    % Convert back to original scale
    thr = otsu_level * (max_pixel_value - min_pixel_value) + min_pixel_value;
end

function [diff_image_smooth] = get_smoothed_grayscale_diffs(reference_image, image, gaussian_sigma)
    % get the smoothed grayscale difference images
    % input: reference_image - reference grayscale image
    %        image - current RGB image
    %        gaussian_sigma - sigma for Gaussian smoothing
    % output: diff_image_smooth - smoothed difference image

    % Images are already preprocessed (rotated, translated, resized)
    curr_img_gray = rgb2gray(image);

    % Compute change detection
    diff_image = abs(double(reference_image) - double(curr_img_gray));

    % Apply Gaussian smoothing to reduce noise
    diff_image_smooth = imgaussfilt(diff_image, gaussian_sigma, 'FilterSize', 5);
end

function [cmap] = get_heatmap_colormap(colormap_name)
    % Get a suitable colormap for heatmap visualization
    % input: colormap_name - name of the colormap
    % output: cmap - colormap matrix

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

function [overlay_image] = create_heatmap_overlay(base_image, diff_image, threshold, alpha, colormap_matrix)
    % Create heatmap overlay on faint base image
    % input: base_image - original RGB image
    %        diff_image - difference intensity image
    %        threshold - threshold for significant changes
    %        alpha - blending factor for heatmap
    %        colormap_matrix - colormap for heatmap
    % output: overlay_image - faint base image with prominent heatmap overlay

    % Convert base image to double [0,1] - keep at full brightness initially
    base_normalized = double(base_image);

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
    % Higher intensity changes get more opacity
    heatmap_alpha = diff_normalized .* significant_mask;

    % Scale alpha to ensure strong visibility (minimum 0.6 for any significant change)
    min_visible_alpha = 0.6;
    heatmap_alpha(significant_mask) = min_visible_alpha + heatmap_alpha(significant_mask) * (alpha - min_visible_alpha);

    % Initialize output image
    overlay_image = zeros(size(base_normalized));

    % Apply proper alpha blending
    for c = 1:3
        % Areas with significant changes: blend base image (faint) with heatmap (strong)
        % Areas without changes: show base image at faint opacity
        overlay_image(:, :, c) = base_normalized(:, :, c) .* faint_base_opacity .* (1 - significant_mask) + ... % Faint base in unchanged areas
            base_normalized(:, :, c) .* (1 - heatmap_alpha) .* significant_mask + ... % Reduced base in change areas
            heatmap_rgb(:, :, c) .* heatmap_alpha; % Heatmap overlay
    end

    % Ensure output values are in valid range [0,1]
    overlay_image = max(0, min(1, overlay_image));

    % Convert back to uint8
    overlay_image = uint8(overlay_image * 255);
end
