function results = run_all()
%RUN_ALL Rebuild the whole-trial baseline and its two sensitivity analyses.
% The two paired follow-ups use the artifacts produced by this first stage.

results = struct();
results.tests = run_tests();
[results.fileAudit, results.trialManifest, results.auditSummary] = ...
    run_data_audit();
[results.featureTable, results.featureNames] = run_feature_extraction();
results.modeling = run_modeling();
results.samplingRateSensitivity = run_sampling_rate_sensitivity();
results.durationExclusionSensitivity = run_duration_exclusion_sensitivity();
results.verification = verify_results();
end

