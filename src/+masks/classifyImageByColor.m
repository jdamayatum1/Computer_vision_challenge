function [dominantCategory, scores, dominantMask, masks] = classifyImageByColor(image)
    % Robust HSV-based classifier for RGB satellite images

    %     % Parameters
    %     waterThreshold = 0.50;
    %     minCategoryFraction = 0.01;  % 1% minimum size
    %     dominanceRatio = 1.2;        % must be 20% stronger than next best
    %
    %     hsvImg = rgb2hsv(image);
    %     H = hsvImg(:,:,1); S = hsvImg(:,:,2); V = hsvImg(:,:,3);
    %
    %     % Slightly more tolerant: allow more shadows
    %     backgroundMask = V < 0.03;
    %
    %     % Broader city range and adjusted categories
    %     categories = struct( ...
    %         'water',   struct('h',[0.55,0.75], 's',[0.2,1.0],  'v',[0.2,1.0]), ...
    %         'forest',  struct('h',[0.25,0.45], 's',[0.2,1.0],  'v',[0.2,1.0]), ...
    %         'glacier', struct('h',[0.50,0.70], 's',[0.0,0.4],  'v',[0.6,1.0]), ...
    %         'ice',     struct('h',[0.0,1.0],   's',[0.0,0.1],  'v',[0.85,1.0]), ...
    %         'city', struct('h',[0.0, 0.08], 's',[0.05, 0.20], 'v',[0.35, 0.75]), ...
    %         'field',    struct('h',[0.10,0.25], 's',[0.2,0.9],  'v',[0.3,0.9]), ...
    %         'desert',  struct('h',[0.10,0.18], 's',[0.3,0.8],  'v',[0.6,1.0]) ...
    %     );
    %
    %
    %     categoryNames = fieldnames(categories);
    %     scores = struct();
    %     masks = struct();
    %     totalPixels = sum(~backgroundMask(:));  % only consider valid area
    %
    %     for i = 1:numel(categoryNames)
    %         cat = categoryNames{i};
    %         r = categories.(cat);
    %
    %         mask = (H >= r.h(1) & H <= r.h(2)) & ...
    %                (S >= r.s(1) & S <= r.s(2)) & ...
    %                (V >= r.v(1) & V <= r.v(2)) & ...
    %                ~backgroundMask;
    %         if strcmp(cat, 'city')
    %             gray = rgb2gray(image);
    %             texture = entropyfilt(gray, true(9)); % larger neighborhood
    %             texture = mat2gray(texture);
    %             mask = mask & texture > 0.4;  % increase or decrease threshold
    %         end
    %
    %         mask = bwareaopen(mask, 50);  % Remove small specks
    %
    %         scores.(cat) = sum(mask(:));
    %         masks.(cat) = mask;
    %     end
    %
    %     pixelCounts = struct2array(scores);
    %     [sortedVals, idx] = sort(pixelCounts, 'descend');
    %     sortedCategories = categoryNames(idx);
    %
    %     % Check if the top category is dominant
    %     if sortedVals(1) / totalPixels < minCategoryFraction || ...
    %        sortedVals(1) < dominanceRatio * sortedVals(2)
    %         dominantCategory = 'uncertain';
    %         masks.uncertain = false(size(H));
    %         if numel(sortedCategories) >= 3
    %             masks.uncertain = masks.(sortedCategories{1}) | ...
    %                               masks.(sortedCategories{2}) | ...
    %                               masks.(sortedCategories{3});
    %         end
    %         dominantMask = masks.uncertain;
    %         return;
    %     end
    %
    %     % Special logic for water (avoid misclassification)
    %     fprintf("Water coverage: %.2f%%\n", 100 * scores.water / totalPixels);
    %     dominantCategory = sortedCategories{1};
    %     if strcmp(dominantCategory, 'water') && scores.water / totalPixels < waterThreshold
    %         dominantCategory = sortedCategories{2};
    %     end
    %
    %     dominantMask = masks.(dominantCategory);
    %     disp(scores);
    %
    %     % Optional visualization (uncomment if needed)
    % %     showMasks = true;
    % %     if showMasks
    % %         nonEmptyCategories = categoryNames(struct2array(scores) > 0);
    % %         numValid = numel(nonEmptyCategories);
    % %         figure('Name', 'Non-Empty Category Masks');
    % %         for i = 1:numValid
    % %             cname = nonEmptyCategories{i};
    % %             subplot(ceil(sqrt(numValid)), ceil(sqrt(numValid)), i);
    % %             imshow(masks.(cname));
    % %             title(cname);
    % %         end
    % %     end
    % Robust HSV-based classifier for RGB satellite images

    % Parameters
    waterThreshold = 0.50;
    minCategoryFraction = 0.05; % 1 % minimum size
    dominanceRatio = 1.5; % must be 20 % stronger than next best

    hsvImg = rgb2hsv(image);
    H = hsvImg(:, :, 1); S = hsvImg(:, :, 2); V = hsvImg(:, :, 3);

    % Ignore dark areas (e.g. oceans, shadows)
    backgroundMask = V < 0.05;

    % Main HSV color ranges
    categories = struct( ...
        'water', struct('h', [0.55, 0.75], 's', [0.2, 1.0], 'v', [0.2, 1.0]), ...
        'forest', struct('h', [0.25, 0.45], 's', [0.2, 1.0], 'v', [0.2, 1.0]), ...
        'glacier', struct('h', [0.50, 0.70], 's', [0.0, 0.4], 'v', [0.6, 1.0]), ...
        'ice', struct('h', [0.0, 1.0], 's', [0.0, 0.1], 'v', [0.85, 1.0]), ...
        'city', struct('h', [0.0, 0.12], 's', [0.07, 0.30], 'v', [0.35, 0.8]), ...
        'field', struct('h', [0.10, 0.25], 's', [0.2, 0.9], 'v', [0.3, 0.9]), ...
        'desert', struct('h', [0.08, 0.18], 's', [0.2, 0.8], 'v', [0.5, 1.0]) ...
    );

    categoryNames = fieldnames(categories);
    scores = struct();
    masks = struct();
    totalPixels = sum(~backgroundMask(:)); % only consider valid area

    for i = 1:numel(categoryNames)
        cat = categoryNames{i};
        r = categories.(cat);

        mask = (H >= r.h(1) & H <= r.h(2)) & ...
            (S >= r.s(1) & S <= r.s(2)) & ...
            (V >= r.v(1) & V <= r.v(2)) & ...
            ~backgroundMask;

        mask = bwareaopen(mask, 50); % Remove small specks

        scores.(cat) = sum(mask(:));
        masks.(cat) = mask;
    end

    pixelCounts = struct2array(scores);
    [sortedVals, idx] = sort(pixelCounts, 'descend');
    sortedCategories = categoryNames(idx);

    % Check if top category is strong enough
    if sortedVals(1) / totalPixels < minCategoryFraction || ...
            sortedVals(1) < dominanceRatio * sortedVals(2)
        dominantCategory = 'uncertain';
        dominantMask = false(size(H));
        return;
    end

    % Special rule: water must be ≥50% to count as dominant
    fprintf("Water coverage: %.2f%%\n", 100 * scores.water / totalPixels);
    dominantCategory = sortedCategories{1};

    if strcmp(dominantCategory, 'water') && scores.water / totalPixels < waterThreshold
        dominantCategory = sortedCategories{2};
    end

    % Output final dominant mask
    dominantMask = masks.(dominantCategory);
    disp(scores);

end
