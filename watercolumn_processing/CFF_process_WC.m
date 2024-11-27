function [fData, processingParams] = CFF_process_WC(fData, varargin)
%CFF_PROCESS_WC  Apply processing to WCD
%
%   CFF_PROCESS_WC applies one or several WCD-processing functions, in
%   series.
%
%   FDATA = CFF_PROCESS_WC(FDATA,FUNC) where FUNC is the handle of a CoFFee
%   core WCD-processing function, applies that function to FDATA using
%   default parameters. The function returns FDATA with processed WCD.
%   Possible function handles include (to date):
%   - @CFF_WC_radiometric_corrections_CORE (applies radiometric correction)
%   - @CFF_filter_WC_sidelobe_artifact_CORE (filters sidelobe artefact)
%   - @CFF_mask_WC_data_CORE (mask desired parts of the data)
%
%   CFF_PROCESS_WC(FDATA,FUNCS) where FUNCS is a cell array of handles of
%   CoFFee core WCD-processing functions, applies each function in turn to
%   FDATA using their respective default parameters. 
%
%   CFF_PROCESS_WC(FDATA,FUNC,PARAMS) where FUNC is the handle of a CoFFee
%   core WCD-processing function and PARAMS is a structure with
%   processing parameters for FUNC, uses those parameters in processing.
%
%   CFF_PROCESS_WC(FDATA,FUNCS,PARAMS) where FUNCS is a cell array of
%   handles of CoFFee core WCD-processing functions and PARAMS is a cell
%   array of structure with processing parameters for each function in
%   FUNCS, uses those parameters in processing.
%
%   CFF_PROCESS_WC(...,'comms',COMMS) specifies if and how this function
%   communicates on its internal state (progress, info, errors). COMMS can
%   be either a CFF_COMMS object, or a text string to initiate a new
%   CFF_COMMS object. Options are 'disp', 'textprogressbar', 'waitbar',
%   'oneline', 'multilines'. By default, using an empty CFF_COMMS object
%   (i.e. no communication). See CFF_COMMS for more information.
%
%   [FDATA,PARAMS] = CFF_process_WC(...) also output the processing
%   parameter structures PARAMS used in processing.
%
%   See also CFF_WC_RADIOMETRIC_CORRECTIONS_CORE,
%   CFF_FILTER_WC_SIDELOBE_ARTIFACT_CORE, CFF_MASK_WC_DATA_CORE,
%   CFF_WC_RADIOMETRIC_CORRECTIONS, CFF_FILTER_WC_SIDELOBE_ARTIFACT,
%   CFF_MASK_WC_DATA.

%   Copyright 2024-2024 Alexandre Schimel
%   Licensed under MIT. Details on https://github.com/alexschimel/CoFFee/


%% Input arguments management
p = inputParser;
addRequired(p,'fData',@(x) CFF_is_fData_version_current(x)); % source fData
addOptional(p,'processingList', {}, @CFF_mustBeFunctionHandleOrCellVectorOfFunctionHandles); % list of processing functions
addOptional(p,'processingParams', {}, @CFF_mustBeStructOrCellVectorOfStructsOrEmpty); % list of parameters for each processing function
addParameter(p,'flagReprocess', 1, @CFF_mustBeBoolean); % reprocess from scratch (1, default) or continue from existing processed data (0)
addParameter(p,'comms',CFF_Comms()); % information communication (none by default)
parse(p,fData,varargin{:});
fData = p.Results.fData;
processingList = p.Results.processingList;
processingParams = p.Results.processingParams;
flagReprocess = p.Results.flagReprocess;
comms = p.Results.comms;
clear p
if ischar(comms)
    comms = CFF_Comms(comms);
end

% processingList checks and edits
if isempty(processingList)
    % return input fData if processingList is empty
    warning('No processing functions specified. Returning fData unchanged.');
    return
elseif isa(processingList,'function_handle')
    % use cell arrays, even if only one processing is requested
    processingList = {processingList};
end

% number of processes to apply
nProcessesToApply = numel(processingList);

% processingParams checks and edits
if ~isempty(processingParams) && numel(processingList) ~= numel(processingParams)
    % processingList and processingParams must be the same size
    error('processingParams must be empty, or the same size as processingList.');
elseif isstruct(processingParams)
    % use cell arrays, even if only one processing is requested
    processingParams = {processingParams};
elseif isempty(processingParams)
    % if processingParams is empty, make it the same size as processingList
    processingParams = repmat({struct()}, 1, nProcessesToApply);
end


%% Prep

% start message
comms.start('Processing water-column data');
comms.progress(0,1);

%% (Re)initialize processing, or continue from existing processing
if ~CFF_is_WC_processed(fData) || flagReprocess
    flagReprocess = 1;
else
    flagReprocess = 0;
end

if flagReprocess
    % (re)initialize processing
    
    % Processed data are double precision (8 bytes) or single precision (4
    % bytes). Storing this data in this format will take a lot of disk
    % space. To save disk space, we encode that data in a lower precision
    % format (1 or 2 bytes) although we will lose in precision (e.g.
    % -23.4283 dB will be stored as -23.5 dB instead).
    % We define the desired precision of the stored data here:
    % - 1 byte allows storage of 255 different values, allowing
    %   for example a dynamic range of 25.5 dB at 0.1 dB resolution,
    %   or 127 dB at 0.5 dB resolution. Aka largest space saving but
    %   largest loss of precision.
    % - 2 bytes allow storage of 65535 different values, allowing
    %   for example a dynamic range of 655.35 dB at 0.01 dB
    %   resolution, or 65.535 dB at 0.001 dB resolution. Aka moderate space
    %   saving for moderate loss of precision 
    storing_precision = '1 byte'; % '1 byte' or '2 bytes'
    switch storing_precision
        case '1 byte'
            wcdataproc_Class = 'uint8';
        case '2 bytes'
            wcdataproc_Class = 'uint16';
    end
    
    % number, dimensions, and pings of memmap files data
    datagramSource = CFF_get_datagramSource(fData);
    [nSamples, nBeams, nPings] = cellfun(@(x) size(x.Data.val),fData.(sprintf('%s_SBP_SampleAmplitudes',datagramSource)));
    ping_gr_start = fData.(sprintf('%s_n_start',datagramSource));
    ping_gr_end   = fData.(sprintf('%s_n_end',datagramSource));
    nMemMapFiles = numel(ping_gr_start);
    
    % create empty binary files for processed data and memory-map them in
    % fData
    wc_dir = CFF_converted_data_folder(fData.ALLfilename{1});
    newfieldname = 'X_SBP_WaterColumnProcessed';
    fData = CFF_init_memmapfiles(fData,...
        'field', newfieldname, ...
        'wc_dir', wc_dir, ...
        'Class', wcdataproc_Class, ...
        'Factor', NaN, ... % to be updated later, from data
        'Nanval', intmin(wcdataproc_Class), ... % nan value is minimum possible value
        'Offset', NaN, ... % to be updated later, from data
        'MaxSamples', nSamples, ...
        'MaxBeams', nanmax(nBeams), ...
        'ping_group_start', ping_gr_start, ...
        'ping_group_end', ping_gr_end);
    
else
    % start from data already processed 
    [nSamples, nBeams, nPings] = cellfun(@(x) size(x.Data.val),fData.X_SBP_WaterColumnProcessed);
    ping_gr_start = fData.X_n_start;
    ping_gr_end   = fData.X_n_end;
    nMemMapFiles = numel(ping_gr_start);
    newfieldname = 'X_SBP_WaterColumnProcessed';
    wcdataproc_Class = fData.X_1_WaterColumnProcessed_Class;
end

%% Apply requested processings
for ig = 1:nMemMapFiles
    
    % indices of the pings in this memmap file
    iPingsInMemMapfile = ping_gr_start(ig):ping_gr_end(ig);
    
    % block processing setup
    [blocks,info] = CFF_setup_optimized_block_processing(...
        nPings(ig),nSamples(ig)*nBeams(ig)*4,...
        'desiredMaxMemFracToUse',0.1);
    nBlocks = size(blocks,1);
    %disp(info);
    
    % initialize encoding parameters for each data block
    minsrc_block = single(nan(1,nBlocks));
    maxsrc_block = single(nan(1,nBlocks));
    encode_factor_block = nan(1,nBlocks);
    encode_offset_block = nan(1,nBlocks);
    
    % destination values after encoding are fixed and only dependent on
    % precision byte chosen
    mindest = single(intmin(wcdataproc_Class)+1); % reserve min value for NaN
    maxdest = single(intmax(wcdataproc_Class));
    
    % processing per block of pings in memmap file, in reverse since the
    % last block is the most likely to need updating
    for iB = nBlocks:-1:1
        
        % list of pings in this block
        blockPings = (blocks(iB,1):blocks(iB,2));
        
        % corresponding pings in file
        iPings = iPingsInMemMapfile(blocks(iB,1):blocks(iB,2));
        
        % grab data in dB
        if flagReprocess
            % get original data
            datagramSource = CFF_get_datagramSource(fData);
            data = CFF_get_WC_data(fData,sprintf('%s_SBP_SampleAmplitudes',datagramSource),'iPing',iPings,'iRange',1:nSamples(ig),'output_format','true');
        else
            % get already processed data
            data = CFF_get_WC_data(fData,'X_SBP_WaterColumnProcessed','iPing',iPings,'iRange',1:nSamples(ig),'output_format','true');
        end
        
        % apply each process in series. Save the (default) parameters in
        % case input was missing
        for iP = 1:nProcessesToApply
            if ~isempty(comms.Type)
                comms.step(sprintf('Memmaped file %i/%i. Data block %i/%i. Applying %s',ig,nMemMapFiles,nBlocks-iB+1,nBlocks,char(processingList{iP})));
            end
            [data,processingParams{iP}] = feval(processingList{iP}, data, fData, iPings, processingParams{iP});
        end
        
        % Next is data encoding for storage. For this we need to know the
        % min and max value of all blocks, not just this one. We're going
        % to operate an intermediate encoding using best available
        % information, and perhaps later reencode.
        
        % min and max values in this block
        minsrc = nanmin(data(:));
        maxsrc = nanmax(data(:));
        
        % take the min of that or any previous block
        minsrc = nanmin(nanmin(minsrc_block),minsrc);
        maxsrc = nanmax(nanmax(maxsrc_block),maxsrc);
        
        % optimal encoding parameters
        encode_factor = (maxdest-mindest)./(maxsrc-minsrc);
        encode_offset = ((mindest.*maxsrc)-(maxdest.*minsrc))./(maxsrc-minsrc);
        % dest_check_optimal = encode_factor.*[minsrc maxsrc] + encode_offset;
        
        % suboptimal encoding parameters (to minimize changes of
        % recomputation in case there are several blocks of data). This is
        % not ideal. To change eventually XXX
        if nBlocks > 1
            encode_factor = nanmax(floor(encode_factor),1);
            encode_offset = ceil((mindest-encode_factor.*minsrc)./10).*10;
            dest_check_suboptimal = encode_factor.*[minsrc maxsrc] + encode_offset;
            if dest_check_suboptimal(1)<mindest || dest_check_suboptimal(2)>maxdest
                comms.info('warning: encoding saturation');
            end
        end
        
        % encode data
        data_encoded = cast(data.*encode_factor + encode_offset, wcdataproc_Class);
        
        % set nan values
        data_encoded(isnan(data)) = intmin(wcdataproc_Class);
        
        % store
        fData.X_SBP_WaterColumnProcessed{ig}.Data.val(:,:,blockPings) = data_encoded;
        
        % save parameters
        minsrc_block(iB) = minsrc;
        maxsrc_block(iB) = maxsrc;
        encode_factor_block(iB) = encode_factor;
        encode_offset_block(iB) = encode_offset;
        
        % update progress
        if ~isempty(comms.Type)
            comms.progress( (ig-1)/nMemMapFiles + (1/nMemMapFiles)*(nBlocks-iB+1)/nBlocks ,1);
        end
        
    end
    
    % we may have to reencode some blocks if blocks were encoded with
    % different parameters
    
    if nBlocks == 1
        % no need here. Just save the parameters
        encode_factor_final = encode_factor;
        encode_offset_final = encode_offset;
    else
        
        % total dynamic range across all blocks
        minsrc = nanmin(minsrc_block);
        maxsrc = nanmax(maxsrc_block);
        
        % optimal final encoding parameters
        encode_factor_final = (maxdest-mindest)./(maxsrc-minsrc);
        encode_offset_final = ((mindest.*maxsrc)-(maxdest.*minsrc))./(maxsrc-minsrc);
        
        % suboptimal final encoding parameters
        encode_factor_final = nanmax(floor(encode_factor_final),1);
        encode_offset_final = ceil((mindest-encode_factor_final.*minsrc)./10).*10;
        dest_check_suboptimal = encode_factor.*[minsrc maxsrc] + encode_offset;
        if dest_check_suboptimal(1)<mindest || dest_check_suboptimal(2)>maxdest
            comms.info('warning: encoding saturation');
        end
        
        % look for blocks that didn't use those parameters and
        % reencode them using final parameters
        for iB = 1:nBlocks
            
            reencode_flag = (encode_factor_final~=encode_factor_block(iB)) || (encode_offset_final~=encode_offset_block(iB));
            if ~reencode_flag
                continue;
            end
            
            % get stored processed data
            blockPings  = (blocks(iB,1):blocks(iB,2));
            encoded_data = fData.X_SBP_WaterColumnProcessed{ig}.Data.val(:,:,blockPings);
            
            % decode
            data_decoded = (single(encoded_data) - encode_offset_block(iB))/encode_factor_block(iB);
            
            % re-encode data
            data_reencoded = cast(data_decoded.*encode_factor_final + encode_offset_final, wcdataproc_Class);
            
            % re-set nan values
            data_reencoded(encoded_data==intmin(wcdataproc_Class)) = intmin(wcdataproc_Class);
            
            % re-store
            fData.X_SBP_WaterColumnProcessed{ig}.Data.val(:,:,blockPings) = data_reencoded;
            
        end
        
    end
    
    % reverse (decode) parameters for storage
    wcdataproc_Factor = 1./encode_factor_final;
    wcdataproc_Offset = -(encode_offset_final./encode_factor_final);
    
    % store (update) those parameters in fData
    p_field = strrep(newfieldname,'SBP','1');
    fData.(sprintf('%s_Factor',p_field))(ig) = wcdataproc_Factor;
    fData.(sprintf('%s_Offset',p_field))(ig) = wcdataproc_Offset;
    
end


%% Finalize

% save the updated fData on the drive
folder_for_converted_data = CFF_converted_data_folder(fData.ALLfilename{1});
mat_fdata_file = fullfile(folder_for_converted_data,'fData.mat');
save(mat_fdata_file,'-struct','fData','-v7.3');

% output processing parameters
if nProcessesToApply == 1
    processingParams = processingParams{1};
end


%% End message
comms.finish('Done');


end
