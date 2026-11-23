function hexDigest = sha256_file(filePath)
%SHA256_FILE Return a lowercase SHA-256 digest for one file.

arguments
    filePath (1,1) string
end

fileId = fopen(filePath, 'r');
if fileId < 0
    error('EEG:HashOpenFailed', 'Cannot open file for hashing: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));

digest = java.security.MessageDigest.getInstance('SHA-256');
while true
    bytes = fread(fileId, 1024 * 1024, '*uint8');
    if isempty(bytes)
        break;
    end
    digest.update(bytes);
end

digestBytes = typecast(digest.digest(), 'uint8');
hexDigest = string(lower(reshape(dec2hex(digestBytes, 2).', 1, [])));
end

