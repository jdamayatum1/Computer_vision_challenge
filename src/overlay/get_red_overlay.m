function [processed_images, gui_params] = get_red_overlay(image_paths, main_picture_path, is_new_file_list, category, inputParams)
    % GET_RED_MASKING - Change detection using red mask overlay
    % This function implements change detection by highlighting changed areas in red
    % based on the interface specification and visualization_2 functionality

    %% 1. INPUT VALIDATION
    fprintf('Starting get_red_masking function...\n');

    [is_valid, message] = input_validation(image_paths, main_picture_path, category, is_new_file_list);

    if ~is_valid
        fprintf('Input validation failed with error:\n%s\n', message);
        return;
    end

    % Validate and process inputParams
    % use_otsu_threshold = true; % Flag to determine if we should use Otsu's method

    if exist('inputParams', 'var') && isstruct(inputParams)

        if isfield(inputParams, 'threshold')
            thr = inputParams.threshold;
            use_otsu_threshold = false; % Explicit threshold provided
            fprintf('Using explicit threshold: %.3f\n', thr);
        end

        rotation_angle = helpers('getfield_default', inputParams, 'rotation_angle', 0);
        dx = helpers('getfield_default', inputParams, 'dx', 0);
        dy = helpers('getfield_default', inputParams, 'dy', 0);
        alpha = helpers('getfield_default', inputParams, 'alpha', 0.5);
        gaussian_sigma = helpers('getfield_default', inputParams, 'gaussian_sigma', 1.0);
    else
        rotation_angle = 0;
        dx = 0;
        dy = 0;
        alpha = 0.5;
        gaussian_sigma = 1.0;
        inputParams = struct();
        inputParams.rotation_angle = rotation_angle;
        inputParams.dx = dx;
        inputParams.dy = dy;
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

    % %% 2.5. THRESHOLD DETERMINATION
    % if use_otsu_threshold
    %     fprintf('No explicit threshold provided. Using Otsu''s method to determine optimal threshold...\n');
    %     thr = helpers('determine_otsu_threshold', reference_image, images, gaussian_sigma);
    %     fprintf('Otsu-determined threshold: %.4f\n', thr);
    % else
    %     fprintf('Using provided threshold: %.3f\n', thr);
    % end

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

    %% 3.2 THRESHOLD DETERMINATION
    thr = determine_otsu_threshold(intermediate_images);

    %% 3.3 Mask overlay
    for i = 1:length(intermediate_images)
        % Create binary change mask
        change_mask = diff_image_smooth > thr;

        % Apply terrain mask - only consider changes in relevant areas
        masked_change = change_mask & terrain_mask;

        curr_img_rgb = images{i};

        % Create red overlay visualization
        overlay_image = curr_img_rgb;

        % Create red overlay for changed areas
        red_overlay = cat(3, ones(size(masked_change)), zeros(size(masked_change)), zeros(size(masked_change)));

        % Apply alpha blending
        for c = 1:3
            overlay_image(:, :, c) = overlay_image(:, :, c) .* (1 - alpha * masked_change) + ...
                red_overlay(:, :, c) .* (alpha * masked_change);
        end

        % Store processed image
        processed_images{i} = overlay_image;

        % Calculate statistics for masked areas
        total_terrain_mask_pixels = sum(terrain_mask(:));
        changed_pixels = sum(masked_change(:));
        change_stats(i) = changed_pixels / total_terrain_mask_pixels; % Relative change in relevant areas

        % Calculate confidence scores (avoid division by zero) TODO: evaluate
        % if sum(masked_change(:)) > 0
        %     confidence_scores(i) = mean(diff_image_smooth(masked_change)); % Average intensity of changes
        % else
        %     confidence_scores(i) = 0;
        % end

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
    gui_params.category = category;
    gui_params.detected_changes = change_stats;
    gui_params.confidence_scores = confidence_scores;
    gui_params.total_images = total_images;
    gui_params.avg_change_percentage = avg_change_percentage;
    gui_params.max_change_percentage = max_change_percentage;
    gui_params.min_change_percentage = min_change_percentage;
    % gui_params.terrain_mask = terrain_mask;

    % print the whole struct to console
    disp(gui_params);

    fprintf('Change detection completed successfully!\n');
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

    % normalize all values between 0 and 255
    min_pixel_value = min(all_pixels);
    max_pixel_value = max(all_pixels);
    all_pixels = uint8((all_pixels - min_pixel_value) / (max_pixel_value - min_pixel_value) * 255);

    % find global otsu threshold for the all pixels
    thr = graythresh(all_pixels);
end

function [diff_image_smooth] = get_smoothed_grayscale_diffs(reference_image, image, gaussian_sigma)
    % get the intermediate images
    % input: images - cell array of images
    % output: intermediate_images - cell array of intermediate images

    % Images are already preprocessed (rotated, translated, resized)
    curr_img_gray = rgb2gray(image);

    % Compute change detection
    diff_image = abs(reference_image - curr_img_gray);

    % Apply Gaussian smoothing to reduce noise
    diff_image_smooth = imgaussfilt(diff_image, gaussian_sigma, 'FilterSize', 5);

end
