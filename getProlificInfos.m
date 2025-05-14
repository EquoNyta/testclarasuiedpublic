clear all, close all; clc;

path = 'data';
files = 'crm-nback-prolific_PARTICIPANT_SESSION*.json';
outPath = 'incompletes';
jsPath = [pwd filesep 'mergeJsons-analyseNbip'];
jsFilename = "mergeJson-cp.js";
scriptSh = "runJsViaMatlab.sh";

% 1/ pull data
system('git pull');
fprintf('1/ Git pull done.\n');
    
% 2/ move incomplete data
putAwayIncompleteData(path, files, outPath)
fprintf('2/ Incomplete data move into %s.\n', outPath);

% 3/ run mergeJson.js
pathToSh = fullfile(jsPath, scriptSh);
pathToJs = fullfile(jsPath, jsFilename);
cmdStr = sprintf("%s %s", pathToSh, pathToJs);

system(cmdStr);
fprintf('3/ mergeJson.js, done.\n');

% 4/ complete demographic data

% load it in a prolificData table
incompletes = getInfos4Incompletes([path filesep outPath],1);
[baseName, folder] = uigetfile('prolific*.csv');
prolificFilename = fullfile(folder, baseName);

opts = detectImportOptions(prolificFilename);
opts.VariableTypes(strcmpi(opts.VariableTypes, 'char')) = {'string'};
prolificData = readtable(prolificFilename, opts);

shortResFilename = [jsPath filesep 'output' filesep 'shortRes.csv'];
opts = detectImportOptions(shortResFilename);
opts.VariableTypes(strcmpi(opts.VariableTypes, 'char')) = {'string'};
shortRes = readtable(shortResFilename, opts);

% ask to load an old file to complete it
oldFile = 0;
if questdlg('Use an old file to complete?', 'Use old file', 'Yes', 'No', 'Yes') == "Yes"
    [oldBaseName, folder] = uigetfile('data/*.xls');
    prolificFilename = fullfile(folder, oldBaseName);
    
    opts = detectImportOptions(prolificFilename);
    opts.VariableTypes(strcmpi(opts.VariableTypes, 'char')) = {'string'};
    oldProlificData = readtable(prolificFilename, opts);
    oldFile = 1;
end

% add vars to prolificData
nRows = height(prolificData);
if any( strcmp('payer_rejeter',prolificData.Properties.VariableNames) ) == 0
    prolificData = addvars(prolificData, zeros(nRows,1) ,'NewVariableNames', 'payer_rejeter');
end
if any( strcmp('commentaire',prolificData.Properties.VariableNames) ) == 0
    prolificData = addvars(prolificData, strings(nRows,1) ,'NewVariableNames', 'commentaire');
end
s = seconds(prolificData.time_taken);
s.Format = 'hh:mm:ss';
if any( strcmp('time_taken_formated',prolificData.Properties.VariableNames) ) == 0
    prolificData = addvars(prolificData, s,'NewVariableNames', 'time_taken_formated');
end

% fill these new vars with info from the prolific file and the old file
nIncompletes = height(incompletes);
for i = 1:nIncompletes
    row = find(prolificData.participant_id == incompletes.participant_id(i));
    prolificData(row,{'payer_rejeter','commentaire'}) = {incompletes.payer_rejeter(i), incompletes.commentaire(i)};
end

for i = 1:nRows
    doThis = 1;
    if oldFile == 1
        idx = find(oldProlificData.participant_id == prolificData.participant_id(i));
        if ~isempty(idx) && oldProlificData.status(idx) ~= "ACTIVE"
            if oldProlificData.status(idx) == prolificData.status(i)
                prolificData.payer_rejeter(i) = oldProlificData.payer_rejeter(idx);
                prolificData.commentaire(i) = oldProlificData.commentaire(idx);
                doThis = 0;
            end
        end
    end
    
    if doThis == 1
        switch prolificData.status(i)
            case "RETURNED"
                if prolificData.commentaire(i) == ""
                    prolificData.commentaire(i) = "RETURNED";
                else
                    prolificData.commentaire(i) = "RETURNED + " + prolificData.commentaire(i);
                end
            case "TIMED-OUT"
                if prolificData.commentaire(i) == ""
                    prolificData.commentaire(i) = "TIMED-OUT";
                else
                    prolificData.commentaire(i) = "TIMED-OUT + " + prolificData.commentaire(i);
                end
            case "AWAITING REVIEW"
                if any(strcmpi(shortRes.participant, prolificData.participant_id(i)))
                    prolificData.payer_rejeter(i) = 1;
                end
            case "APPROVED"
                    prolificData.payer_rejeter(i) = 1;
            case "ACTIVE"
                prolificData.commentaire(i) = "ACTIVE";
            otherwise
                % do nothing
        end

        if prolificData.entered_code(i) == "NOCODE"
            prolificData.commentaire(i) = "NOCODE" + prolificData.commentaire(i);
        end
    end 
end

prolificData = sortrows(prolificData,'time_taken','ascend');
fprintf('4/ New prolificData, done.\n');

% 5/ save the new demographic data file
if questdlg('Save the new file?', 'Save', 'Yes', 'No', 'No') == "Yes"
    newName = ['data/new_' strrep(baseName,'csv','xls')];
    writetable(prolificData, newName, 'WriteVariableNames', true);
    fprintf('5/ Saved as %s.\n', newName);
end


%%%%%% functions
function T = getInfos4Incompletes(path, rewrite)
    if ~exist('path','var')
        path = uigetdir;
    else
        path = char(path);
    end
    
    if ~exist('rewrite','var')
        rewrite = 0;
    end
    
    infosFilename = [path filesep 'infos.xls'];
    
    if ~isfile(infosFilename) || rewrite == 1
        ls = dir([path filesep '*.csv']);
        nfiles = length(ls);
        
        varTypes = ["string","double","string"];
        varNames = ["participant_id","payer_rejeter","commentaire"];
        sz = [nfiles, length(varNames)];
        T = table('Size',sz,'VariableTypes',varTypes,'VariableNames',varNames);
        for ifile = 1:nfiles
            filename = [path filesep ls(ifile).name];
            data = readtable(filename);
            
            % store id
            T.participant_id(ifile) = string( data.subject{1} );
            
            nRows = height(data);
            
            % indicate who failed for the headphones test
            if nRows == 3
                T.commentaire(ifile) = "Pb casque";
            else
                T.commentaire(ifile) = string( nRows );
            end
        end
        writetable(T, infosFilename, 'WriteVariableNames', true);
    else
        opts = detectImportOptions(infosFilename);
        opts.VariableTypes(strcmpi(opts.VariableTypes, 'char')) = {'string'};
        T = readtable(infosFilename, opts);
    end
end

function putAwayIncompleteData(path, files, outPath)   
    if path(end) ~= filesep
        path = [path filesep];
    end
    
    if outPath(end) ~= filesep
        outPath = [outPath filesep];
    end
    
    outPath = [path outPath];
    
    ls = dir([path files]);
    
    if ~exist(outPath, 'dir')
        mkdir(outPath);
    end
    
    
    for i = 1:length(ls)
        from = [path ls(i).name];
        newName = strrep(ls(i).name,'json','csv');
        to = [outPath newName];
        movefile(from, to)
    end
end