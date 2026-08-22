function cutoff_array = get_cutoff_ratios(r, p)
% Load rho values
rho_values = r(:); % Ensure it's a column vector

% Parameters
n_components = p.n_colors;        % Number of Gaussian components
specificity = p.specificity;                % Specificity threshold (e.g., 60%)
x_range = linspace(min(rho_values), max(rho_values), 1000); % Evaluation grid

% Fit Gaussian Mixture Model (GMM)
gmm = fitgmdist(rho_values, n_components, 'RegularizationValue', 1e-5);

% Evaluate each component's PDF over x_range
pdf_all = zeros(n_components, length(x_range));
for k = 1:n_components
    pdf_all(k, :) = gmm.ComponentProportion(k) * normpdf(x_range, ...
        gmm.mu(k), sqrt(squeeze(gmm.Sigma(:, :, k))));
end

% Compute total PDF and posterior probabilities
pdf_total = sum(pdf_all, 1);
posteriors = pdf_all ./ pdf_total; % Each row is P(component=k | rho)

% Initialize cutoffs structure
cutoffs = struct();
figure; hold on;

% Plot histogram
histogram(rho_values, 100, 'Normalization', 'pdf', 'FaceAlpha', 0.3);

% Plot component Gaussians and find cutoffs
colors = lines(n_components);
for k = 1:n_components
    % Plot component
    plot(x_range, pdf_all(k, :), 'LineWidth', 2, 'Color', colors(k,:));
    
    % Find boundaries where P(k) crosses specificity threshold
    Pk = posteriors(k, :);
    above_spec = find(Pk >= specificity);
    
    if ~isempty(above_spec)
        lower_idx = above_spec(1);
        upper_idx = above_spec(end);
        cutoffs(k).lower = x_range(lower_idx);
        cutoffs(k).upper = x_range(upper_idx);
        
        % Plot vertical lines
        xline(cutoffs(k).lower, '--', sprintf('Spec %.2f low (k=%d)', specificity, k));
        xline(cutoffs(k).upper, '--', sprintf('Spec %.2f high (k=%d)', specificity, k));
    else
        cutoffs(k).lower = NaN;
        cutoffs(k).upper = NaN;
    end
end

% Final plot settings
title(sprintf('GMM Fit with %d Gaussians and %.0f%% Specificity', n_components, specificity*100));
xlabel('rho (locs.ratio)');
ylabel('Probability Density');
legend('Histogram', 'Gaussian Components');
hold off;

% Print cutoff summary
fprintf('Classification cutoffs per component (specificity = %.2f):\n', specificity);
for k = 1:n_components
    fprintf('Component %d: Lower = %.4f, Upper = %.4f\n', ...
        k, cutoffs(k).lower, cutoffs(k).upper);
end


% reformat struct to array
% Initialize cutoff array
cutoff_array = nan(numel(cutoffs), 2);

% Fill with lower and upper bounds from the struct
for k = 1:numel(cutoffs)
    cutoff_array(k, :) = [cutoffs(k).lower, cutoffs(k).upper];
end

% Sort based on the lower boundary
[~, sort_idx] = sort(cutoff_array(:,1), 'ascend', 'MissingPlacement', 'last');
cutoff_array = cutoff_array(sort_idx, :);

end
