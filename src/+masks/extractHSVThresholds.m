function adaptiveThresholds = extractHSVThresholds(image, masks)
%EXTRACTHSVTHRESHOLDS Extracts min/max HSV thresholds per class from masks
%   image  - RGB input image
%   masks  - struct with binary masks per category (from classifyImageByColor)
%   Returns: struct with adaptive HSV thresholds per class

    hsvImg = rgb2hsv(image);
    H = hsvImg(:,:,1);
    S = hsvImg(:,:,2);
    V = hsvImg(:,:,3);

    classNames = fieldnames(masks);
    adaptiveThresholds = struct();

    for i = 1:numel(classNames)
        class = classNames{i};
        mask = masks.(class);

        hVals = H(mask); sVals = S(mask); vVals = V(mask);

        if ~isempty(hVals)
            adaptiveThresholds.(class) = struct( ...
                'h', [min(hVals), max(hVals)], ...
                's', [min(sVals), max(sVals)], ...
                'v', [min(vVals), max(vVals)] ...
            );
        end
    end
end