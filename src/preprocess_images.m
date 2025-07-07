function preprocessedImages = preprocess_images(imagePaths)
% PREPROCESS_IMAGES - Loads and processes satellite images from given paths.
%
% Input:
%    imagePaths - Cell array of full paths to the images
%
% Output:
%   preprocessedImages - Struct array with fields:
%       .name  - file name
%       .image - preprocessed grayscale image

    if ~iscell(imagePaths)
        error('Input must be a cell array of image file paths.');
    end

    % Supported image formats
    valid_ext = {'.jpg', '.jpeg', '.png', '.tif', '.tiff'};

    % Validate and filter image paths
    validPaths = {};
    for i = 1:length(imagePaths)
        [~, name, ext] = fileparts(imagePaths{i});
        if any(strcmpi(ext, valid_ext))
            validPaths{end+1} = imagePaths{i};
        else
            error('Invalid file detected: %s. Allowed extensions: %s.', ...
                imagePaths{i}, strjoin(valid_ext, ', '));
        end
    end

    % Parse dates from filenames
    dateList = datetime.empty;
    for i = 1:length(validPaths)
        [~, nameOnly, ~] = fileparts(validPaths{i});
        matched = false;

        % Try matching different formats
        patterns = {
            '^\d{4}$',           'yyyy';            % 2020
            '^\d{1,2}_\d{4}$',   'M_yyyy';          % 9_2020
            '^\d{4}_\d{1,2}$',   'yyyy_MM';         % 2020_9
        };

        for j = 1:size(patterns, 1)
            if regexp(nameOnly, patterns{j, 1})
                try
                    switch patterns{j, 2}
                        case 'M_yyyy'
                            parts = sscanf(nameOnly, '%d_%d');
                            d = datetime(parts(2), parts(1), 1);
                        case 'yyyy_MM'
                            parts = sscanf(nameOnly, '%d_%d');
                            d = datetime(parts(1), parts(2), 1);
                        otherwise
                            d = datetime(nameOnly, 'InputFormat', patterns{j,2});
                    end
                    dateList(end+1) = d;
                    matched = true;
                    break;
                catch
                    % Try next
                end
            end
        end

        if ~matched
            error('Could not parse date from file name "%s".', nameOnly);
        end
    end

    % Sort by date
    [~, idx] = sort(dateList);
    sortedPaths = validPaths(idx);

    % First pass: find smallest image size (height x width)
    minSize = [Inf, Inf];  % [rows, cols]
    imageData = cell(length(sortedPaths), 1);

    for i = 1:length(sortedPaths)
        img = imread(sortedPaths{i});
        imageData{i} = img;

        sz = size(img);
        sz = sz(1:2);  % height and width

        if prod(sz) < prod(minSize)
            minSize = sz;
        end
    end

    % Output initialization
    preprocessedImages = struct('name', {}, 'image', {});

    for i = 1:length(sortedPaths)
        img = imageData{i};

        % Normalize brightness
        if size(img, 3) == 3
            img = im2double(img);
            hsv = rgb2hsv(img);
            hsv(:,:,3) = histeq(hsv(:,:,3));
            img = hsv2rgb(hsv);
        else
            img = histeq(img);
            img = im2double(img);
        end

        img = imgaussfilt(img, 1);  % Gaussian blur
        img = imresize(img, minSize);  % Resize to min size

        % Save
        [~, nameOnly, ext] = fileparts(sortedPaths{i});
        preprocessedImages(end+1).name = [nameOnly, ext];
        preprocessedImages(end).image = img;
    end
end
