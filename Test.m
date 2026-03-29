cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

N = 100;                                                                                 % 种群规模
saves = 200;                                                                              % 进化代数
maxFE = N * 200;                                                                        % 最大评估次数

%%
platemo('algorithm', @NSGAII, 'N', N, 'problem', @myObj, 'maxFE', maxFE, 'save', saves);    % 出结果数据
% platemo('algorithm', @NSGAIII, 'N', N, 'problem', @myObj, 'maxFE', maxFE, 'save', saves);    % 出结果数据
platemo('algorithm', @NSGAIIPlus, 'N', N, 'problem', @myObj, 'maxFE', maxFE, 'save', saves);    % 出结果数据

% platemo('algorithm', @NSGAII, 'N', N, 'problem', @myObj, 'maxFE', maxFE);  % 出图
% platemo('algorithm', @NSGAIII, 'N', N, 'problem', @myObj, 'maxFE', maxFE);  % 出图
% platemo('algorithm', @NSGAIIPlus, 'N', N, 'problem', @myObj, 'maxFE', maxFE);  % 出图

