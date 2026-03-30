cd(fileparts(mfilename('fullpath')));
projectRoot = cd;
addpath(genpath(projectRoot));

N = 100;                  % 种群规模
saves = 200;              % 保存代数
maxFE = N * 300;          % 最大评估次数

% 碳税水平：论文单位 元/t-CO2
carbonTaxList_ton = 0:5:100;

% 代码单位：元/kg-CO2
carbonTaxList = carbonTaxList_ton / 1000;

for i = 1:length(carbonTaxList)
    carbonTax = carbonTaxList(i);
    carbonTax_ton = carbonTaxList_ton(i);

    fprintf('\n=============================\n');
    fprintf('运行碳税水平：%.0f 元/t-CO2\n', carbonTax_ton);
    fprintf('=============================\n');

    % 关键：把碳税作为 problem 参数传给 myObj
    platemo( ...
        'algorithm', @NSGAIIPlus, ...
        'N', N, ...
        'problem', {@myObj, carbonTax}, ...
        'maxFE', maxFE, ...
        'save', saves ...
    );

    fprintf('已完成碳税水平：%.0f 元/t-CO2\n', carbonTax_ton);
    % ====== platemo运行结束后，保存当前碳税对应的结果文件 ======
archiveDir = fullfile(projectRoot, 'result_5_2');
if ~exist(archiveDir, 'dir')
    mkdir(archiveDir);
end

% PlatEMO 可能把结果放在 data/NSGAIIPlus 或 Data/NSGAIIPlus
cand1 = fullfile(projectRoot, 'data', 'NSGAIIPlus');
cand2 = fullfile(projectRoot, 'Data', 'NSGAIIPlus');

files = [];
if exist(cand1, 'dir')
    files = [files; dir(fullfile(cand1, 'NSGAIIPlus_myObj*.mat'))];
end
if exist(cand2, 'dir')
    files = [files; dir(fullfile(cand2, 'NSGAIIPlus_myObj*.mat'))];
end

assert(~isempty(files), '未找到NSGAIIPlus结果文件，请检查PlatEMO输出路径。');

[~, idxNewest] = max([files.datenum]);
srcFile = fullfile(files(idxNewest).folder, files(idxNewest).name);

dstFile = fullfile(archiveDir, sprintf('NSGAIIPlus_myObj_tax_%03d.mat', carbonTax_ton));
copyfile(srcFile, dstFile);

fprintf('结果已归档到: %s\n', dstFile);
end


