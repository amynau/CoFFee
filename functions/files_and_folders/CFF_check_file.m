%% CFF_check_file.m
%
% check if file(s) exist and returns the absolute path of the input file(s)
% (with correct filesep), or prompt for valid file(s) as close as
% possible to the (invalid) input file(s)
%
%% Help
%
% *USE*
%
% TODO: write longer description of function
%
% *INPUT VARIABLES*
%
% * |in_file|: TODO: write description and info on variable
%
% *OUTPUT VARIABLES*
%
% * |out_file|: TODO: write description and info on variable
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
function [out_file] = CFF_check_file(in_file)

% first off, replace wrong fileseps if any
file = CFF_correct_filesep(in_file);

% then, test for the number of files in input
if ischar(in_file)
    % if only one...

    % test if file exists
    if exist(file,'file')
        % if it does...
        
        % just return input file, with its full path
        out_file = CFF_full_path(file);
        
    else
        % if it doesn't...
        
        % get closest existing folder
        folder = CFF_closest_existing_folder(file);
        
        % prompt for one file in the closest existing folder
        txt = ['The file ''' file ''' does not exist. Please select a valid file'];
        FilterSpec = [folder filesep '*.*'];
        [FileName,PathName] = uigetfile(FilterSpec,txt,'MultiSelect','off');
        
        % output file with path
        out_file = fullfile(PathName,FileName);
        
    end
    
elseif iscell(file)
    % if several files in input
    
    % test if all files exist
    flag = cellfun( @(x)exist(x,'file')==0, file);
    X = sum(flag);
    
    if X==0
        % if they all exist, just return input file list (with full path)
        out_file = cellfun(@CFF_full_path,file,'UniformOutput',0);
        
    else
        % if at least one does not exist, prompt for all files to be selected
        % using input number as guess
        
        % get closest existing folder
        folder = CFF_closest_existing_folder(file{1});

        % prompt for files in the closest existing folder
        n_files = length(file);
        txt = sprintf('%i out of %i files do not exist. Please select valid files.', X, n_files);
        FilterSpec = [folder filesep '*.*'];
        [FileName,PathName] = uigetfile(FilterSpec,txt,'MultiSelect','on');
        
        % return with full path
        out_file = cell(size(file));
        for ii = 1:length(out_file)
            out_file{ii} = fullfile(PathName,FileName{ii});
        end

    end
    
end
    
