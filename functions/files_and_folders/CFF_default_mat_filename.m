%% this_function_name.m
%
% returns a default .mat file name for a file to be converted, by replacing
% extension period with underscore, and adding .mat extension.
% For example: 'C:\DATA\myfile.all' -> 'C:\DATA\myfile_all.mat'
%
%% Help
%
% *USE*
%
% TODO: write longer description of function
%
% *INPUT VARIABLES*
%
% * |input_variable_1|: TODO: write description and info on variable
%
% *OUTPUT VARIABLES*
%
% * |output_variable_1|: TODO: write description and info on variable
%
% *RESEARCH NOTES*
%
% TODO: write research notes
%
% *NEW FEATURES*
%
% * YYYY-MM-DD: first version (Author). TODO: complete date and comment
%
% *EXAMPLE*
%
% TODO: write examples
%
% *AUTHOR, AFFILIATION & COPYRIGHT*
%
% Alexandre Schimel, NIWA.

%% Function
function mat_files = CFF_default_mat_filename(files)

if ischar(files)
    
    [p,n,e] = fileparts(files);
    mat_files = [p filesep n  '_' e(2:end) '.mat'];
    
elseif iscell(files)
    
    for ii=1:length(files)
        [p,n,e] = fileparts(files{ii});
        mat_files{ii} = [p filesep n  '_' e(2:end) '.mat'];
    end
    
end