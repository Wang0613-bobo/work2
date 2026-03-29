function [model] = initModel(fileName)
    data = load(fileName);
    data = updateData(data);

    model.startPointId = 1;                                                 % 起点id（上海）
    model.endPointId = 20;                                                  % 终点id（成都）

    % 货量设置：quantityOfCargo仅作为兼容字段/最可能货量展示值
    model.quantityOfCargo = 1000;                                           % 兼容字段（最可能货量）, t
    model.fuzzyQ = [800 1000 1200];                                         % 三角模糊需求场景, t
    model.fuzzyW = [0.25 0.50 0.25];                                        % 三场景权重

    model.TW = [60 100];                                                    % 时间窗, h
    model.costOfUnitWait = [2 1 0.2];                                       % [公路 铁路 水路]单位等待成本, 元/(h*t)
    model.speedOfTransportType = [80 60 25];                                % [公路 铁路 水路]运行速度, km/h
    model.costOfUnitTransport = [0.6 0.15 0.05];                            % [公路 铁路 水路]单位运输成本, 元/(km*t)
    model.carbonEmissionsOfUnitTransport = [0.0538 0.0099 0.0128];          % [公路 铁路 水路]单位运输碳排放, kg/(km*t)
    model.startTimeOfTransportType = [0 8 8];                               % [公路 铁路 水路]首班时刻
    model.endTimeOfTransportType = [24 20 16];                              % [公路 铁路 水路]末班时刻
    model.intervalTimeOfTransportType = [0 12 24];                          % [公路 铁路 水路]班次间隔
    model.rateDamagedOfRansportType = [0.3 0.2 0.1] / 100;                  % [公路 铁路 水路]运输货损率

    % 中转参数顺序：[不中转, 公铁, 公水, 铁水]
    model.rateDamagedOfTransferType = [0.00 0.04 0.04 0.04] / 100;          % 单位中转货损率
    model.costOfUnitTransfer = [0 3.5 3 4];                                 % 单位中转成本, 元/t
    model.timeOfUnitTransfer = [0 0.01 0.015 0.01];                         % 单位中转时间, h/t
    model.carbonEmissionsOfUnitTransfer = [0 0.54 0.82 1.02];               % 单位中转碳排放, kg/t

    model.price = 10000;                                                    % 单位货值, 元/t
    model.p1 = 8;                                                           % 提前到达惩罚, 元/(h*t)
    model.p2 = 20;                                                          % 延误到达惩罚, 元/(h*t)
    model.carbonTax = 0.5;                                                  % 统一碳税, 元/kg
    model.penaltyFactor = 10 ^ 10;                                          % Big-M惩罚系数

    model.numOfObjs = 2;                                                    % 双目标：[加权综合经济成本, 加权总碳排放]
    model.weightOfObjs = [0.5 0.5];                                         % 兼容字段（未参与本模型目标组装）

    model.numOfEdge = size(data, 1);
    model.edgeSet = data(1: model.numOfEdge, 1: 2);
    model.distanceTable = data(1: model.numOfEdge, 3: 5);
    model.numOfVertex = max(model.edgeSet(:));
    model.numOfTransportType = size(model.distanceTable, 2);

    model.adjacencyMatrix = getAdjacencyMatrix(model.edgeSet);
    [model.distanceMatOfAdjacency, ~] = floyd(model.adjacencyMatrix);
    [model.distanceMat3D] = getDistanceMat3D(model.edgeSet, model.distanceTable);

    model.sequence = removeX(1: model.numOfVertex, model.startPointId);
    model.numOfDecVariablesPart1 = length(model.sequence);
    model.numOfDecVariablesPart2 = length(model.sequence);
    model.numOfDecVariables = model.numOfDecVariablesPart1 + model.numOfDecVariablesPart2;

    model.lower2 = ones(1, model.numOfDecVariablesPart2);
    model.upper2 = ones(1, model.numOfDecVariablesPart2) * model.numOfTransportType;

    model.initIndividual = @initIndividual;
    model.repairIndividual = @repairIndividual;
    model.analyseIndividual = @analyseIndividual;
    model.getIndividualFitness = @getIndividualFitness;
    model.printIndividual = @printIndividual;
    model.showIndividual = @showIndividual;
    model.getPathTransferType = @getPathTransferType;
    model.getDistanceOfPath = @getDistanceOfPath;
    model.getArriveTime = @getArriveTime;
    model.getIndividualObjs = @getIndividualObjs;
    model.analyseIndividualUnderQ = @analyseIndividualUnderQ;
end

function [data] = updateData(data)
    [~, I] = sort(data(:, 1) * 100 + data(:, 2));
    data = data(I, :);
end

function [adjacencyMatrix] = getAdjacencyMatrix(edgeSet)
    numOfVertex = max(edgeSet(:));
    adjacencyMatrix = Inf(numOfVertex, numOfVertex);
    for i = 1: numOfVertex
        adjacencyMatrix(i, i) = 0;
    end
    for i = 1: size(edgeSet, 1)
        id1 = edgeSet(i, 1);
        id2 = edgeSet(i, 2);
        adjacencyMatrix(id1, id2) = 1;
    end
end

function [distanceMat] = getDistanceMat(edgeSet, distanceArray)
    numOfVertex = max(edgeSet(:));
    distanceMat = Inf(numOfVertex, numOfVertex);
    for i = 1: numOfVertex
        distanceMat(i, i) = 0;
    end
    for i = 1: size(edgeSet, 1)
        id1 = edgeSet(i, 1);
        id2 = edgeSet(i, 2);
        distanceMat(id1, id2) = distanceArray(i);
    end
end

function [distanceMat3D] = getDistanceMat3D(edgeSet, distanceTable)
    numOfVertex = max(edgeSet(:));
    numOfTransportType = size(distanceTable, 2);
    distanceMat3D = zeros(numOfVertex, numOfVertex, numOfTransportType);
    for i = 1: numOfTransportType
        distanceArray = distanceTable(:, i);
        distanceMat3D(:, :, i) = getDistanceMat(edgeSet, distanceArray);
    end
end

function [newArray] = removeX(originalArray, elementToRemove)
    indexToRemove = originalArray == elementToRemove;
    newArray = originalArray;
    newArray(indexToRemove) = [];
end

function [individualPart1] = initIndividualPart1(model)
    path = generateFeasiblePath(model);                                          % 含起点和终点
    usedNodes = path(2:end);                                                     % 染色体中不含起点
    restNodes = setdiff(model.sequence, usedNodes, 'stable');

    if ~isempty(restNodes)
        restNodes = restNodes(randperm(length(restNodes)));
    end

    individualPart1 = [usedNodes, restNodes];
end

function [individualPart2] = initIndividualPart2(individualPart1, model)
    path = getPath(individualPart1, model);
    individualPart2 = ones(1, model.numOfDecVariablesPart2);

    for i = 1:length(path)-1
        I = path(i);
        J = path(i+1);
        availableTypes = find(isfinite(squeeze(model.distanceMat3D(I, J, :))));
        if isempty(availableTypes)
            individualPart2(i) = 1;
        else
            individualPart2(i) = availableTypes(randi(length(availableTypes)));
        end
    end

    if length(path)-1 < model.numOfDecVariablesPart2
        tailLen = model.numOfDecVariablesPart2 - (length(path)-1);
        individualPart2(length(path):end) = randi(model.numOfTransportType, 1, tailLen);
    end
end

function [individual] = initIndividual(model)
    individualPart1 = initIndividualPart1(model);
    individualPart2 = initIndividualPart2(individualPart1, model);
    individual = [individualPart1 individualPart2];
end

function [path, typeOfPath] = analyseIndividual(individual, model)
    individualPart1 = individual(1:model.numOfDecVariablesPart1);
    individualPart2 = individual(1 + model.numOfDecVariablesPart1:end);

    individualPart2 = repairIndividualPart2(individualPart2, model);

    path = getPath(individualPart1, model);

                                                                                % 如果路径中存在不可达弧段，则直接重构一条可行路径
    if ~isPathFeasible(path, model)
        path = generateFeasiblePath(model);
        usedNodes = path(2:end);
        restNodes = setdiff(model.sequence, usedNodes, 'stable');
        if ~isempty(restNodes)
            restNodes = restNodes(randperm(length(restNodes)));
        end
        individualPart1 = [usedNodes, restNodes];
        path = getPath(individualPart1, model);
    end

    typeOfPath = individualPart2(1:length(path)-1);

                                                                                % 如果某一段运输方式不可用，则替换成该段可用方式
    for i = 1:length(path)-1
        I = path(i);
        J = path(i+1);
        if ~isfinite(model.distanceMat3D(I, J, typeOfPath(i)))
            availableTypes = find(isfinite(squeeze(model.distanceMat3D(I, J, :))));
            if ~isempty(availableTypes)
                typeOfPath(i) = availableTypes(randi(length(availableTypes)));
            end
        end
    end
end

function [path] = getPath(individualPart1, model)
    [~, I] = find(individualPart1 == model.endPointId);
    path = [model.startPointId individualPart1(1: I)];
end

function [newIndividualPart2] = repairIndividualPart2(individualPart2, model)
    newIndividualPart2 = individualPart2;
    newIndividualPart2 = max(newIndividualPart2, model.lower2);
    newIndividualPart2 = min(newIndividualPart2, model.upper2);
    newIndividualPart2 = round(newIndividualPart2);
end

function [distanceOfPath, distanceArray, numOfPenalty] = getDistanceOfPath(path, typeOfPath, model)
    numOfRoute = length(path) - 1;
    distanceArray = zeros(1, numOfRoute);
    for i = 1: numOfRoute
        I = path(i);
        J = path(i + 1);
        K = typeOfPath(i);
        distanceArray(i) = model.distanceMat3D(I, J, K);
    end

    numOfPenalty = 0;
    J = find(distanceArray == inf, 1);
    if ~isempty(J)
        numOfPenalty = model.distanceMatOfAdjacency(path(J), path(end));
    end

    I = distanceArray < inf;
    distanceOfPath = sum(distanceArray(I)) + numOfPenalty * model.penaltyFactor;
end

% 每个节点到达时间、等待时间（中转时间沿用Q×timeOfUnitTransfer原逻辑）
function [arriveTime, waitTime] = getArriveTime(distanceArray, typeOfPath, pathTransferType, model, Q)
    if nargin < 5
        Q = model.quantityOfCargo;
    end

    travelTime = distanceArray ./ model.speedOfTransportType(typeOfPath);
    arriveTime = zeros(1, length(distanceArray) + 1);
    waitTime = zeros(1, length(distanceArray) + 1);

    currentTime = 0;
    for i = 1: length(typeOfPath)
        type = typeOfPath(i);
        startTimeOfTransport = model.startTimeOfTransportType(type);
        endTimeOfTransport = model.endTimeOfTransportType(type);
        intervalTimeOfTransport = model.intervalTimeOfTransportType(type);
        [startTime] = getStartTime(currentTime, startTimeOfTransport, endTimeOfTransport, intervalTimeOfTransport);
        waitTime(i) = startTime - currentTime;
        arriveTime(i + 1) = startTime + travelTime(i);
        transferTime = 0;
        if i > 1
            transferTime = Q * model.timeOfUnitTransfer(pathTransferType(i - 1));
        end
        currentTime = arriveTime(i + 1) + transferTime;
    end
end

function [startTime] = getStartTime(currentTime, startTimeOfTransport, endTimeOfTransport, intervalTimeOfTransport)
    if ~isfinite(currentTime)
        startTime = inf;
        return;
    end

    if intervalTimeOfTransport == 0
        intervalTimeOfTransport = 0.01;
    end

    currentT = mod(currentTime, 24);
    if currentT <= startTimeOfTransport
        startTime = startTimeOfTransport;
    else
        n = ceil((currentT - startTimeOfTransport) / intervalTimeOfTransport);
        startTime = startTimeOfTransport + n * intervalTimeOfTransport;
        if startTime > endTimeOfTransport
            startTime = ceil(startTime / 24) * 24 + startTimeOfTransport;
        end
    end
    awaitTime = startTime - currentT;
    startTime = awaitTime + currentTime;
end

% 转运类型：[不中转, 公铁, 公水, 铁水]
function [transferType] = getTransferType(id1, id2)
    transferType = 1;
    if id1 == 1 && id2 == 2 || id1 == 2 && id2 == 1
        transferType = 2;
    elseif id1 == 1 && id2 == 3 || id1 == 3 && id2 == 1
        transferType = 3;
    elseif id1 == 2 && id2 == 3 || id1 == 3 && id2 == 2
        transferType = 4;
    end
end

function [pathTransferType] = getPathTransferType(typeOfPath)
    pathTransferType = zeros(1, length(typeOfPath) - 1);
    for i = 1: length(pathTransferType)
        pathTransferType(i) = getTransferType(typeOfPath(i), typeOfPath(i + 1));
    end
end

function [C_wait] = getCostWait(waitTime, typeOfPath, model, Q)
    C_wait = sum(Q * waitTime(1: length(typeOfPath)) .* model.costOfUnitWait(typeOfPath));
end

function [C_trans] = getCostTransport(distanceArray, typeOfPath, model, Q)
    C_trans = sum(Q * distanceArray .* model.costOfUnitTransport(typeOfPath));
end

function [E_total] = getCarbonEmission(distanceArray, typeOfPath, pathTransferType, model, Q)
    E_trans = sum(Q * distanceArray .* model.carbonEmissionsOfUnitTransport(typeOfPath));
    E_transfer = sum(Q * model.carbonEmissionsOfUnitTransfer(pathTransferType));
    E_total = E_trans + E_transfer;
end

function [C_transfer] = getCostTransfer(pathTransferType, model, Q)
    C_transfer = sum(Q * model.costOfUnitTransfer(pathTransferType));
end

function [C_timeWindow] = getCostTimeWindow(arriveTime, model, Q)
    T = arriveTime(end);
    C_timeWindow = 0;
    if T < model.TW(1)
        C_timeWindow = Q * model.p1 * (model.TW(1) - T);
    elseif T > model.TW(2)
        C_timeWindow = Q * model.p2 * (T - model.TW(2));
    end
end

function [C_damage] = getCostDamage(typeOfPath, pathTransferType, model, Q)
    C_damage_transport = sum(Q * model.rateDamagedOfRansportType(typeOfPath));
    C_damage_transfer = sum(Q * model.rateDamagedOfTransferType(pathTransferType));
    C_damage = model.price * (C_damage_transport + C_damage_transfer);
end

% 单一货量情景下的完整评估中间层函数
function [C_wait, C_trans, C_transfer, C_timeWindow, C_damage, E_total, arriveTime, path, typeOfPath, numOfPenalty, distanceOfPath] = analyseIndividualUnderQ(individual, model, Q)
    [path, typeOfPath] = model.analyseIndividual(individual, model);
    [distanceOfPath, distanceArray, numOfPenalty] = getDistanceOfPath(path, typeOfPath, model);
    [pathTransferType] = model.getPathTransferType(typeOfPath);
    [arriveTime, waitTime] = getArriveTime(distanceArray, typeOfPath, pathTransferType, model, Q);

    C_wait = getCostWait(waitTime, typeOfPath, model, Q);
    C_trans = getCostTransport(distanceArray, typeOfPath, model, Q);
    C_transfer = getCostTransfer(pathTransferType, model, Q);
    C_timeWindow = getCostTimeWindow(arriveTime, model, Q);
    C_damage = getCostDamage(typeOfPath, pathTransferType, model, Q);
    E_total = getCarbonEmission(distanceArray, typeOfPath, pathTransferType, model, Q);
end

% 双目标：加权综合经济成本、加权总碳排放
function [individualObjs] = getIndividualObjs(individual, model)
    scenarioQ = model.fuzzyQ;
    scenarioW = model.fuzzyW;

    scenarioCost = zeros(1, length(scenarioQ));
    scenarioEmission = zeros(1, length(scenarioQ));

    penaltyValue = model.penaltyFactor;
    for i = 1: length(scenarioQ)
        Q = scenarioQ(i);
        [C_wait, C_trans, C_transfer, C_timeWindow, C_damage, E_total, ~, ~, ~, numOfPenalty, distanceOfPath] = analyseIndividualUnderQ(individual, model, Q);

        if numOfPenalty > 0 || any(~isfinite([C_wait, C_trans, C_transfer, C_timeWindow, C_damage, E_total]))
            individualObjs = [1 1] * (penaltyValue + abs(distanceOfPath));
            return;
        end

        C_base = C_wait + C_trans + C_transfer + C_timeWindow + C_damage;
        C_tax = model.carbonTax * E_total;
        C_total = C_base + C_tax;

        scenarioCost(i) = C_total;
        scenarioEmission(i) = E_total;
    end

    F_cost = sum(scenarioW .* scenarioCost);
    F_carbon = sum(scenarioW .* scenarioEmission);

    if any(~isfinite([F_cost, F_carbon]))
        individualObjs = [1 1] * penaltyValue;
        return;
    end

    individualObjs = [F_cost, F_carbon];
end

function printIndividual(individual, model)
    scenarioQ = model.fuzzyQ;
    scenarioW = model.fuzzyW;

    scenarioCost = zeros(1, length(scenarioQ));
    scenarioEmission = zeros(1, length(scenarioQ));
    scenarioArriveTime = zeros(1, length(scenarioQ));

    hasPenalty = false;
    for i = 1: length(scenarioQ)
        Q = scenarioQ(i);
        [C_wait, C_trans, C_transfer, C_timeWindow, C_damage, E_total, arriveTime, path, typeOfPath, numOfPenalty, distanceOfPath] = analyseIndividualUnderQ(individual, model, Q);

        if numOfPenalty > 0 || any(~isfinite([C_wait, C_trans, C_transfer, C_timeWindow, C_damage, E_total]))
            hasPenalty = true;
            fprintf('个体不可行，触发Big-M惩罚。numOfPenalty=%d, distanceOfPath=%.2f\n', numOfPenalty, distanceOfPath);
            break;
        end

        C_base = C_wait + C_trans + C_transfer + C_timeWindow + C_damage;
        C_tax = model.carbonTax * E_total;
        C_total = C_base + C_tax;

        scenarioCost(i) = C_total;
        scenarioEmission(i) = E_total;
        scenarioArriveTime(i) = arriveTime(end);

        fprintf('情景%d: Q=%.0f, W=%.2f, C_wait=%.2f, C_trans=%.2f, C_transfer=%.2f, C_timeWindow=%.2f, C_damage=%.2f, C_tax=%.2f, C_total=%.2f, E_total=%.2f, arriveTime=%.2f\n', ...
            i, Q, scenarioW(i), C_wait, C_trans, C_transfer, C_timeWindow, C_damage, C_tax, C_total, E_total, arriveTime(end));
    end

    if hasPenalty
        return;
    end

    [individualObjs] = getIndividualObjs(individual, model);
    fprintf('加权综合经济成本 F_cost: %.2f\n', individualObjs(1));
    fprintf('加权总碳排放量 F_carbon: %.2f\n', individualObjs(2));
    fprintf('路径序列 path: %s\n', mat2str(path));
    fprintf('运输方式序列 typeOfPath: %s\n', mat2str(typeOfPath));
    fprintf('各情景到达时间: %s\n', mat2str(scenarioArriveTime, 6));
end

function [individualFitness] = getIndividualFitness(individual, model)
    [individualObjs] = getIndividualObjs(individual, model);
    if any(~isfinite(individualObjs)) || any(individualObjs >= model.penaltyFactor)
        individualFitness = -model.penaltyFactor;
        return;
    end

    F_cost = individualObjs(1);
    individualFitness = -F_cost;
end

function [newIndividual] = repairIndividual(individual, model)
    individualPart1 = individual(1: model.numOfDecVariablesPart1);
    individualPart2 = individual(model.numOfDecVariablesPart1 + 1: end);

    [individualPart1] = repairIndividualPart1(individualPart1, model);
    [individualPart2] = repairIndividualPart2(individualPart2, model);
    newIndividual = [individualPart1 individualPart2];
end

function [newIndividualPart1] = repairIndividualPart1(individualPart1, model)
    [~, IA] = unique(individualPart1, 'stable');
    missSet = setdiff(model.sequence, individualPart1(IA), 'stable');
    newIndividualPart1 = individualPart1;
    dupId = setdiff(1: length(individualPart1), IA, 'stable');
    if ~isempty(dupId)
        fillLen = min(length(dupId), length(missSet));
        newIndividualPart1(dupId(1: fillLen)) = missSet(1: fillLen);
    end
end

function showIndividual(individual, model)
    [path, typeOfPath] = model.analyseIndividual(individual, model);

    distanceTable = model.distanceTable;
    s = model.edgeSet(:, 1);
    t = model.edgeSet(:, 2);
    numOfEdge = length(s);
    numOfVertex = model.numOfVertex;

    edgeLabel = cell(numOfEdge, 1);
    for i = 1: numOfEdge
        edgeLabel{i} = num2str(distanceTable(i, :), '%d,');
    end
    nodeLabel = cell(numOfVertex, 1);
    for i = 1: numOfVertex
        nodeLabel{i} = num2str(i);
    end

    edgeColor = zeros(numOfEdge, 3);

    for i = 1: length(path) - 1
        idS = path(i);
        idT = path(i + 1);
        id = find(s == idS & t == idT);
        if ~isempty(id)
            if typeOfPath(i) == 1
                edgeColor(id, :) = [1 0 0];
            elseif typeOfPath(i) == 2
                edgeColor(id, :) = [0 1 0];
            else
                edgeColor(id, :) = [0 0 1];
            end
        end
    end

    G = digraph(s, t);
    plot(G, 'NodeLabel', nodeLabel, 'EdgeLabel', edgeLabel, 'EdgeColor', edgeColor, 'LineWidth', 2);
end

function path = generateFeasiblePath(model)
    maxRetry = 200;

    for trial = 1:maxRetry
        current = model.startPointId;
        path = current;
        visited = false(1, model.numOfVertex);
        visited(current) = true;

        while current ~= model.endPointId
            outNodes = find(isfinite(model.adjacencyMatrix(current, :)) & model.adjacencyMatrix(current, :) > 0);

            feasibleNext = [];
            for k = 1:length(outNodes)
                nxt = outNodes(k);
                if ~visited(nxt) && isfinite(model.distanceMatOfAdjacency(nxt, model.endPointId))
                    feasibleNext(end+1) = nxt; %#ok<AGROW>
                end
            end

            if isempty(feasibleNext)
                break;
            end

            nextNode = feasibleNext(randi(length(feasibleNext)));
            path(end+1) = nextNode; %#ok<AGROW>
            visited(nextNode) = true;
            current = nextNode;
        end

        if path(end) == model.endPointId
            return;
        end
    end

    error('初始化失败：多次尝试后仍未生成可行路径，请检查网络连通性或初始化逻辑。');
end

function flag = isPathFeasible(path, model)
    flag = true;
    for i = 1:length(path)-1
        if ~isfinite(model.adjacencyMatrix(path(i), path(i+1))) || model.adjacencyMatrix(path(i), path(i+1)) <= 0
            flag = false;
            return;
        end
    end
end


