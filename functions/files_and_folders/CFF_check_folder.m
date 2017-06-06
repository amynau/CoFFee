%% CFF_check_folder.m
%
% check if folder exists and returns the absolute path of the input folder
% (with correct filesep), or prompt for a valid input folder as close as
% possible to the (invalid) input folder
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
% * 2017-06-06: first version (Alex Schimel)
%
% *EXAMPLE*
%
% TODO: write examples
%
% *AUTHOR, AFFILIATION & COPYRIGHT*
%
% Alexandre Schimel, NIWA.

%% Function
function [out_folder] = CFF_check_folder(in_folder)

% first off, replace wrong fileseps if any
folder = CFF_correct_filesep(in_folder);

% then test if folder exists
if exist(folder,'dir')
    
    % folder exists, return its full path
    out_folder = CFF_full_path(folder);
    
else
    % folder doesn't exist
    
    % check input path to find the closest existing folder in the input
    % path (or pwd if there none valid)
    folder = CFF_closest_existing_folder(folder);
    
    % prompt for an existing folder
    txt = ['The folder ''' in_folder ''' does not exist. Please select a valid folder.'];
    out_folder = uigetdir(folder,txt);
    
end



