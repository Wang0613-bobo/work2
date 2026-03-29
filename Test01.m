% 3目标
load('./data/NSGAII/NSGAII_myObj_M3_D38_1.mat');
bestP1 = result{end, end}.best;
% bestP1 = result{end, end};
X1 = bestP1.decs;
Y1 = bestP1.objs;
IGD1 = metric.IGD;
GD1 = metric.GD;

% load('./data/NSGAIII/NSGAIII_myObj_M3_D38_1.mat');
% bestP2 = result{end, end}.best;
% % bestP1 = result{end, end};
% X2 = bestP2.decs;
% Y2 = bestP2.objs;
% IGD2 = metric.IGD;
% GD2 = metric.GD;

load('./data/NSGAIIPlus/NSGAIIPlus_myObj_M3_D38_4.mat');
bestP3 = result{end, end}.best;
% bestP3 = result{end, end};
X3 = bestP3.decs;
Y3 = bestP3.objs;
IGD3 = metric.IGD;
GD3 = metric.GD;




figure;
hold on;
grid on;
plot3(Y1(:,1), Y1(:,2), Y1(:,3), 'bo');
% plot3(Y2(:,1), Y2(:,2), Y2(:,3), 'gv');
plot3(Y3(:,1), Y3(:,2), Y3(:,3), 'r*');
xlabel('Y1', 'Fontsize', 15);
ylabel('Y2', 'Fontsize', 15);
zlabel('Y3', 'Fontsize', 15);
title('目标空间种群Pareto分布');
% legend('NSGA-II', 'NSGA-III', 'NSGA-II-改进');
legend('NSGA-II', 'NSGA-II-改进');
view(3);

figure;
scope = 1: length(IGD1);
semilogy(   scope, IGD1(scope)', '-', ...
            scope, IGD3(scope)', '-', ...
            'LineWidth', 1);
xlabel('进化', 'Fontsize', 15);
ylabel('IGD指标', 'Fontsize', 15);
legend('NSGA-II',  'NSGA-III-改进');
title('IGD指标对比');



%%
fileName = 'Copy_of_data04.txt';
[model] = initModel(fileName);

%%
[~, I1] = min(Y3(:, 1));
x1 = X3(I1, :);
y1 = Y3(I1, :);
model.printIndividual(x1, model);
figure;
model.showIndividual(x1, model);
title('时间最短方案');
[path1, typeOfPath1] = model.analyseIndividual(x1, model);

%%
[~, I2] = min(Y3(:, 2));
x2 = X3(I2, :);
y2 = Y3(I2, :);
model.printIndividual(x2, model);
figure;
model.showIndividual(x2, model);
title('成本最小方案');
[path2, typeOfPath2] = model.analyseIndividual(x2, model);

%%
[~, I3] = min(Y3(:, 3));
x3 = X3(I3, :);
y3 = Y3(I3, :);
model.printIndividual(x3, model);
figure;
model.showIndividual(x3, model);
title('碳排放量最少方案');
[path3, typeOfPath3] = model.analyseIndividual(x3, model);

