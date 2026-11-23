# Data directory

The EEGEmotions-27 recordings are not committed to this repository.

Place the official public text files under:

```text
data/raw/EEGEmotions-27/eeg_raw/
```

Keep the original file names. The analysis records the upstream URL, Git revision and individual SHA-256 hashes. Use the sparse-checkout commands in the [project README](../README.md#reproduce) to obtain the release.

The checked upstream commit `0dfec14d177ed73c37a95f06d942e9b58e2bbf77` contains 2,343 tab-delimited TXT files. The [file-level audit](../outputs/audit/data_audit.csv) records their shape, numeric checks and disposition. The 2,335 primary trials have 14 numeric columns, one row per time sample and variable row counts.

Documented or directly inspected properties are:

- the upstream README states 256 samples/second, while the released row-count and bandwidth clusters support participant-level 128/256 Hz groups; see [`../DATA_AUDIT.md`](../DATA_AUDIT.md);
- 14 channels;
- time samples in rows and channels in the documented order;
- filenames encoding participant and target-condition identifiers;
- participant metadata contains 88 IDs spanning 1--90, with IDs 26 and 48 absent.

Signal units and the precise filtering/reference/ICA history remain unknown. These are deliberately not guessed. If the full audit contradicts the sampled format, update the parser/config and document the evidence.

The small upstream files `participants_info.csv`, `emotivX_channels_location.ced`, and `readme.md` should remain beside `eeg_raw/`. The stimulus videos and the authors' extracted feature table are not required for this baseline. Record the exact upstream commit SHA and download date. The official dataset is licensed CC BY-NC 4.0; retain attribution and do not redistribute the recordings from this repository.

