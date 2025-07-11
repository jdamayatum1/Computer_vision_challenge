function stats = calculateStats(ref_img, img, mask_ref_img, mask_img, mask_diff, category)
    % Calculate statistics for change detection analysis
    %
    % Inputs:
    %   ref_img - Reference image (grayscale or RGB)
    %   img - Comparison image (grayscale or RGB)
    %   mask_ref_img - Mask for reference image
    %   mask_img - Mask for comparison image
    %   mask_diff - Mask for difference/change areas
    %
    % Outputs:
    %   stats - Statistics struct with various metrics

    % Initialize stats structure
    stats = struct();

    stats.img_mask = mask_img;
    stats.img_ref_mask = mask_ref_img;
    stats.img_united_mask = mask_img | mask_ref_img;
    stats.diff_mask = mask_diff;

    stats.category = category;

    % Basic image information
    stats.image_size = size(ref_img);
    stats.total_pixels = numel(mask_ref_img);

    % Mask statistics
    stats.mask_ref_pixels = sum(mask_ref_img(:));
    stats.mask_img_pixels = sum(mask_img(:));
    stats.mask_diff_pixels = sum(mask_diff(:));

    % Coverage percentages
    stats.mask_ref_coverage = (stats.mask_ref_pixels / stats.total_pixels);
    stats.mask_img_coverage = (stats.mask_img_pixels / stats.total_pixels);
    stats.mask_diff_coverage = (stats.mask_diff_pixels / stats.total_pixels);

    % Growth rate
    ref_gray = rgb2gray(ref_img);
    img_gray = rgb2gray(img);
    black_mask = img_gray == 0;
    ref_img_blacked = mask_ref_img & ~black_mask;
    px_ref_mask_blacked = sum(ref_img_blacked(:));
    % fprintf('--------------------------------\n');
    % fprintf('black_mask: %d\n', sum(black_mask(:)));
    % fprintf('stats.mask_img_pixels: %d\n', stats.mask_img_pixels);
    % fprintf('stats.mask_ref_pixels: %d\n', stats.mask_ref_pixels);
    % fprintf('px_ref_mask_blacked: %d\n', px_ref_mask_blacked);
    % fprintf('stats.mask_img_pixels: %d\n', stats.mask_img_pixels);
    stats.mask_growth_rate = (stats.mask_img_pixels - px_ref_mask_blacked) / (px_ref_mask_blacked + 1);
    % fprintf('Mask growth rate: %.1f%%\n', stats.mask_growth_rate * 100);

    % diff_img = double(ref_gray(stats.img_united_mask)) - double(img_gray(stats.img_united_mask));
    % stats.change_mean = mean(diff_img);
    % stats.change_std = std(diff_img);
    % stats.change_max = max(diff_img);
    % stats.change_min = min(diff_img);

    % stats.stats_text_cell = formatStatsForDisplay(stats);

    fprintf('Statistics calculated successfully.\n');
end

%% Display Formatting Functions

function formatted_text = formatStatsForDisplay(stats)
    % Format statistics for display in the GUI stats text area
    %
    % Inputs:
    %   stats - Statistics struct from overlay computation
    %
    % Outputs:
    %   formatted_text - Cell array of strings for display in text area

    formatted_text = {};

    % Check if stats is empty or invalid
    if isempty(stats) || ~isstruct(stats)
        formatted_text{1} = 'No statistics available';
        return;
    end

    % Coverage values in percent
    if isfield(stats, 'mask_ref_coverage') && isfield(stats, 'mask_img_coverage')
        formatted_text{end + 1} = sprintf('Ref Coverage: %.1f%%', stats.mask_ref_coverage * 100);
        formatted_text{end + 1} = sprintf('Img Coverage: %.1f%%', stats.mask_img_coverage * 100);
    end

    % Rate values for current mask in percent (e.g., "Forest change: 10%")
    if isfield(stats, 'mask_growth_rate')
        % Handle capitalization safely
        if isempty(stats.category)
            mask_display_name = 'Unknown';
        elseif length(stats.category) == 1
            mask_display_name = upper(stats.category);
        else
            mask_display_name = [upper(stats.category(1)), lower(stats.category(2:end))];
        end

        formatted_text{end + 1} = sprintf('%s change: %.1f%%', mask_display_name, stats.mask_growth_rate * 100);
    end

    % Change detection metrics (mean, std, max, min in percent)
    if isfield(stats, 'change_mean') && isfield(stats, 'change_std') && ...
            isfield(stats, 'change_max') && isfield(stats, 'change_min')
        formatted_text{end + 1} = sprintf('Mean: %.1f', stats.change_mean);
        formatted_text{end + 1} = sprintf('Std: %.1f', stats.change_std);
        formatted_text{end + 1} = sprintf('Max: %.1f', stats.change_max);
        formatted_text{end + 1} = sprintf('Min: %.1f', stats.change_min);
    end

    % If no valid statistics were found
    if isempty(formatted_text)
        formatted_text{1} = 'No valid statistics found';
    end

end
