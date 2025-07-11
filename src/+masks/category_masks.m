function [mask, rgbMaskedImage] = category_masks(image, category)
    % category_masks - Returns and plots mask + RGB overlay for a category
    %
    % Usage:
    %   [mask, rgbMasked] = category_masks(image, 'forest');

    hsvImg = rgb2hsv(image);
    H = hsvImg(:, :, 1); S = hsvImg(:, :, 2); V = hsvImg(:, :, 3);
    backgroundMask = V < 0.05;

    % HSV thresholds per category
    categories = struct( ...
        'water', struct('h', [0.55, 0.75], 's', [0.3, 1.0], 'v', [0.2, 1.0]), ...
        'forest', struct('h', [0.25, 0.45], 's', [0.3, 1.0], 'v', [0.2, 1.0]), ...
        'river', struct('h', [0.25, 0.50], 's', [0.2, 0.7], 'v', [0.2, 0.6]), ...
        'glacier', struct('h', [0.0, 1.0], 's', [0.0, 0.3], 'v', [0.7, 1.0]), ...
        'ice', struct('h', [0.0, 1.0], 's', [0.0, 0.1], 'v', [0.85, 1.0]), ...
        'city', struct('h', [0.0, 0.12], 's', [0.05, 0.5], 'v', [0.2, 0.9]), ...
        'field', struct('h', [0.10, 0.25], 's', [0.2, 0.9], 'v', [0.3, 0.9]), ...
        'desert', struct('h', [0.07, 0.17], 's', [0.1, 0.6], 'v', [0.5, 1.0]), ...
        'frauenkirche', struct('h', [0.00, 0.08], 's', [0.2, 0.5], 'v', [0.3, 0.7]), ...
        'oktoberfest', struct('h', [0.00, 1.00], 's', [0.00, 0.25], 'v', [0.85, 1.00]) ...
    );

    if ~isfield(categories, category)
        error('Invalid category: %s', category);
    end

    % Apply HSV mask
    r = categories.(category);
    mask = (H >= r.h(1) & H <= r.h(2)) & ...
        (S >= r.s(1) & S <= r.s(2)) & ...
        (V >= r.v(1) & V <= r.v(2)) & ...
        ~backgroundMask;

    % Add entropy filtering for 'city' to remove desert-like misclassification
    if strcmp(category, 'city')
        gray = rgb2gray(image);
        texture = entropyfilt(gray, true(9)); % 9x9 neighborhood
        texture = mat2gray(texture); % normalize to 0-1
        entropyMask = texture > 0.4; % threshold
        mask = mask & entropyMask;
    end

    % Remove small noise
    mask = bwareaopen(mask, 50);

    % Generate RGB-masked image (preserve color only inside mask)
    rgbMaskedImage = image;

    for c = 1:3
        channel = rgbMaskedImage(:, :, c);
        channel(~mask) = 0;
        rgbMaskedImage(:, :, c) = channel;
    end

    % Plot original, binary mask, and RGB-masked image
    % figure('Name', ['Category: ', category]);
    % subplot(1, 3, 1); imshow(image); title('Original Image', 'FontWeight', 'bold');
    % subplot(1, 3, 2); imshow(mask); title(['Binary Mask: ', category], 'FontWeight', 'bold');
    % subplot(1, 3, 3); imshow(rgbMaskedImage); title('RGB Masked Output', 'FontWeight', 'bold');
end
