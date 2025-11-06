function aseg2wm_iFS(aseg)

% Converts aseg.presurf to wm.mgz for FreeSurfer processing
% Modified for iFS-only pipeline (without iBEAT2 integration)
%
% This function generates the white matter file needed by FreeSurfer
% using only the Infant FreeSurfer segmentation labels
%
% For questions: theodore_turesky@gse.harvard.edu

% White matter labels: left/right cortical WM, brainstem, vermis
wm_labs = [2 41 173 174 175];

% Gray matter labels: subcortical structures and lateral ventricles
% Note: Following Natu et al. (2021), thalamus labels 10 and 49 are NOT included
gm_labs = [4 11 12 13 26 28 43 50 51 52 58 60];


% Build output file paths
[p, ~, ~] = fileparts(aseg);
asegd = niftiread(aseg);
wmi = niftiinfo(aseg); % for header info
wm_pre = [p '/wm'];
wm_nii = [wm_pre '.nii'];
wmi.Filename = wm_nii;

% Initialize white matter volume
wmd = single(zeros(size(asegd)));

% Relabel white matter voxels to 110
for i = wm_labs
    wmd(asegd == i) = 110;
end

% Relabel gray matter voxels to 250
for i = gm_labs
    wmd(asegd == i) = 250;
end

% Save white matter file
fprintf('Saving white matter file...\n');
niftiwrite(wmd, wm_nii, wmi);

% Convert to MGZ format
cmd = ['mri_convert -i ' wm_nii ' -o ' wm_pre '.mgz'];
system(cmd);

fprintf('White matter file generation complete.\n');
fprintf('Output: %s.mgz\n', wm_pre);
