function imageAlignmentApp()
    % Create a figure for the UI
    fig = uifigure('Position', [100, 100, 300, 200], 'Name', 'Image Alignment');

    % Create properties to store images
    fig.UserData.fixedImage = [];
    fig.UserData.movingImage = [];

    % Create button for automatic alignment
    btnAutoAlign = uibutton(fig, 'Text', 'Automatic Alignment', ...
        'Position', [50, 120, 200, 40], ...
        'ButtonPushedFcn', @(btn, event) automaticAlignment(fig));

    % Create button for manual control point selection
    btnManualAlign = uibutton(fig, 'Text', 'Choose Control Points Manually', ...
        'Position', [50, 60, 200, 40], ...
        'ButtonPushedFcn', @(btn, event) manualControlPointSelection(fig));
end

function automaticAlignment(fig)
    % Prompt user to select the fixed image
    [fixedImageFile, fixedImagePath] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files (*.jpg, *.png, *.tif)'}, 'Select Fixed Image');
    if isequal(fixedImageFile, 0)
        disp('User canceled the selection.');
        return; % Exit if no file is selected
    end
    fixedImage = imread(fullfile(fixedImagePath, fixedImageFile));
    fig.UserData.fixedImage = fixedImage; % Store fixed image in UserData

    % Prompt user to select the moving image
    [movingImageFile, movingImagePath] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files (*.jpg, *.png, *.tif)'}, 'Select Moving Image');
    if isequal(movingImageFile, 0)
        disp('User canceled the selection.');
        return; % Exit if no file is selected
    end
    movingImage = imread(fullfile(movingImagePath, movingImageFile));
    fig.UserData.movingImage = movingImage; % Store moving image in UserData

    % Convert to grayscale if necessary
    fixedImage = convertToGray(fixedImage);
    movingImage = convertToGray(movingImage);

    % Detect features
    pointsFixed = detectSURFFeatures(fixedImage);
    pointsMoving = detectSURFFeatures(movingImage);

    % Extract features
    [featuresFixed, validPointsFixed] = extractFeatures(fixedImage, pointsFixed);
    [featuresMoving, validPointsMoving] = extractFeatures(movingImage, pointsMoving);

    % Match features
    indexPairs = matchFeatures(featuresFixed, featuresMoving);

    if isempty(indexPairs)
        disp('Automatic feature matching failed. Please select control points manually.');
        manualControlPointSelection(fig); % Call manual selection with the figure
        return;
    end

    matchedPointsFixed = validPointsFixed(indexPairs(:, 1), :);
    matchedPointsMoving = validPointsMoving(indexPairs(:, 2), :);

    % Estimate geometric transformation
    [tform, ~] = estimateGeometricTransform(matchedPointsMoving, matchedPointsFixed, 'affine');

    % Apply transformation
    alignedImage = imwarp(movingImage, tform, 'OutputView', imref2d(size(fixedImage)));

    % Display results
    displayResults(fixedImage, movingImage, alignedImage);
end

function manualControlPointSelection(fig)
    % Retrieve images from UserData
    fixedImage = fig.UserData.fixedImage;
    movingImage = fig.UserData.movingImage;

    if isempty(fixedImage) || isempty(movingImage)
        disp('Images must be loaded before selecting control points.');
        return;
    end

    % Open cpselect for manual control point selection
    [movingPoints, fixedPoints] = cpselect(movingImage, fixedImage, 'Wait', true);
    [tform, ~] = estimateGeometricTransform(movingPoints, fixedPoints, 'affine');
    alignedImage = imwarp(movingImage, tform, 'OutputView', imref2d(size(fixedImage)));

    % Display results
    displayResults(fixedImage, movingImage, alignedImage);
end

function grayImage = convertToGray(image)
    if size(image, 3) == 3
        grayImage = rgb2gray(image);
    else
        grayImage = image;
    end
end

function displayResults(fixedImage, movingImage, alignedImage)
    figure;
    subplot(1, 2, 1);
    imshow(fixedImage);
    title('Fixed Image');

    subplot(1, 2, 2);
    imshow(movingImage);
    title('Moving Image');
    
    figure;
    imshow(alignedImage);
    title('Aligned Image');

    % Calculate the absolute difference
    differenceImage = imabsdiff(fixedImage, alignedImage);

    % Check if the difference image is RGB or grayscale
    if size(differenceImage, 3) == 3
        grayDiff = rgb2gray(differenceImage); % Convert to grayscale if RGB
    else
        grayDiff = differenceImage; % Use directly if already grayscale
    end

    % Enhance contrast for the difference image
    contrastEnhancedImage = imadjust(grayDiff);

    % Create a binary mask of significant differences
    threshold = 50; % Adjust this value as needed
    binaryMask = contrastEnhancedImage > threshold;

    % Display the binary mask
    figure;
    imshow(binaryMask);
    title('Binary Mask of Significant Differences');

    % Amplify the difference image
    amplifiedDiff = uint8(3 * double(differenceImage));  % Scale difference
    amplifiedDiff(amplifiedDiff > 255) = 255;  % Clip values > 255
    amplifiedDiff = uint8(amplifiedDiff);

    % Display the amplified difference image
    figure;
    imshow(amplifiedDiff);
    title('Amplified Difference Image');

    % Highlight differences in the fixed image
    highlight = fixedImage;

    % Ensure highlight is RGB before accessing channels
    if size(highlight, 3) == 3
        highlight(:,:,1) = min(highlight(:,:,1) + uint8(binaryMask * 100), 255); % Add red where different
        highlight(:,:,2) = highlight(:,:,2); % Keep green channel unchanged
        highlight(:,:,3) = highlight(:,:,3); % Keep blue channel unchanged
    else
        % If the image is grayscale, you can create a colored highlight
        highlight = cat(3, highlight, highlight, highlight); % Convert to RGB
        highlight(:,:,1) = min(highlight(:,:,1) + uint8(binaryMask * 100), 255); % Add red where different
    end

    figure;
    imshow(highlight);
    title('Differences Highlighted in Red');
end


