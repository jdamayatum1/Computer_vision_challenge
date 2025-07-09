function flicker_visualization(app)
    % Get indices for selected images
    idx1 = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));
    idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

    % Validate indices
    if isempty(idx1) || isempty(idx2)
        return;
    end

    % Retrieve registered images
    img1 = app.RegisteredImages{idx1};
    img2reg = app.RegisteredImages{idx2};

    % Convert grayscale to RGB if needed
    if size(img1, 3) == 1
        img1 = repmat(img1, [1 1 3]);
    end

    if size(img2reg, 3) == 1
        img2reg = repmat(img2reg, [1 1 3]);
    end

    % Flicker display
    if app.FlickerState
        imshow(img1, 'Parent', app.ResultAxes);
        axis(app.ResultAxes, 'image');
        axis(app.ResultAxes, 'off');
        name1 = strrep(app.ImageFiles(idx1).name, '_', ' ');
        title(app.ResultAxes, sprintf('Flicker: %s', name1));
    else
        imshow(img2reg, 'Parent', app.ResultAxes);
        axis(app.ResultAxes, 'image');
        axis(app.ResultAxes, 'off');
        name2 = strrep(app.ImageFiles(idx2).name, '_', ' ');
        title(app.ResultAxes, sprintf('Flicker: %s (registered)', name2));
    end

    % Toggle flicker state
    app.FlickerState = ~app.FlickerState;
end
