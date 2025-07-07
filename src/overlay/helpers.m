function varargout = helpers(func_name, varargin)
    % HELPERS - Collection of helper functions for computer vision challenge
    % Usage: result = helpers('function_name', arg1, arg2, ...)

    switch func_name
        case 'get_rotated_images'
            [varargout{1:nargout}] = get_rotated_images(varargin{:});
        case 'getfield_default'
            [varargout{1:nargout}] = getfield_default(varargin{:});
        case 'translate_image'
            [varargout{1:nargout}] = translate_image(varargin{:});
        case 'translate_image_rgb'
            [varargout{1:nargout}] = translate_image_rgb(varargin{:});
        case 'determine_otsu_threshold'
            [varargout{1:nargout}] = determine_otsu_threshold(varargin{:});
        otherwise
            error('Unknown function: %s', func_name);
    end

end

function [processed_images, reference_image] = get_rotated_images(image_paths, main_picture_path, inputParams)
    % GET_ROTATED_IMAGES - Dummy preprocessing function for image rotation and translation
    % This function will be replaced with the actual preprocessing implementation
    %
    % Inputs:
    %   image_paths - cell array of image file paths
    %   main_picture_path - path to reference image
    %   inputParams - struct with rotation_angle, dx, dy parameters
    %
    % Outputs:
    %   processed_images - cell array of preprocessed image objects
    %   reference_image - preprocessed reference image

    fprintf('Loading and preprocessing images using get_rotated_images...\n');

    % Extract parameters
    rotation_angle = getfield_default(inputParams, 'rotation_angle', 0);
    dx = getfield_default(inputParams, 'dx', 0);
    dy = getfield_default(inputParams, 'dy', 0);

    % Load reference image
    reference_image = imread(main_picture_path);
    ref_img_rgb = im2double(reference_image);

    % Initialize output
    processed_images = cell(length(image_paths), 1);

    % Process each image
    for i = 1:length(image_paths)

        if ~exist(image_paths{i}, 'file')
            error('Image file does not exist: %s', image_paths{i});
        end

        % Load image
        curr_img = imread(image_paths{i});
        curr_img_rgb = im2double(curr_img);

        % Resize if dimensions don't match reference
        if ~isequal(size(curr_img_rgb, [1, 2]), size(ref_img_rgb, [1, 2]))
            curr_img_rgb = imresize(curr_img_rgb, size(ref_img_rgb, [1, 2]));
            fprintf('Resized image %d to match reference dimensions.\n', i);
        end

        % Apply rotation only to the second image (index 2)
        if rotation_angle ~= 0 && i == 2
            curr_img_rgb = imrotate(curr_img_rgb, rotation_angle, 'bicubic', 'crop');
            fprintf('Applied rotation of %.1f degrees to image %d.\n', rotation_angle, i);
        elseif i == 1
            fprintf('Image %d (reference) left unrotated.\n', i);
        else
            fprintf('Image %d left unrotated (rotation only applied to image 2).\n', i);
        end

        % Apply translation (dummy implementation for now)
        if dx ~= 0 || dy ~= 0
            curr_img_rgb = translate_image_rgb(curr_img_rgb, dx, dy);
            fprintf('Applied translation (%d, %d) to image %d.\n', dx, dy, i);
        end

        processed_images{i} = curr_img_rgb;
    end

    % Convert reference image to double
    reference_image = ref_img_rgb;

    fprintf('Preprocessing completed for %d images.\n', length(image_paths));
end

function value = getfield_default(struct_var, field_name, default_value)
    % Helper function to get field value with default fallback
    if isfield(struct_var, field_name)
        value = struct_var.(field_name);
    else
        value = default_value;
    end

end

function translated_img = translate_image(img, dx, dy)
    % Translate grayscale image by dx, dy pixels
    [rows, cols] = size(img);
    translated_img = zeros(rows, cols);

    % Calculate valid regions after translation
    src_row_start = max(1, 1 - dy);
    src_row_end = min(rows, rows - dy);
    src_col_start = max(1, 1 - dx);
    src_col_end = min(cols, cols - dx);

    dst_row_start = max(1, 1 + dy);
    dst_row_end = min(rows, rows + dy);
    dst_col_start = max(1, 1 + dx);
    dst_col_end = min(cols, cols + dx);

    % Perform translation
    translated_img(dst_row_start:dst_row_end, dst_col_start:dst_col_end) = ...
        img(src_row_start:src_row_end, src_col_start:src_col_end);
end

function translated_img = translate_image_rgb(img, dx, dy)
    % Translate RGB image by dx, dy pixels
    [rows, cols, channels] = size(img);
    translated_img = zeros(rows, cols, channels);

    % Calculate valid regions after translation
    src_row_start = max(1, 1 - dy);
    src_row_end = min(rows, rows - dy);
    src_col_start = max(1, 1 - dx);
    src_col_end = min(cols, cols - dx);

    dst_row_start = max(1, 1 + dy);
    dst_row_end = min(rows, rows + dy);
    dst_col_start = max(1, 1 + dx);
    dst_col_end = min(cols, cols + dx);

    % Perform translation for each channel
    for c = 1:channels
        translated_img(dst_row_start:dst_row_end, dst_col_start:dst_col_end, c) = ...
            img(src_row_start:src_row_end, src_col_start:src_col_end, c);
    end

end

function optimal_threshold = determine_otsu_threshold(reference_image, images, gaussian_sigma)
    % DETERMINE_OTSU_THRESHOLD - Automatically determine optimal threshold using Otsu's method
    % This function analyzes difference images to find the best threshold for change detection
    %
    % Inputs:
    %   reference_image - reference image (RGB, already preprocessed)
    %   images - cell array of comparison images (RGB, already preprocessed)
    %   gaussian_sigma - sigma value for Gaussian smoothing (optional, default 1.0)
    %
    % Outputs:
    %   optimal_threshold - optimal threshold value determined by Otsu's method

    if nargin < 3
        gaussian_sigma = 1.0;
    end

    fprintf('Determining optimal threshold using Otsu''s method...\n');

    % Convert reference image to grayscale
    ref_img_gray = rgb2gray(reference_image);

    % Collect all difference values from all image pairs
    all_diff_values = [];

    % Process each comparison image
    for i = 1:length(images)
        % Convert current image to grayscale
        curr_img_gray = rgb2gray(images{i});

        % Ensure same dimensions
        if ~isequal(size(ref_img_gray), size(curr_img_gray))
            error('Error in function determine_otsu_threshold: Reference and current image have different dimensions');
        end

        % Compute difference image
        diff_image = abs(ref_img_gray - curr_img_gray);

        % Apply Gaussian smoothing
        diff_image_smooth = imgaussfilt(diff_image, gaussian_sigma, 'FilterSize', 3);

        % Collect difference values
        all_diff_values = [all_diff_values; diff_image_smooth(:)];
    end

    % Remove zero values to focus on actual differences
    all_diff_values = all_diff_values(all_diff_values > 0);

    if isempty(all_diff_values)
        fprintf('Warning: No differences found between images. Using default threshold 0.1.\n');
        optimal_threshold = 0.1;
        return;
    end

    % Normalize values to [0, 1] range for Otsu's method
    min_val = min(all_diff_values);
    max_val = max(all_diff_values);

    if max_val == min_val
        fprintf('Warning: All difference values are identical. Using default threshold 0.1.\n');
        optimal_threshold = 0.1;
        return;
    end

    normalized_values = (all_diff_values - min_val) / (max_val - min_val);

    % Apply Otsu's method to find optimal threshold
    % Convert to uint8 for graythresh function
    values_uint8 = uint8(normalized_values * 255);

    % Use MATLAB's implementation of Otsu's method
    otsu_threshold_normalized = graythresh(values_uint8);

    % Convert back to original scale
    optimal_threshold = otsu_threshold_normalized * (max_val - min_val) + min_val;

    % Apply some bounds checking
    optimal_threshold = max(0.01, min(0.5, optimal_threshold)); % Constrain between 0.01 and 0.5

    fprintf('Otsu''s method determined optimal threshold: %.4f\n', optimal_threshold);
    fprintf('  (normalized Otsu threshold: %.4f, value range: [%.4f, %.4f])\n', ...
        otsu_threshold_normalized, min_val, max_val);

end
