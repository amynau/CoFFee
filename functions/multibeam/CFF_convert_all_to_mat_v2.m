function [ALLfileinfo] = CFF_convert_all_to_mat_v2(ALLfilename, varargin)
% [ALLfileinfo] = CFF_convert_all_to_mat_v2(ALLfilename, varargin)
%
% DESCRIPTION
%
% Converts Kongsberg EM series binary .all or .wcd data files (ALL) to a
% Matlab format (MAT), conserving all information from the original as it
% is.
%
% USE
%
% 
%
% PROCESSING SUMMARY
% 
% 
%
% REQUIRED INPUT ARGUMENTS
% - 'ALLfilename': string filename to parse (extension in .all or .wcd)
%
% OPTIONAL INPUT ARGUMENTS
% - 'MATfilename': string filename to output. If not provided (default),
% the MAT file is saved in same folder as input file and bears the same
% name except for its extension changed to '.mat'. 
%
% OUTPUT VARIABLES
%
% - ALLfileinfo (optional): structure for description of the datagrams in
% input file. Fields are: 
%   * ALLfilename: input file name
%   * filesize: file size in bytes
%   * datagsizeformat: endianness of the datagram size field 'b' or 'l'
%   * datagramsformat: endianness of the datagrams 'b' or 'l'
%   * datagNumberInFile: 
%   * datagTypeNumber: for each datagram, SIMRAD datagram type in decimal
%   * datagTypeText: for each datagram, SIMRAD datagram type description
%   * parsed: for each datagram, 1 if datagram has been parsed, 0 if not
%   * counter: the counter of this type of datagram in the file (ie
%   first datagram of that type is 1 and last datagram is the total number
%   of datagrams of that type).
%   * number: the number/counter found in the datagram (usually
%   different to counter)
%   * size: for each datagram, datagram size in bytes
%   * syncCounter: for each datagram, the number of bytes founds between
%   this datagram and the previous one (any number different than zero
%   indicates a sunc error
%   * emNumber: EM Model number (eg 2045 for EM2040c)
%   * date: datagram date in YYYMMDD
%   * timeSinceMidnightInMilliseconds: time since midnight in msecs 
% - 'OutputFields'
%   *Chosen output Fields to speed up the reading in case we do not want
%   everything
%
% RESEARCH NOTES
%
% - PU Status output datagram structure seems different to the datagram
% manual description. Find the good description.#edit 21aug2013: updated to
% Rev Q. Need to be checked though.# 
%
% - code currently lists the EM model numbers supported as a test for sync.
% Add your model number in the list if it's not currently there. It would
% be better to remove this test and try to sync on ETX and Checksum
% instead.
%
% - to print out GPS datagrams (GGA), type: cell2mat(EM_Position.PositionInputDatagramAsReceived')
%
% - attitude datagrams contain several values of attitude. to pad cell values to allow plot, type:
% for ii = 1:length(EM_Attitude.TypeOfDatagram)
%     EM_Attitude.TimeInMillisecondsSinceRecordStart{ii} = [EM_Attitude.TimeInMillisecondsSinceRecordStart{ii};nan(max(EM_Attitude.NumberOfEntries)-length(EM_Attitude.TimeInMillisecondsSinceRecordStart{ii}),1)];
%     EM_Attitude.SensorStatus{ii} = [EM_Attitude.SensorStatus{ii};nan(max(EM_Attitude.NumberOfEntries)-length(EM_Attitude.SensorStatus{ii}),1)];
%     EM_Attitude.Roll{ii} = [EM_Attitude.Roll{ii};nan(max(EM_Attitude.NumberOfEntries)-length(EM_Attitude.Roll{ii}),1)];
%     EM_Attitude.Pitch{ii} = [EM_Attitude.Pitch{ii};nan(max(EM_Attitude.NumberOfEntries)-length(EM_Attitude.Pitch{ii}),1)];
%     EM_Attitude.Heave{ii} = [EM_Attitude.Heave{ii};nan(max(EM_Attitude.NumberOfEntries)-length(EM_Attitude.Heave{ii}),1)];
%     EM_Attitude.Heading{ii} = [EM_Attitude.Heading{ii};nan(max(EM_Attitude.NumberOfEntries)-length(EM_Attitude.Heading{ii}),1)];
% end
% % example: figure; grid on; plot(cell2mat(EM_Attitude.Roll))
%
% - to show soundspeed profile (if existing), type: figure;plot(cell2mat(EM_SoundSpeedProfile.Depth)./100, cell2mat(EM_SoundSpeedProfile.SoundSpeed)./10); grid on
%
% NEW FEATURES
%
% - 2015-09-30:
%   - first version taking from last version of convert_all_to_mat
%
% EXAMPLES
%
% ALLfilename = '.\DATA\RAW\0001_20140213_052736_Yolla.all';
%
% tic
% ALLfileinfo1 = CFF_convert_all_to_mat_v2(ALLfilename, 'temp1.mat');
% toc
%
% % using old conversion function:
% tic
% ALLfileinfo2 = CFF_convert_all_to_mat(ALLfilename, 'temp2.mat');
% toc
%
%%%
% Alex Schimel, Deakin University
%%%

%% Input arguments management using inputParser
p = inputParser;

% ALLfilename to parse as only required argument. Test for file existence and
% extension.
argName = 'ALLfilename';
argCheck = @(x) exist(x,'file') && any(strcmp(CFF_file_extension(x),{'.all','.ALL','.wcd','.WCD'}));
addRequired(p,argName,argCheck);

% MATfilename output as only optional argument.
argName = 'MATfilename';
argDefault = [ALLfilename(1:end-3) 'mat'];
argCheck = @isstr;
addParameter(p,argName,argDefault,argCheck)

argName = 'OutputFields';
argDefault = {};
argCheck = @iscell;
addParameter(p,argName,argDefault,argCheck)

% now parse inputs
parse(p,ALLfilename,varargin{:})

% and get results
MATfilename = p.Results.MATfilename;

% if output folder doesn't exist, create it
if ~exist(fileparts(MATfilename),'dir') && ~isempty(fileparts(MATfilename))
    mkdir(fileparts(MATfilename));
end

%% Now just read data with new set of functions

info = CFF_all_file_info(ALLfilename);

info.parsed(:) = 1; % to save all the datagrams

ALLfile = CFF_read_all_from_fileinfo(ALLfilename, info,'OutputFields',p.Results.OutputFields);

ALLfileinfo = CFF_save_mat_from_all(ALLfile,MATfilename);

