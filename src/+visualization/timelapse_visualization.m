function timelapse_visualization(app)

    if isempty(app.TimelapseFrames)
        return;
    end

    if app.TimelapseFrameIndex > numel(app.TimelapseFrames)
        app.TimelapseFrameIndex = 1; % Loop back to start
    end

    % Display current frame
    img = app.TimelapseFrames{app.TimelapseFrameIndex};

    % Convert grayscale to RGB if needed
    if size(img, 3) == 1
        img = repmat(img, [1 1 3]);
    end

    imshow(img, 'Parent', app.ResultAxes);
    axis(app.ResultAxes, 'image');
    axis(app.ResultAxes, 'off');

    % Generate cleaned name for title (using ImageFiles since TimelapseFrames are from registered images)
    currentIdx = app.TimelapseFrameIndex;

    if currentIdx <= numel(app.ImageFiles)
        frameName = strrep(app.ImageFiles(currentIdx).name, '_', ' ');
    else
        frameName = '';
    end

    % Set title with frame index and name
    title(app.ResultAxes, sprintf('Timelapse Frame %d / %d: %s', ...
        app.TimelapseFrameIndex, numel(app.TimelapseFrames), frameName));

    % Increment for next call
    app.TimelapseFrameIndex = app.TimelapseFrameIndex + 1;
end
