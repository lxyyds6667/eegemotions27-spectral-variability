function results = run_tests()
%RUN_TESTS Run all automated checks for this repository.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

results = runtests(fullfile(projectRoot, 'tests'), 'IncludeSubfolders', true);
disp(table(results));

if any([results.Failed])
    error('EEG:TestsFailed', '%d MATLAB tests failed.', sum([results.Failed]));
end
end

