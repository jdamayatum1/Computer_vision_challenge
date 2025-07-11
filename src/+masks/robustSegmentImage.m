function [segmentationRGB, validMasks, adaptiveHSV] = robustSegmentImage(image)
    %ROBUSTSEGMENTIMAGE Segments an RGB image using HSV classification with fallback to K-means.
    % Returns:
    %   segmentationRGB - color-coded segmentation image
    %   validMasks      - struct of binary masks (only for dominant classes)
    %   adaptiveHSV     - struct of HSV thresholds used

    minCoverage = 0.05; % Only keep classes with >5 % of pixels

    % Step 1: classify and get all masks
    [dominantCategory, scores, ~, masks] = classifyImageByColor(image);

    % Step 2: filter masks by coverage
    totalPixels = numel(image(:, :, 1));
    validMasks = struct();
    validScores = struct();
    categories = fieldnames(masks);

    for i = 1:numel(categories)
        cat = categories{i};

        if isfield(scores, cat)
            fraction = scores.(cat) / totalPixels;

            if fraction > minCoverage
                validMasks.(cat) = masks.(cat);
                validScores.(cat) = scores.(cat);
            end

        end

    end

    % Fallback: nothing valid or uncertain → switch to K-means
    if isempty(fieldnames(validMasks)) || strcmp(dominantCategory, 'uncertain')
        warning('No valid HSV classes or uncertain classification. Falling back to K-means.');
        [segmentationRGB, dominantMask, maskedRGB] = segmentImageByKMeans(image);
        adaptiveHSV = struct();
        return;
    end

    % Step 3: build color-coded segmentation from HSV masks
    segmentationRGB = zeros(size(image), 'uint8');
    classColors = struct( ...
        'water', [0, 0, 255], ...
        'forest', [0, 255, 0], ...
        'glacier', [0, 255, 255], ...
        'ice', [255, 255, 255], ...
        'city', [128, 128, 128], ...
        'field', [153, 255, 51], ...
        'desert', [255, 204, 102]);

    categoryNames = fieldnames(validMasks);

    for i = 1:numel(categoryNames)
        cname = categoryNames{i};

        if isfield(classColors, cname)
            mask = validMasks.(cname);
            color = classColors.(cname);

            for c = 1:3
                segmentationRGB(:, :, c) = segmentationRGB(:, :, c) + uint8(mask) * color(c);
            end

        end

    end

    % Step 4: Dominant class and mask
    pixelCounts = struct2array(validScores);
    [~, idx] = max(pixelCounts);
    dominantClass = categoryNames{idx};
    dominantMask = validMasks.(dominantClass);

    % Step 5: Masked RGB
    maskedRGB = image;
    maskedRGB(repmat(~dominantMask, [1 1 3])) = 0;

    % Step 6: Extract adaptive HSV thresholds
    adaptiveHSV = extractHSVThresholds(image, validMasks);

    % Step 7: Display results
    figure;
    subplot(2, 2, 1); imshow(image); title('Original Image');
    subplot(2, 2, 2); imshow(segmentationRGB); title('HSV Segmentation');
    subplot(2, 2, 3); imshow(dominantMask); title(['Binary Mask: ' dominantClass]);
    subplot(2, 2, 4); imshow(maskedRGB); title('Masked RGB Dominant Region');
end
