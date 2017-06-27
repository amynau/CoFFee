function ALLfile = CFF_read_all_from_fileinfo(ALLfilename, ALLfileinfo,varargin)
% function ALLfile = CFF_convert_all_to_mat(ALLfilename, ALLfileinfo)
%
% DESCRIPTION
%
% Reads and parse the datagrams in a Kongsberg EM series binary .all or
% .wcd data files (ALLfilename) that are indicated for parsing (where
% ALLfileinfo.parsed equals 1.) ALLfileinfo obtained from
% CFF_all_file_info.
%
% REQUIRED INPUT ARGUMENTS
%
% - 'ALLfilename': string filename to parse (extension in .all or .wcd)
%
% - 'ALLfileinfo': structure for description of the datagrams in
% input file. Fields are:
%   * ALLfilename: input file name
%   * filesize: file size in bytes
%   * datagsizeformat: endianness of the datagram size field 'b' or 'l'
%   * datagramsformat: endianness of the datagrams 'b' or 'l'
%   * datagNumberInFile:
%   * datagTypeNumber: for each datagram, SIMRAD datagram type in decimal
%   * datagTypeText: for each datagram, SIMRAD datagram type description
%   * parsed: for each datagram, 1 if the datagram is to be parsed, 0 if
%   not
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
%   * timeSinceMidnightInMilliseconds: time since midnight in msecs \
% - 'OutputFields'
%   *Chosen output Fields to speed up the reading in case we do not want
%   everything

% OUTPUTS:
%
% - 'ALLfile': stucture containing structures for each datagram type, and
% the original ALLfileinfo, now as ALLfile.info with ALLfile.info.parsed
% set to 1 if datagram was parsed.
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
% EXAMPLE
%
% ALLfilename = '.\DATA\RAW\0001_20140213_052736_Yolla.all';
%
% tic
% info = CFF_all_file_info(ALLfilename);
% info.parsed(:)=1; % to save all the datagrams
% ALLfile = CFF_read_all_from_fileinfo(ALLfilename, info);
% ALLfileinfo1 = CFF_save_mat_from_all(ALLfile, 'temp1.mat');
% clear ALLfile
% toc
%
% % using old conversion function:
% tic
% ALLfileinfo2 = CFF_convert_all_to_mat(ALLfilename, 'temp2.mat');
% toc
%
% NEW FEATURES
%
% - 2015-09-30:
%   - first version taking from last version of convert_all_to_mat
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
argName = 'ALLfileinfo';
argCheck = @isstruct;
addRequired(p,argName,argCheck);

%list of output required

argName='OutputFields';
argCheck = @iscell;
argDefault={};
addParameter(p,argName,argDefault,argCheck);

% now parse inputs
parse(p,ALLfilename,ALLfileinfo,varargin{:});

% and get results
ALLfilename = p.Results.ALLfilename;
ALLfileinfo = p.Results.ALLfileinfo;


%% Get basic info for file opening
filesize = ALLfileinfo.filesize;
datagsizeformat = ALLfileinfo.datagsizeformat;
datagramsformat = ALLfileinfo.datagramsformat;


%% Open file
[fid,~] = fopen(ALLfilename, 'r',datagramsformat);


%% Parse only datagrams indicated in ALLfileinfo
datagToParse = find(ALLfileinfo.parsed==1);

%% Reading datagrams
for iDatag = datagToParse'
    pos=ftell(fid);
    % go to begining of datagram
    pif = ALLfileinfo.datagPositionInFile(iDatag);
    
    fread(fid,pif-pos);
    %fseek(fid,pif,-1);
    % start reading
    nbDatag                         = fread(fid,1,'uint32',datagsizeformat); % number of bytes in datagram
    stxDatag                        = fread(fid,1,'uint8');  % STX (always H02)
    datagTypeNumber                 = fread(fid,1,'uint8');  % SIMRAD type of datagram
    emNumber                        = fread(fid,1,'uint16'); % EM Model Number
    date                            = fread(fid,1,'uint32'); % date
    timeSinceMidnightInMilliseconds = fread(fid,1,'uint32'); % time since midnight in milliseconds
    number                          = fread(fid,1,'uint16'); % datagram or ping number
    systemSerialNumber              = fread(fid,1,'uint16'); % EM system serial number
    
    % reset the datagram counter and parsed switch
    counter = NaN;
    parsed = 0;
    
    switch datagTypeNumber
        
        case 49
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_PUStatus'));
                continue;
            end
            datagTypeText = 'PU STATUS OUTPUT (31H)';
            
            % counter for this type of datagram
            try i49=i49+1; catch, i49=1; end
            counter = i49;
            
            % SOMETHING WRONG WITH THIS DATAGRAM, NEW TEMPLATE? REWRITE USING LATEST KONGSBERG DOCUMENTATION
            %             % parsing
            %             ALLfile.EM_PUStatus.STX(i49)                                    = stxDatag;
            %             ALLfile.EM_PUStatus.TypeOfDatagram(i49)                         = datagTypeNumber;
            %             ALLfile.EM_PUStatus.EMModelNumber(i49)                          = emNumber;
            %             ALLfile.EM_PUStatus.Date(i49)                                   = date;
            %             ALLfile.EM_PUStatus.TimeSinceMidnightInMilliseconds(i49)        = timeSinceMidnightInMilliseconds;
            %             ALLfile.EM_PUStatus.StatusDatagramCounter(i49)                  = number;
            %             ALLfile.EM_PUStatus.SystemSerialNumber(i49)                     = systemSerialNumber;
            %
            %             ALLfile.EM_PUStatus.PingRate(i49)                               = fread(fid,1,'uint16');
            %             ALLfile.EM_PUStatus.PingCounterOfLatestPing(i49)                = fread(fid,1,'uint16');
            %             ALLfile.EM_PUStatus.DistanceBetweenSwath(i49)                   = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.SensorInputStatusUDPPort2(i49)              = fread(fid,1,'uint32');
            %             ALLfile.EM_PUStatus.SensorInputStatusSerialPort1(i49)           = fread(fid,1,'uint32');
            %             ALLfile.EM_PUStatus.SensorInputStatusSerialPort2(i49)           = fread(fid,1,'uint32');
            %             ALLfile.EM_PUStatus.SensorInputStatusSerialPort3(i49)           = fread(fid,1,'uint32');
            %             ALLfile.EM_PUStatus.SensorInputStatusSerialPort4(i49)           = fread(fid,1,'uint32');
            %             ALLfile.EM_PUStatus.PPSStatus(i49)                              = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.PositionStatus(i49)                         = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.AttitudeStatus(i49)                         = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.ClockStatus(i49)                            = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.HeadingStatus (i49)                         = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.PUStatus(i49)                               = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.LastReceivedHeading(i49)                    = fread(fid,1,'uint16');
            %             ALLfile.EM_PUStatus.LastReceivedRoll(i49)                       = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.LastReceivedPitch(i49)                      = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.LastReceivedHeave(i49)                      = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.SoundSpeedAtTransducer(i49)                 = fread(fid,1,'uint16');
            %             ALLfile.EM_PUStatus.LastReceivedDepth(i49)                      = fread(fid,1,'uint32');
            %             ALLfile.EM_PUStatus.AlongShipVelocity(i49)                      = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.AttitudeVelocitySensor(i49)                 = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.MammalProtectionRamp(i49)                   = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.BackscatterAtObliqueAngle(i49)              = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.BackscatterAtNormalIncidence(i49)           = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.FixedGain(i49)                              = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.DepthToNormalIncidence(i49)                 = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.RangeToNormalIncidence(i49)                 = fread(fid,1,'uint16');
            %             ALLfile.EM_PUStatus.PortCoverage(i49)                           = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.StarboardCoverage(i49)                      = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.SoundSpeedAtTransducerFoundFromProfile(i49) = fread(fid,1,'uint16');
            %             ALLfile.EM_PUStatus.YawStabilization(i49)                       = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.PortCoverageOrAcrossShipVelocity(i49)       = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.StarboardCoverageOrDownwardVelocity(i49)    = fread(fid,1,'int16');
            %             ALLfile.EM_PUStatus.EM2040CPUtemp(i49)                          = fread(fid,1,'int8');
            %             ALLfile.EM_PUStatus.ETX(i49)                                    = fread(fid,1,'uint8');
            %             ALLfile.EM_PUStatus.CheckSum(i49)                               = fread(fid,1,'uint16');
            %
            %             % ETX check
            %             if ALLfile.EM_PUStatus.ETX(i49)~=3
            %                 error('wrong ETX value (ALLfile.EM_PUStatus)');
            %             end
            %
            %             % confirm parsing
            %             parsed = 1;
            
        case 65
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Attitude'));
                continue;
            end
            
            datagTypeText = 'ATTITUDE (41H)';
            
            % counter for this type of datagram
            try i65=i65+1; catch, i65=1; end
            counter = i65;
            
            % parsing
            ALLfile.EM_Attitude.NumberOfBytesInDatagram(i65)                = nbDatag;
            ALLfile.EM_Attitude.STX(i65)                                    = stxDatag;
            ALLfile.EM_Attitude.TypeOfDatagram(i65)                         = datagTypeNumber;
            ALLfile.EM_Attitude.EMModelNumber(i65)                          = emNumber;
            ALLfile.EM_Attitude.Date(i65)                                   = date;
            ALLfile.EM_Attitude.TimeSinceMidnightInMilliseconds(i65)        = timeSinceMidnightInMilliseconds;
            ALLfile.EM_Attitude.AttitudeCounter(i65)                        = number;
            ALLfile.EM_Attitude.SystemSerialNumber(i65)                     = systemSerialNumber;
            
            ALLfile.EM_Attitude.NumberOfEntries(i65)                        = fread(fid,1,'uint16'); %N
            % repeat cycle: N entries of 12 bits
            temp = ftell(fid);
            N = ALLfile.EM_Attitude.NumberOfEntries(i65) ;
            ALLfile.EM_Attitude.TimeInMillisecondsSinceRecordStart{i65} = fread(fid,N,'uint16',12-2);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_Attitude.SensorStatus{i65}                       = fread(fid,N,'uint16',12-2);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_Attitude.Roll{i65}                               = fread(fid,N,'int16',12-2);
            fseek(fid,temp+6,'bof'); % to next data type
            ALLfile.EM_Attitude.Pitch{i65}                              = fread(fid,N,'int16',12-2);
            fseek(fid,temp+8,'bof'); % to next data type
            ALLfile.EM_Attitude.Heave{i65}                              = fread(fid,N,'int16',12-2);
            fseek(fid,temp+10,'bof'); % to next data type
            ALLfile.EM_Attitude.Heading{i65}                            = fread(fid,N,'uint16',12-2);
            fseek(fid,2-12,'cof'); % we need to come back after last jump
            ALLfile.EM_Attitude.SensorSystemDescriptor(i65)                 = fread(fid,1,'uint8');
            ALLfile.EM_Attitude.ETX(i65)                                    = fread(fid,1,'uint8');
            ALLfile.EM_Attitude.CheckSum(i65)                               = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_Attitude.ETX(i65)~=3
                error('wrong ETX value (ALLfile.EM_Attitude)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 67
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Clock'));
                continue;
            end
            
            datagTypeText = 'CLOCK (43H)';
            
            % counter for this type of datagram
            try i67=i67+1; catch, i67=1; end
            counter = i67;
            
            % parsing
            ALLfile.EM_Clock.NumberOfBytesInDatagram(i67)                          = nbDatag;
            ALLfile.EM_Clock.STX(i67)                                              = stxDatag;
            ALLfile.EM_Clock.TypeOfDatagram(i67)                                   = datagTypeNumber;
            ALLfile.EM_Clock.EMModelNumber(i67)                                    = emNumber;
            ALLfile.EM_Clock.Date(i67)                                             = date;
            ALLfile.EM_Clock.TimeSinceMidnightInMilliseconds(i67)                  = timeSinceMidnightInMilliseconds;
            ALLfile.EM_Clock.ClockCounter(i67)                                     = number;
            ALLfile.EM_Clock.SystemSerialNumber(i67)                               = systemSerialNumber;
            
            ALLfile.EM_Clock.DateFromExternalClock(i67)                            = fread(fid,1,'uint32');
            ALLfile.EM_Clock.TimeSinceMidnightInMillisecondsFromExternalClock(i67) = fread(fid,1,'uint32');
            ALLfile.EM_Clock.OnePPSUse(i67)                                        = fread(fid,1,'uint8');
            ALLfile.EM_Clock.ETX(i67)                                              = fread(fid,1,'uint8');
            ALLfile.EM_Clock.CheckSum(i67)                                         = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_Clock.ETX(i67)~=3
                error('wrong ETX value (ALLfile.EM_Clock)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 68
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Depth'));
                continue;
            end
            
            datagTypeText = 'DEPTH DATAGRAM (44H)';
            
            % counter for this type of datagram
            try i68=i68+1; catch, i68=1; end
            counter = i68;
            
            % parsing
            ALLfile.EM_Depth.NumberOfBytesInDatagram(i68)           = nbDatag;
            ALLfile.EM_Depth.STX(i68)                               = stxDatag;
            ALLfile.EM_Depth.TypeOfDatagram(i68)                    = datagTypeNumber;
            ALLfile.EM_Depth.EMModelNumber(i68)                     = emNumber;
            ALLfile.EM_Depth.Date(i68)                              = date;
            ALLfile.EM_Depth.TimeSinceMidnightInMilliseconds(i68)   = timeSinceMidnightInMilliseconds;
            ALLfile.EM_Depth.PingCounter(i68)                       = number;
            ALLfile.EM_Depth.SystemSerialNumber(i68)                = systemSerialNumber;
            
            ALLfile.EM_Depth.HeadingOfVessel(i68)                   = fread(fid,1,'uint16');
            ALLfile.EM_Depth.SoundSpeedAtTransducer(i68)            = fread(fid,1,'uint16');
            ALLfile.EM_Depth.TransmitTransducerDepth(i68)           = fread(fid,1,'uint16');
            ALLfile.EM_Depth.MaximumNumberOfBeamsPossible(i68)      = fread(fid,1,'uint8');
            ALLfile.EM_Depth.NumberOfValidBeams(i68)                = fread(fid,1,'uint8'); %N
            ALLfile.EM_Depth.ZResolution(i68)                       = fread(fid,1,'uint8');
            ALLfile.EM_Depth.XAndYResolution(i68)                   = fread(fid,1,'uint8');
            ALLfile.EM_Depth.SamplingRate(i68)                      = fread(fid,1,'uint16'); % OR: ALLfile.EM_Depth.DepthDifferenceBetweenSonarHeadsInTheEM3000D(i68) = fread(fid,1,'int16');
            % repeat cycle: N entries of 16 bits
            temp = ftell(fid);
            N = ALLfile.EM_Depth.NumberOfValidBeams(i68);
            ALLfile.EM_Depth.DepthZ{i68}                        = fread(fid,N,'int16',16-2); % OR 'uint16' for EM120 and EM300
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_Depth.AcrosstrackDistanceY{i68}          = fread(fid,N,'int16',16-2);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_Depth.AlongtrackDistanceX{i68}           = fread(fid,N,'int16',16-2);
            fseek(fid,temp+6,'bof'); % to next data type
            ALLfile.EM_Depth.BeamDepressionAngle{i68}           = fread(fid,N,'int16',16-2);
            fseek(fid,temp+8,'bof'); % to next data type
            ALLfile.EM_Depth.BeamAzimuthAngle{i68}              = fread(fid,N,'uint16',16-2);
            fseek(fid,temp+10,'bof'); % to next data type
            ALLfile.EM_Depth.Range{i68}                         = fread(fid,N,'uint16',16-2);
            fseek(fid,temp+12,'bof'); % to next data type
            ALLfile.EM_Depth.QualityFactor{i68}                 = fread(fid,N,'uint8',16-1);
            fseek(fid,temp+13,'bof'); % to next data type
            ALLfile.EM_Depth.LengthOfDetectionWindow{i68}       = fread(fid,N,'uint8',16-1);
            fseek(fid,temp+14,'bof'); % to next data type
            ALLfile.EM_Depth.ReflectivityBS{i68}                = fread(fid,N,'int8',16-1);
            fseek(fid,temp+15,'bof'); % to next data type
            ALLfile.EM_Depth.BeamNumber{i68}                    = fread(fid,N,'uint8',16-1);
            fseek(fid,1-16,'cof'); % we need to come back after last jump
            ALLfile.EM_Depth.TransducerDepthOffsetMultiplier(i68) = fread(fid,1,'int8');
            ALLfile.EM_Depth.ETX(i68)                             = fread(fid,1,'uint8');
            ALLfile.EM_Depth.CheckSum(i68)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_Depth.ETX(i68)~=3,
                error('wrong ETX value (ALLfile.EM_Depth)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 70
            %
            %             if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Attitude'));
            %                 continue;
            %             end
            
            
            datagTypeText = 'RAW RANGE AND BEAM ANGLE (F) (46H)';
            
            % counter for this type of datagram
            try i70=i70+1; catch, i70=1; end
            counter = i70;
            
            % parsing
            % ...to write...
            
        case 71
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_SurfaceSoundSpeed'));
                continue;
            end
            
            datagTypeText = 'SURFACE SOUND SPEED (47H)';
            
            % counter for this type of datagram
            try i71=i71+1; catch, i71=1; end
            counter = i71;
            
            % parsing
            ALLfile.EM_SurfaceSoundSpeed.NumberOfBytesInDatagram(i71)           = nbDatag;
            ALLfile.EM_SurfaceSoundSpeed.STX(i71)                               = stxDatag;
            ALLfile.EM_SurfaceSoundSpeed.TypeOfDatagram(i71)                    = datagTypeNumber;
            ALLfile.EM_SurfaceSoundSpeed.EMModelNumber(i71)                     = emNumber;
            ALLfile.EM_SurfaceSoundSpeed.Date(i71)                              = date;
            ALLfile.EM_SurfaceSoundSpeed.TimeSinceMidnightInMilliseconds(i71)   = timeSinceMidnightInMilliseconds;
            ALLfile.EM_SurfaceSoundSpeed.SoundSpeedCounter(i71)                 = number;
            ALLfile.EM_SurfaceSoundSpeed.SystemSerialNumber(i71)                = systemSerialNumber;
            
            ALLfile.EM_SurfaceSoundSpeed.NumberOfEntries(i71)                   = fread(fid,1,'uint16'); %N
            % repeat cycle: N entries of 4 bits
            temp = ftell(fid);
            N = ALLfile.EM_SurfaceSoundSpeed.NumberOfEntries(i71);
            ALLfile.EM_SurfaceSoundSpeed.TimeInSecondsSinceRecordStart{i71} = fread(fid,N,'uint16',4-2);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_SurfaceSoundSpeed.SoundSpeed{i71}                    = fread(fid,N,'uint16',4-2);
            fseek(fid,2-4,'cof'); % we need to come back after last jump
            ALLfile.EM_SurfaceSoundSpeed.Spare(i71)                             = fread(fid,1,'uint8');
            ALLfile.EM_SurfaceSoundSpeed.ETX(i71)                               = fread(fid,1,'uint8');
            ALLfile.EM_SurfaceSoundSpeed.CheckSum(i71)                          = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_SurfaceSoundSpeed.ETX(i71)~=3
                error('wrong ETX value (ALLfile.EM_SurfaceSoundSpeed)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 72
            %
            %             if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Attitude'));
            %                 continue;
            %             end
            
            datagTypeText = 'HEADING (48H)';
            
            % counter for this type of datagram
            try i72=i72+1; catch, i72=1; end
            counter = i72;
            
            % parsing
            % ...to write...
            
        case 73
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_InstallationStart'));
                continue;
            end
            
            datagTypeText = 'INSTALLATION PARAMETERS - START (49H)';
            
            % counter for this type of datagram
            try i73=i73+1; catch, i73=1; end
            counter = i73;
            
            % parsing
            ALLfile.EM_InstallationStart.NumberOfBytesInDatagram(i73)         = nbDatag;
            ALLfile.EM_InstallationStart.STX(i73)                             = stxDatag;
            ALLfile.EM_InstallationStart.TypeOfDatagram(i73)                  = datagTypeNumber;
            ALLfile.EM_InstallationStart.EMModelNumber(i73)                   = emNumber;
            ALLfile.EM_InstallationStart.Date(i73)                            = date;
            ALLfile.EM_InstallationStart.TimeSinceMidnightInMilliseconds(i73) = timeSinceMidnightInMilliseconds;
            ALLfile.EM_InstallationStart.SurveyLineNumber(i73)                = number;
            ALLfile.EM_InstallationStart.SystemSerialNumber(i73)              = systemSerialNumber;
            
            ALLfile.EM_InstallationStart.SerialNumberOfSecondSonarHead(i73)   = fread(fid,1,'uint16');
            
            % 18 bytes of binary data already recorded and 3 more to come = 21.
            % but nbDatag will always be even thanks to SpareByte. so
            % nbDatag is 22 if there is no ASCII data and more if there is
            % ASCII data. read the rest as ASCII (including SpareByte) with
            % 1 byte for 1 character.
            ALLfile.EM_InstallationStart.ASCIIData{i73}                       = fscanf(fid, '%c', nbDatag-21);
            
       
            ALLfile.EM_InstallationStart.ETX(i73)                             = fread(fid,1,'uint8');
            ALLfile.EM_InstallationStart.CheckSum(i73)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_InstallationStart.ETX(i73)~=3
                error('wrong ETX value (ALLfile.EM_InstallationStart)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 78
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_RawRangeAngle78'));
                continue;
            end
            
            datagTypeText = 'RAW RANGE AND ANGLE 78 (4EH)';
            
            % counter for this type of datagram
            try i78=i78+1; catch, i78=1; end
            counter = i78;
            
            % parsing
            ALLfile.EM_RawRangeAngle78.NumberOfBytesInDatagram(i78)           = nbDatag;
            ALLfile.EM_RawRangeAngle78.STX(i78)                               = stxDatag;
            ALLfile.EM_RawRangeAngle78.TypeOfDatagram(i78)                    = datagTypeNumber;
            ALLfile.EM_RawRangeAngle78.EMModelNumber(i78)                     = emNumber;
            ALLfile.EM_RawRangeAngle78.Date(i78)                              = date;
            ALLfile.EM_RawRangeAngle78.TimeSinceMidnightInMilliseconds(i78)   = timeSinceMidnightInMilliseconds;
            ALLfile.EM_RawRangeAngle78.PingCounter(i78)                       = number;
            ALLfile.EM_RawRangeAngle78.SystemSerialNumber(i78)                = systemSerialNumber;
            
            ALLfile.EM_RawRangeAngle78.SoundSpeedAtTransducer(i78)            = fread(fid,1,'uint16');
            ALLfile.EM_RawRangeAngle78.NumberOfTransmitSectors(i78)           = fread(fid,1,'uint16'); %Ntx
            ALLfile.EM_RawRangeAngle78.NumberOfReceiverBeamsInDatagram(i78)   = fread(fid,1,'uint16'); %Nrx
            ALLfile.EM_RawRangeAngle78.NumberOfValidDetections(i78)           = fread(fid,1,'uint16');
            ALLfile.EM_RawRangeAngle78.SamplingFrequencyInHz(i78)             = fread(fid,1,'float32');
            ALLfile.EM_RawRangeAngle78.Dscale(i78)                            = fread(fid,1,'uint32');
            % repeat cycle #1: Ntx entries of 24 bits
            temp = ftell(fid);
            C = 24;
            Ntx = ALLfile.EM_RawRangeAngle78.NumberOfTransmitSectors(i78);
            ALLfile.EM_RawRangeAngle78.TiltAngle{i78}                     = fread(fid,Ntx,'int16',C-2);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.FocusRange{i78}                    = fread(fid,Ntx,'uint16',C-2);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.SignalLength{i78}                  = fread(fid,Ntx,'float32',C-4);
            fseek(fid,temp+8,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.SectorTransmitDelay{i78}           = fread(fid,Ntx,'float32',C-4);
            fseek(fid,temp+12,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.CentreFrequency{i78}               = fread(fid,Ntx,'float32',C-4);
            fseek(fid,temp+16,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.MeanAbsorptionCoeff{i78}           = fread(fid,Ntx,'uint16',C-2);
            fseek(fid,temp+18,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.SignalWaveformIdentifier{i78}      = fread(fid,Ntx,'uint8',C-1);
            fseek(fid,temp+19,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.TransmitSectorNumberTxArrayIndex{i78} = fread(fid,Ntx,'uint8',C-1);
            fseek(fid,temp+20,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.SignalBandwidth{i78}               = fread(fid,Ntx,'float32',C-4);
            fseek(fid,4-C,'cof'); % we need to come back after last jump
            % repeat cycle #2: Nrx entries of 16 bits
            temp = ftell(fid);
            C = 16;
            Nrx = ALLfile.EM_RawRangeAngle78.NumberOfReceiverBeamsInDatagram(i78);
            ALLfile.EM_RawRangeAngle78.BeamPointingAngle{i78}             = fread(fid,Nrx,'int16',C-2);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.TransmitSectorNumber{i78}          = fread(fid,Nrx,'uint8',C-1);
            fseek(fid,temp+3,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.DetectionInfo{i78}                 = fread(fid,Nrx,'uint8',C-1);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.DetectionWindowLength{i78}         = fread(fid,Nrx,'uint16',C-2);
            fseek(fid,temp+6,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.QualityFactor{i78}                 = fread(fid,Nrx,'uint8',C-1);
            fseek(fid,temp+7,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.Dcorr{i78}                         = fread(fid,Nrx,'int8',C-1);
            fseek(fid,temp+8,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.TwoWayTravelTime{i78}              = fread(fid,Nrx,'float32',C-4);
            fseek(fid,temp+12,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.ReflectivityBS{i78}                = fread(fid,Nrx,'int16',C-2);
            fseek(fid,temp+14,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.RealTimeCleaningInfo{i78}          = fread(fid,Nrx,'int8',C-1);
            fseek(fid,temp+15,'bof'); % to next data type
            ALLfile.EM_RawRangeAngle78.Spare{i78}                         = fread(fid,Nrx,'uint8',C-1);
            fseek(fid,1-C,'cof'); % we need to come back after last jump
            ALLfile.EM_RawRangeAngle78.Spare2(i78)                            = fread(fid,1,'uint8');
            ALLfile.EM_RawRangeAngle78.ETX(i78)                               = fread(fid,1,'uint8');
            ALLfile.EM_RawRangeAngle78.CheckSum(i78)                          = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_RawRangeAngle78.ETX(i78)~=3,
                error('wrong ETX value (ALLfile.EM_RawRangeAngle78)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 79
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Attitude'));
                continue;
            end
            
            datagTypeText = 'QUALITY FACTOR DATAGRAM 79 (4FH)';
            
            % counter for this type of datagram
            try i79=i79+1; catch, i79=1; end
            counter = i79;
            
            % parsing
            % ...to write...
            
        case 80
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Position'));
                continue;
            end
            
            datagTypeText = 'POSITION (50H)';
            
            % counter for this type of datagram
            try i80=i80+1; catch, i80=1; end
            counter = i80;
            
            % parsing
            ALLfile.EM_Position.NumberOfBytesInDatagram(i80)         = nbDatag;
            ALLfile.EM_Position.STX(i80)                             = stxDatag;
            ALLfile.EM_Position.TypeOfDatagram(i80)                  = datagTypeNumber;
            ALLfile.EM_Position.EMModelNumber(i80)                   = emNumber;
            ALLfile.EM_Position.Date(i80)                            = date;
            ALLfile.EM_Position.TimeSinceMidnightInMilliseconds(i80) = timeSinceMidnightInMilliseconds;
            ALLfile.EM_Position.PositionCounter(i80)                 = number;
            ALLfile.EM_Position.SystemSerialNumber(i80)              = systemSerialNumber;
            
            ALLfile.EM_Position.Latitude(i80)                        = fread(fid,1,'int32');
            ALLfile.EM_Position.Longitude(i80)                       = fread(fid,1,'int32');
            ALLfile.EM_Position.MeasureOfPositionFixQuality(i80)     = fread(fid,1,'uint16');
            ALLfile.EM_Position.SpeedOfVesselOverGround(i80)         = fread(fid,1,'uint16');
            ALLfile.EM_Position.CourseOfVesselOverGround(i80)        = fread(fid,1,'uint16');
            ALLfile.EM_Position.HeadingOfVessel(i80)                 = fread(fid,1,'uint16');
            ALLfile.EM_Position.PositionSystemDescriptor(i80)        = fread(fid,1,'uint8');
            ALLfile.EM_Position.NumberOfBytesInInputDatagram(i80)    = fread(fid,1,'uint8');
            
            % next data size is variable. 34 bits of binary data already
            % recorded and 3 more to come = 37. read the rest as ASCII
            % (including SpareByte)
            ALLfile.EM_Position.PositionInputDatagramAsReceived{i80} = fscanf(fid, '%c', nbDatag-37);
            
            ALLfile.EM_Position.ETX(i80)                             = fread(fid,1,'uint8');
            ALLfile.EM_Position.CheckSum(i80)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_Position.ETX(i80)~=3
                error('wrong ETX value (ALLfile.EM_Position)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 82
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Runtime'));
                continue;
            end
            
            datagTypeText = 'RUNTIME PARAMETERS (52H)';
            
            % counter for this type of datagram
            try i82=i82+1; catch, i82=1; end
            counter = i82;
            
            % parsing
            ALLfile.EM_Runtime.NumberOfBytesInDatagram(i82)                 = nbDatag;
            ALLfile.EM_Runtime.STX(i82)                                     = stxDatag;
            ALLfile.EM_Runtime.TypeOfDatagram(i82)                          = datagTypeNumber;
            ALLfile.EM_Runtime.EMModelNumber(i82)                           = emNumber;
            ALLfile.EM_Runtime.Date(i82)                                    = date;
            ALLfile.EM_Runtime.TimeSinceMidnightInMilliseconds(i82)         = timeSinceMidnightInMilliseconds;
            ALLfile.EM_Runtime.PingCounter(i82)                             = number;
            ALLfile.EM_Runtime.SystemSerialNumber(i82)                      = systemSerialNumber;
            
            ALLfile.EM_Runtime.OperatorStationStatus(i82)                   = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.ProcessingUnitStatus(i82)                    = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.BSPStatus(i82)                               = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.SonarHeadStatus(i82)                         = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.Mode(i82)                                    = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.FilterIdentifier(i82)                        = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.MinimumDepth(i82)                            = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.MaximumDepth(i82)                            = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.AbsorptionCoefficient(i82)                   = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.TransmitPulseLength(i82)                     = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.TransmitBeamwidth(i82)                       = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.TransmitPowerReMaximum(i82)                  = fread(fid,1,'int8');
            ALLfile.EM_Runtime.ReceiveBeamwidth(i82)                        = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.ReceiveBandwidth(i82)                        = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.ReceiverFixedGainSetting(i82)                = fread(fid,1,'uint8'); % OR mode 2
            ALLfile.EM_Runtime.TVGLawCrossoverAngle(i82)                    = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.SourceOfSoundSpeedAtTransducer(i82)          = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.MaximumPortSwathWidth(i82)                   = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.BeamSpacing(i82)                             = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.MaximumPortCoverage(i82)                     = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.YawAndPitchStabilizationMode(i82)            = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.MaximumStarboardCoverage(i82)                = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.MaximumStarboardSwathWidth(i82)              = fread(fid,1,'uint16');
            ALLfile.EM_Runtime.DurotongSpeed(i82)                           = fread(fid,1,'uint16'); % OR: ALLfile.EM_Runtime.TransmitAlongTilt(i82) = fread(fid,1,'int16');
            ALLfile.EM_Runtime.HiLoFrequencyAbsorptionCoefficientRatio(i82) = fread(fid,1,'uint8'); % OR filter identifier 2
            ALLfile.EM_Runtime.ETX(i82)                                     = fread(fid,1,'uint8');
            ALLfile.EM_Runtime.CheckSum(i82)                                = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_Runtime.ETX(i82)~=3,
                error('wrong ETX value (ALLfile.EM_Runtime)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 83
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_SeabedImage'));
                continue;
            end
            
            datagTypeText = 'SEABED IMAGE DATAGRAM (53H)';
            
            % counter for this type of datagram
            try i83=i83+1; catch, i83=1; end
            counter = i83;
            
            % parsing
            ALLfile.EM_SeabedImage.NumberOfBytesInDatagram(i83)         = nbDatag;
            ALLfile.EM_SeabedImage.STX(i83)                             = stxDatag;
            ALLfile.EM_SeabedImage.TypeOfDatagram(i83)                  = datagTypeNumber;
            ALLfile.EM_SeabedImage.EMModelNumber(i83)                   = emNumber;
            ALLfile.EM_SeabedImage.Date(i83)                            = date;
            ALLfile.EM_SeabedImage.TimeSinceMidnightInMilliseconds(i83) = timeSinceMidnightInMilliseconds;
            ALLfile.EM_SeabedImage.PingCounter(i83)                     = number;
            ALLfile.EM_SeabedImage.SystemSerialNumber(i83)              = systemSerialNumber;
            
            ALLfile.EM_SeabedImage.MeanAbsorptionCoefficient(i83)       = fread(fid,1,'uint16'); % 'this field had earlier definition'
            ALLfile.EM_SeabedImage.PulseLength(i83)                     = fread(fid,1,'uint16'); % 'this field had earlier definition'
            ALLfile.EM_SeabedImage.RangeToNormalIncidence(i83)          = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage.StartRangeSampleOfTVGRamp(i83)       = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage.StopRangeSampleOfTVGRamp(i83)        = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage.NormalIncidenceBS(i83)               = fread(fid,1,'int8'); %BSN
            ALLfile.EM_SeabedImage.ObliqueBS(i83)                       = fread(fid,1,'int8'); %BSO
            ALLfile.EM_SeabedImage.TxBeamwidth(i83)                     = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage.TVGLawCrossoverAngle(i83)            = fread(fid,1,'uint8');
            ALLfile.EM_SeabedImage.NumberOfValidBeams(i83)              = fread(fid,1,'uint8'); %N
            % repeat cycle: N entries of 6 bits
            temp = ftell(fid);
            N = ALLfile.EM_SeabedImage.NumberOfValidBeams(i83);
            ALLfile.EM_SeabedImage.BeamIndexNumber{i83}             = fread(fid,N,'uint8',6-1);
            fseek(fid,temp+1,'bof'); % to next data type
            ALLfile.EM_SeabedImage.SortingDirection{i83}            = fread(fid,N,'int8',6-1);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_SeabedImage.NumberOfSamplesPerBeam{i83}      = fread(fid,N,'uint16',6-2); %Ns
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_SeabedImage.CentreSampleNumber{i83}          = fread(fid,N,'uint16',6-2);
            fseek(fid,2-6,'cof'); % we need to come back after last jump

            Ns = [ALLfile.EM_SeabedImage.NumberOfSamplesPerBeam{i83}];
            tmp=fread(fid,sum(Ns),'int16');
           
            ALLfile.EM_SeabedImage.SampleAmplitudes(i83).beam = mat2cell(tmp,Ns);
            
            % "spare byte if required to get even length (always 0 if used)"
            if floor(sum(Ns)/2) == sum(Ns)/2
                % even so far, since ETX is 1 byte, add a spare here
                ALLfile.EM_SeabedImage.Data.SpareByte(i83)              = fread(fid,1,'uint8');
            else
                % odd so far, since ETX is 1 bytes, no spare
                ALLfile.EM_SeabedImage.Data.SpareByte(i83) = NaN;
            end
            ALLfile.EM_SeabedImage.ETX(i83)                             = fread(fid,1,'uint8');
            ALLfile.EM_SeabedImage.CheckSum(i83)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_SeabedImage.ETX(i83)~=3
                error('wrong ETX value (ALLfile.EM_SeabedImage)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 85
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_SoundSpeedProfile'));
                continue;
            end
            
            datagTypeText = 'SOUND SPEED PROFILE (55H)';
            
            % counter for this type of datagram
            try i85=i85+1; catch, i85=1; end
            counter = i85;
            
            % parsing
            ALLfile.EM_SoundSpeedProfile.NumberOfBytesInDatagram(i85)                           = nbDatag;
            ALLfile.EM_SoundSpeedProfile.STX(i85)                                               = stxDatag;
            ALLfile.EM_SoundSpeedProfile.TypeOfDatagram(i85)                                    = datagTypeNumber;
            ALLfile.EM_SoundSpeedProfile.EMModelNumber(i85)                                     = emNumber;
            ALLfile.EM_SoundSpeedProfile.Date(i85)                                              = date;
            ALLfile.EM_SoundSpeedProfile.TimeSinceMidnightInMilliseconds(i85)                   = timeSinceMidnightInMilliseconds;
            ALLfile.EM_SoundSpeedProfile.ProfileCounter(i85)                                    = number;
            ALLfile.EM_SoundSpeedProfile.SystemSerialNumber(i85)                                = systemSerialNumber;
            
            ALLfile.EM_SoundSpeedProfile.DateWhenProfileWasMade(i85)                            = fread(fid,1,'uint32');
            ALLfile.EM_SoundSpeedProfile.TimeSinceMidnightInMillisecondsWhenProfileWasMade(i85) = fread(fid,1,'uint32');
            ALLfile.EM_SoundSpeedProfile.NumberOfEntries(i85)                                   = fread(fid,1,'uint16'); %N
            ALLfile.EM_SoundSpeedProfile.DepthResolution(i85)                                   = fread(fid,1,'uint16');
            % repeat cycle: N entries of 8 bits
            temp = ftell(fid);
            N = ALLfile.EM_SoundSpeedProfile.NumberOfEntries(i85);
            ALLfile.EM_SoundSpeedProfile.Depth{i85}                                         = fread(fid,N,'uint32',8-4);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_SoundSpeedProfile.SoundSpeed{i85}                                    = fread(fid,N,'uint32',8-4);
            fseek(fid,4-8,'cof'); % we need to come back after last jump
            ALLfile.EM_SoundSpeedProfile.SpareByte(i85)                                         = fread(fid,1,'uint8');
            ALLfile.EM_SoundSpeedProfile.ETX(i85)                                               = fread(fid,1,'uint8');
            ALLfile.EM_SoundSpeedProfile.CheckSum(i85)                                          = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_SoundSpeedProfile.ETX(i85)~=3
                error('wrong ETX value (ALLfile.EM_SoundSpeedProfile)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 88
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_XYZ88'));
                continue;
            end
            
            datagTypeText = 'XYZ 88 (58H)';
            
            % counter for this type of datagram
            try i88=i88+1; catch, i88=1; end
            counter = i88;
            
            % parsing
            ALLfile.EM_XYZ88.NumberOfBytesInDatagram(i88)           = nbDatag;
            ALLfile.EM_XYZ88.STX(i88)                               = stxDatag;
            ALLfile.EM_XYZ88.TypeOfDatagram(i88)                    = datagTypeNumber;
            ALLfile.EM_XYZ88.EMModelNumber(i88)                     = emNumber;
            ALLfile.EM_XYZ88.Date(i88)                              = date;
            ALLfile.EM_XYZ88.TimeSinceMidnightInMilliseconds(i88)   = timeSinceMidnightInMilliseconds;
            ALLfile.EM_XYZ88.PingCounter(i88)                       = number;
            ALLfile.EM_XYZ88.SystemSerialNumber(i88)                = systemSerialNumber;
            
            ALLfile.EM_XYZ88.HeadingOfVessel(i88)                   = fread(fid,1,'uint16');
            ALLfile.EM_XYZ88.SoundSpeedAtTransducer(i88)            = fread(fid,1,'uint16');
            ALLfile.EM_XYZ88.TransmitTransducerDepth(i88)           = fread(fid,1,'float32');
            ALLfile.EM_XYZ88.NumberOfBeamsInDatagram(i88)           = fread(fid,1,'uint16');
            ALLfile.EM_XYZ88.NumberOfValidDetections(i88)           = fread(fid,1,'uint16');
            ALLfile.EM_XYZ88.SamplingFrequencyInHz(i88)             = fread(fid,1,'float32');
            ALLfile.EM_XYZ88.ScanningInfo(i88)                      = fread(fid,1,'uint8');
            ALLfile.EM_XYZ88.Spare1(i88)                            = fread(fid,1,'uint8');
            ALLfile.EM_XYZ88.Spare2(i88)                            = fread(fid,1,'uint8');
            ALLfile.EM_XYZ88.Spare3(i88)                            = fread(fid,1,'uint8');
            % repeat cycle: N entries of 20 bits
            temp = ftell(fid);
            C = 20;
            N = ALLfile.EM_XYZ88.NumberOfBeamsInDatagram(i88);
            ALLfile.EM_XYZ88.DepthZ{i88}                        = fread(fid,N,'float32',C-4);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_XYZ88.AcrosstrackDistanceY{i88}          = fread(fid,N,'float32',C-4);
            fseek(fid,temp+8,'bof'); % to next data type
            ALLfile.EM_XYZ88.AlongtrackDistanceX{i88}           = fread(fid,N,'float32',C-4);
            fseek(fid,temp+12,'bof'); % to next data type
            ALLfile.EM_XYZ88.DetectionWindowLength{i88}         = fread(fid,N,'uint16',C-2);
            fseek(fid,temp+14,'bof'); % to next data type
            ALLfile.EM_XYZ88.QualityFactor{i88}                 = fread(fid,N,'uint8',C-1);
            fseek(fid,temp+15,'bof'); % to next data type
            ALLfile.EM_XYZ88.BeamIncidenceAngleAdjustment{i88}  = fread(fid,N,'int8',C-1);
            fseek(fid,temp+16,'bof'); % to next data type
            ALLfile.EM_XYZ88.DetectionInformation{i88}          = fread(fid,N,'uint8',C-1);
            fseek(fid,temp+17,'bof'); % to next data type
            ALLfile.EM_XYZ88.RealTimeCleaningInformation{i88}   = fread(fid,N,'int8',C-1);
            fseek(fid,temp+18,'bof'); % to next data type
            ALLfile.EM_XYZ88.ReflectivityBS{i88}                = fread(fid,N,'int16',C-2);
            fseek(fid,2-C,'cof'); % we need to come back after last jump
            ALLfile.EM_XYZ88.Spare4(i88)                            = fread(fid,1,'uint8');
            ALLfile.EM_XYZ88.ETX(i88)                               = fread(fid,1,'uint8');
            ALLfile.EM_XYZ88.CheckSum(i88)                          = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_XYZ88.ETX(i88)~=3,
                error('wrong ETX value (ALLfile.EM_XYZ88)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 89
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_SeabedImage89'));
                continue;
            end
            
            datagTypeText = 'SEABED IMAGE DATA 89 (59H)';
            
            % counter for this type of datagram
            try i89=i89+1; catch, i89=1; end
            counter = i89;
            
            % parsing
            ALLfile.EM_SeabedImage89.NumberOfBytesInDatagram(i89)         = nbDatag;
            ALLfile.EM_SeabedImage89.STX(i89)                             = stxDatag;
            ALLfile.EM_SeabedImage89.TypeOfDatagram(i89)                  = datagTypeNumber;
            ALLfile.EM_SeabedImage89.EMModelNumber(i89)                   = emNumber;
            ALLfile.EM_SeabedImage89.Date(i89)                            = date;
            ALLfile.EM_SeabedImage89.TimeSinceMidnightInMilliseconds(i89) = timeSinceMidnightInMilliseconds;
            ALLfile.EM_SeabedImage89.PingCounter(i89)                     = number;
            ALLfile.EM_SeabedImage89.SystemSerialNumber(i89)              = systemSerialNumber;
            
            ALLfile.EM_SeabedImage89.SamplingFrequencyInHz(i89)           = fread(fid,1,'float32');
            ALLfile.EM_SeabedImage89.RangeToNormalIncidence(i89)          = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage89.NormalIncidenceBS(i89)               = fread(fid,1,'int16'); %BSN
            ALLfile.EM_SeabedImage89.ObliqueBS(i89)                       = fread(fid,1,'int16'); %BSO
            ALLfile.EM_SeabedImage89.TxBeamwidthAlong(i89)                = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage89.TVGLawCrossoverAngle(i89)            = fread(fid,1,'uint16');
            ALLfile.EM_SeabedImage89.NumberOfValidBeams(i89)              = fread(fid,1,'uint16');
            % repeat cycle: N entries of 6 bits
            temp = ftell(fid);
            C = 6;
            N = ALLfile.EM_SeabedImage89.NumberOfValidBeams(i89);
            ALLfile.EM_SeabedImage89.SortingDirection{i89}            = fread(fid,N,'int8',C-1);
            fseek(fid,temp+1,'bof'); % to next data type
            ALLfile.EM_SeabedImage89.DetectionInfo{i89}               = fread(fid,N,'uint8',C-1);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_SeabedImage89.NumberOfSamplesPerBeam{i89}      = fread(fid,N,'uint16',C-2); %Ns
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_SeabedImage89.CentreSampleNumber{i89}          = fread(fid,N,'uint16',C-2);
            fseek(fid,2-C,'cof'); % we need to come back after last jump
            Ns = [ALLfile.EM_SeabedImage89.NumberOfSamplesPerBeam{i89}];
            tmp=fread(fid,sum(Ns),'int16');
           
            ALLfile.EM_SeabedImage89.SampleAmplitudes(i89).beam = mat2cell(tmp,Ns);
          
            ALLfile.EM_SeabedImage89.Spare(i89)                           = fread(fid,1,'uint8');
            ALLfile.EM_SeabedImage89.ETX(i89)                             = fread(fid,1,'uint8');
            ALLfile.EM_SeabedImage89.CheckSum(i89)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_SeabedImage89.ETX(i89)~=3
                error('wrong ETX value (ALLfile.EM_SeabedImage89)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 102
            
            %             if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Attitude'));
            %                 continue;
            %             end
            %
            datagTypeText = 'RAW RANGE AND BEAM ANGLE (f) (66H)';
            
            % counter for this type of datagram
            try i102=i102+1; catch, i102=1; end
            counter = i102;
            
            % parsing
            % ...to write...
            
        case 104
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_Height'));
                continue;
            end
            
            datagTypeText = 'DEPTH (PRESSURE) OR HEIGHT DATAGRAM (68H)';
            
            % counter for this type of datagram
            try i104=i104+1; catch, i104=1; end
            counter = i104;
            
            % parsing
            ALLfile.EM_Height.NumberOfBytesInDatagram(i104)         = nbDatag;
            ALLfile.EM_Height.STX(i104)                             = stxDatag;
            ALLfile.EM_Height.TypeOfDatagram(i104)                  = datagTypeNumber;
            ALLfile.EM_Height.EMModelNumber(i104)                   = emNumber;
            ALLfile.EM_Height.Date(i104)                            = date;
            ALLfile.EM_Height.TimeSinceMidnightInMilliseconds(i104) = timeSinceMidnightInMilliseconds;
            ALLfile.EM_Height.HeightCounter(i104)                   = number;
            ALLfile.EM_Height.SystemSerialNumber(i104)              = systemSerialNumber;
            
            ALLfile.EM_Height.Height(i104)                          = fread(fid,1,'int32');
            ALLfile.EM_Height.HeigthType(i104)                      = fread(fid,1,'uint8');
            ALLfile.EM_Height.ETX(i104)                             = fread(fid,1,'uint8');
            ALLfile.EM_Height.CheckSum(i104)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_Height.ETX(i104)~=3
                error('wrong ETX value (ALLfile.EM_Height)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 105
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_InstallationStop'));
                continue;
            end
            
            datagTypeText = 'INSTALLATION PARAMETERS -  STOP (69H)';
            
            % counter for this type of datagram
            try i105=i105+1; catch, i105=1; end
            counter = i105;
            
            % parsing
            ALLfile.EM_InstallationStop.NumberOfBytesInDatagram(i105)         = nbDatag;
            ALLfile.EM_InstallationStop.STX(i105)                             = stxDatag;
            ALLfile.EM_InstallationStop.TypeOfDatagram(i105)                  = datagTypeNumber;
            ALLfile.EM_InstallationStop.EMModelNumber(i105)                   = emNumber;
            ALLfile.EM_InstallationStop.Date(i105)                            = date;
            ALLfile.EM_InstallationStop.TimeSinceMidnightInMilliseconds(i105) = timeSinceMidnightInMilliseconds;
            ALLfile.EM_InstallationStop.SurveyLineNumber(i105)                = number;
            ALLfile.EM_InstallationStop.SystemSerialNumber(i105)              = systemSerialNumber;
            
            ALLfile.EM_InstallationStop.SerialNumberOfSecondSonarHead(i105)   = fread(fid,1,'uint16');
            
            % 18 bytes of binary data already recorded and 3 more to come = 21.
            % but nbDatag will always be even thanks to SpareByte. so
            % nbDatag is 22 if there is no ASCII data and more if there is
            % ASCII data. read the rest as ASCII (including SpareByte) with
            % 1 byte for 1 character.
            ALLfile.EM_InstallationStop.ASCIIData{i105}                       = fscanf(fid, '%c', nbDatag-21);
            
            ALLfile.EM_InstallationStop.ETX(i105)                             = fread(fid,1,'uint8');
            ALLfile.EM_InstallationStop.CheckSum(i105)                        = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_InstallationStop.ETX(i105)~=3
                error('wrong ETX value (ALLfile.EM_InstallationStop)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 107
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_WaterColumn'));
                continue;
            end
            
            datagTypeText = 'WATER COLUMN DATAGRAM (6BH)';
            
            % counter for this type of datagram
            try i107=i107+1; catch, i107=1; end
            counter = i107;
            
            % parsing
            ALLfile.EM_WaterColumn.NumberOfBytesInDatagram(i107)           = nbDatag;
            ALLfile.EM_WaterColumn.STX(i107)                               = stxDatag;
            ALLfile.EM_WaterColumn.TypeOfDatagram(i107)                    = datagTypeNumber;
            ALLfile.EM_WaterColumn.EMModelNumber(i107)                     = emNumber;
            ALLfile.EM_WaterColumn.Date(i107)                              = date;
            ALLfile.EM_WaterColumn.TimeSinceMidnightInMilliseconds(i107)   = timeSinceMidnightInMilliseconds;
            ALLfile.EM_WaterColumn.PingCounter(i107)                       = number;
            ALLfile.EM_WaterColumn.SystemSerialNumber(i107)                = systemSerialNumber;
            
            ALLfile.EM_WaterColumn.NumberOfDatagrams(i107)                 = fread(fid,1,'uint16');
            ALLfile.EM_WaterColumn.DatagramNumbers(i107)                   = fread(fid,1,'uint16');
            ALLfile.EM_WaterColumn.NumberOfTransmitSectors(i107)           = fread(fid,1,'uint16'); %Ntx
            ALLfile.EM_WaterColumn.TotalNumberOfReceiveBeams(i107)         = fread(fid,1,'uint16');
            ALLfile.EM_WaterColumn.NumberOfBeamsInThisDatagram(i107)       = fread(fid,1,'uint16'); %Nrx
            ALLfile.EM_WaterColumn.SoundSpeed(i107)                        = fread(fid,1,'uint16'); %SS
            ALLfile.EM_WaterColumn.SamplingFrequency(i107)                 = fread(fid,1,'uint32'); %SF
            ALLfile.EM_WaterColumn.TXTimeHeave(i107)                       = fread(fid,1,'int16');
            ALLfile.EM_WaterColumn.TVGFunctionApplied(i107)                = fread(fid,1,'uint8'); %X
            ALLfile.EM_WaterColumn.TVGOffset(i107)                         = fread(fid,1,'int8'); %C
            ALLfile.EM_WaterColumn.ScanningInfo(i107)                      = fread(fid,1,'uint8');
            ALLfile.EM_WaterColumn.Spare1(i107)                            = fread(fid,1,'uint8');
            ALLfile.EM_WaterColumn.Spare2(i107)                            = fread(fid,1,'uint8');
            ALLfile.EM_WaterColumn.Spare3(i107)                            = fread(fid,1,'uint8');
            % repeat cycle #1: Ntx entries of 6 bits
            temp = ftell(fid);
            C = 6;
            Ntx = ALLfile.EM_WaterColumn.NumberOfTransmitSectors(i107);
            ALLfile.EM_WaterColumn.TiltAngle{i107}                     = fread(fid,Ntx,'int16',C-2);
            fseek(fid,temp+2,'bof'); % to next data type
            ALLfile.EM_WaterColumn.CenterFrequency{i107}               = fread(fid,Ntx,'uint16',C-2);
            fseek(fid,temp+4,'bof'); % to next data type
            ALLfile.EM_WaterColumn.TransmitSectorNumber{i107}          = fread(fid,Ntx,'uint8',C-1);
            fseek(fid,temp+5,'bof'); % to next data type
            ALLfile.EM_WaterColumn.Spare{i107}                         = fread(fid,Ntx,'uint8',C-1);
            fseek(fid,1-C,'cof'); % we need to come back after last jump
            % repeat cycle #2: Nrx entries of a possibly variable number of bits. Using a for loop
            Nrx = ALLfile.EM_WaterColumn.NumberOfBeamsInThisDatagram(i107);
            Ns = nan(1,Nrx);
            for jj=1:Nrx
                ALLfile.EM_WaterColumn.BeamPointingAngle{i107}(jj)             = fread(fid,1,'int16');
                ALLfile.EM_WaterColumn.StartRangeSampleNumber{i107}(jj)        = fread(fid,1,'uint16');
                ALLfile.EM_WaterColumn.NumberOfSamples{i107}(jj)               = fread(fid,1,'uint16'); %Ns
                ALLfile.EM_WaterColumn.DetectedRangeInSamples{i107}(jj)        = fread(fid,1,'uint16'); %DR
                ALLfile.EM_WaterColumn.TransmitSectorNumber2{i107}(jj)         = fread(fid,1,'uint8');
                ALLfile.EM_WaterColumn.BeamNumber{i107}(jj)                    = fread(fid,1,'uint8');
                Ns(jj) = ALLfile.EM_WaterColumn.NumberOfSamples{i107}(jj);
                ALLfile.EM_WaterColumn.SampleAmplitude{i107}{jj}               = fread(fid,Ns(jj),'int8');
            end
            % "spare byte if required to get even length (always 0 if used)"
            if floor((Nrx*10+sum(Ns))/2) == (Nrx*10+sum(Ns))/2
                % even so far, since ETX is 1 byte, add a spare here
                ALLfile.EM_WaterColumn.Spare4(i107)                            = fread(fid,1,'uint8');
            else
                % odd so far, since ETX is 1 bytes, no spare
                ALLfile.EM_WaterColumn.Spare4(i107) = NaN;
            end
            ALLfile.EM_WaterColumn.ETX(i107)                               = fread(fid,1,'uint8');
            ALLfile.EM_WaterColumn.CheckSum(i107)                          = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_WaterColumn.ETX(i107)~=3,
                error('wrong ETX value (ALLfile.EM_WaterColumn)');
            end
            
            % confirm parsing
            parsed = 1;
            
        case 110
            
            if ~isempty(p.Results.OutputFields)&&~any(strcmpi(p.Results.OutputFields,'EM_NetworkAttitude'));
                continue;
            end
            
            datagTypeText = 'NETWORK ATTITUDE VELOCITY DATAGRAM 110 (6EH)';
            
            % counter for this type of datagram
            try i110=i110+1; catch, i110=1; end
            counter = i110;
            
            % parsing
            ALLfile.EM_NetworkAttitude.NumberOfBytesInDatagram(i110)                    = nbDatag;
            ALLfile.EM_NetworkAttitude.STX(i110)                                        = stxDatag;
            ALLfile.EM_NetworkAttitude.TypeOfDatagram(i110)                             = datagTypeNumber;
            ALLfile.EM_NetworkAttitude.EMModelNumber(i110)                              = emNumber;
            ALLfile.EM_NetworkAttitude.Date(i110)                                       = date;
            ALLfile.EM_NetworkAttitude.TimeSinceMidnightInMilliseconds(i110)            = timeSinceMidnightInMilliseconds;
            ALLfile.EM_NetworkAttitude.NetworkAttitudeCounter(i110)                     = number;
            ALLfile.EM_NetworkAttitude.SystemSerialNumber(i110)                         = systemSerialNumber;
            
            ALLfile.EM_NetworkAttitude.NumberOfEntries(i110)                            = fread(fid,1,'uint16'); %N
            ALLfile.EM_NetworkAttitude.SensorSystemDescriptor(i110)                     = fread(fid,1,'int8');
            ALLfile.EM_NetworkAttitude.Spare(i110)                                      = fread(fid,1,'uint8');
            % repeat cycle: N entries of a variable number of bits. Using a for loop
            N = ALLfile.EM_NetworkAttitude.NumberOfEntries(i110);
            Nx = nan(1,N);
            for jj=1:N
                ALLfile.EM_NetworkAttitude.TimeInMillisecondsSinceRecordStart{i110}(jj)     = fread(fid,1,'uint16');
                ALLfile.EM_NetworkAttitude.Roll{i110}(jj)                                   = fread(fid,1,'int16');
                ALLfile.EM_NetworkAttitude.Pitch{i110}(jj)                                  = fread(fid,1,'int16');
                ALLfile.EM_NetworkAttitude.Heave{i110}(jj)                                  = fread(fid,1,'int16');
                ALLfile.EM_NetworkAttitude.Heading{i110}(jj)                                = fread(fid,1,'uint16');
                ALLfile.EM_NetworkAttitude.NumberOfBytesInInputDatagrams{i110}(jj)          = fread(fid,1,'uint8'); %Nx
                Nx(jj) = ALLfile.EM_NetworkAttitude.NumberOfBytesInInputDatagrams{i110}(jj);
                ALLfile.EM_NetworkAttitude.NetworkAttitudeInputDatagramAsReceived{i110}{jj} = fread(fid,Nx(jj),'uint8');
            end
            % "spare byte if required to get even length (always 0 if used)"
            if floor((N*11+sum(Nx))/2) == (N*11+sum(Nx))/2
                % even so far, since ETX is 1 byte, add a spare here
                ALLfile.EM_NetworkAttitude.Spare2(i110)                                    = fread(fid,1,'uint8');
            else
                % odd so far, since ETX is 1 bytes, no spare
                ALLfile.EM_NetworkAttitude.Spare2(i110) = NaN;
            end
            ALLfile.EM_NetworkAttitude.ETX(i110)                                           = fread(fid,1,'uint8');
            ALLfile.EM_NetworkAttitude.CheckSum(i110)                                      = fread(fid,1,'uint16');
            
            % ETX check
            if ALLfile.EM_NetworkAttitude.ETX(i110)~=3
                error('wrong ETX value (ALLfile.EM_NetworkAttitude)');
            end
            
            % confirm parsing
            parsed = 1;
            
        otherwise
            
            % this datagTypeNumber is not recognized yet
            datagTypeText = {sprintf('UNKNOWN DATAGRAM (%sH)',dec2hex(datagTypeNumber))};
            
    end
    
    % modify ALLfileinfo for output
    ALLfileinfo.parsed(iDatag,1) = parsed;
    
end


%% close fid
fclose(fid);

%% add info to parsed data
ALLfile.info = ALLfileinfo;

