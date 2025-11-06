function iFS_aseg_process(iFS_dir, out)

% Processes Infant FreeSurfer aseg.mgz for compatibility with standard FreeSurfer
% This function replaces the iBEAT2 integration step in the original pipeline
%
% Main adjustments:
%   - Copies iFS aseg to FreeSurfer directory as aseg.presurf
%   - Adjusts thalamus labels from iFS convention to FS convention
%     (iFS: 9=left thalamus, 48=right thalamus)
%     (FS:  10=left thalamus, 49=right thalamus)
%
% For questions: theodore_turesky@gse.harvard.edu
% Modified for iFS-only pipeline


% Build file paths
aseg_in = fullfile(iFS_dir, 'mri', 'aseg.mgz');
aseg_pre = fullfile(out, 'aseg.presurf');
aseg_nii = [aseg_pre '.nii'];

% Check if iFS aseg exists
if ~exist(aseg_in, 'file')
    error('Infant FreeSurfer aseg.mgz not found at: %s', aseg_in);
end

% Convert iFS aseg to nifti for processing
fprintf('Converting iFS aseg to NIfTI format...\n');
cmd = ['mri_convert -i ' aseg_in ' -o ' aseg_nii];
system(cmd);

% Load segmentation data
asegd = niftiread(aseg_nii);
asegi = niftiinfo(aseg_nii); % for header info
asegi.Datatype = 'single';

% Adjust thalamus labels to match FreeSurfer convention
% iFS uses labels 9 and 48 for thalamus
% Standard FS uses labels 10 and 49 for thalamus
fprintf('Adjusting thalamus labels (9->10, 48->49)...\n');
asegd = single(asegd);
asegd(asegd == 9) = 10;   % Left thalamus
asegd(asegd == 48) = 49;  % Right thalamus

% Save processed aseg
fprintf('Saving processed aseg...\n');
niftiwrite(asegd, aseg_nii, asegi);

% Convert back to MGZ format
cmd = ['mri_convert -i ' aseg_nii ' -o ' aseg_pre '.mgz'];
system(cmd);

fprintf('iFS aseg processing complete.\n');
fprintf('Output: %s.mgz\n', aseg_pre);
