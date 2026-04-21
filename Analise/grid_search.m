% =========================================================================
% SCRIPT: GRID SEARCH PARA OTIMIZAÇÃO DE PARÂMETROS ARX
% =========================================================================
clear; clc;

% --- 1. CONFIGURAÇÕES BASE ---
fs = 16000; 
ganho_tensao = 1 / 0.02454545; 
ganho_corrente = 1 / 0.4888886;

% Arquivo representativo do motor Saudável (Padrão Ouro)
arquivo_treino = 'D:\Organizando dados\1 CV\Motores Saudáveis\Motores Saudáveis para Assinatura\STW_010_000.mat';

% --- 2. ESPAÇO DE BUSCA (GRID) ---
% Defina os limites para a busca. 
% Cuidado: limites muito altos exigem muita memória RAM e tempo de CPU.
na_range = 1:8;   % Varia de 1 a 8 polos
nb_range = 1:8;   % Varia de 1 a 8 zeros
nk_range = 1:3;   % Varia de 1 a 3 atrasos puros (frequentemente é 1)

% --- 3. CARREGAMENTO DOS DADOS ---
dados = load(arquivo_treino); 
campos = fieldnames(dados); Data_mat = dados.(campos{1}); 

Y_raw = [Data_mat(:,2), Data_mat(:,3), Data_mat(:,4)] * ganho_corrente;
U_raw = [Data_mat(:,5), Data_mat(:,6), Data_mat(:,7)] * ganho_tensao;

fases_ativas = var(Y_raw) > 1e-4; num_fases = sum(fases_ativas);
U_filt = U_raw(:, fases_ativas) - mean(U_raw(:, fases_ativas));
Y_filt = Y_raw(:, fases_ativas) - mean(Y_raw(:, fases_ativas));

N_linhas = length(Y_filt);

% --- 4. PREPARAÇÃO DO GRID SEARCH ---
total_combinacoes = length(na_range) * length(nb_range) * length(nk_range);
resultados = zeros(total_combinacoes, 4); % [na, nb, nk, fit_medio]
contador = 1;


% --- 5. LOOP DE OTIMIZAÇÃO ---
for na = na_range
    for nb = nb_range
        for nk = nk_range
            
            % Montagem das Equações para a combinação atual
            N_eq = N_linhas - max(na, nb+nk-1);
            Y_vec = Y_filt(max(na, nb+nk-1)+1:end, :);
            Phi = zeros(N_eq, num_fases*(na+nb));
            
            for i=1:na
                Phi(:, num_fases*(i-1)+1 : num_fases*i) = -Y_filt(max(na, nb+nk-1)+1-i : end-i, :); 
            end
            
            off = num_fases*na;
            for i=1:nb
                Phi(:, off+num_fases*(i-1)+1 : off+num_fases*i) = U_filt(max(na, nb+nk-1)+1-nk-(i-1) : end-nk-(i-1), :); 
            end
            
            % Estimação
            Theta = pinv(Phi) * Y_vec;
            
            % Simulação para calcular o Fit
            Y_estimado = Phi * Theta;
            
            % Cálculo do Fit Médio entre as fases ativas
            fit_fases = zeros(1, num_fases);
            for f = 1:num_fases
                erro = Y_vec(:, f) - Y_estimado(:, f);
                fit_fases(f) = 100 * (1 - norm(erro) / norm(Y_vec(:, f) - mean(Y_vec(:, f))));
            end
            fit_medio = mean(fit_fases);
            
            % Armazena resultado
            resultados(contador, :) = [na, nb, nk, fit_medio];
            
            % Mostra progresso esporadicamente para não travar o console
            if mod(contador, 50) == 0 || contador == total_combinacoes
                fprintf('Testados %d/%d... (Melhor até agora: %.2f%%)\n', contador, total_combinacoes, max(resultados(1:contador, 4)));
            end
            
            contador = contador + 1;
        end
    end
end

% --- 6. ANÁLISE E ESCOLHA INTELIGENTE (MENOR ORDEM vs MAIOR FIT) ---
% Adiciona uma 5ª coluna com a "Ordem Total" do modelo (na + nb + nk)
ordem_total = resultados(:, 1) + resultados(:, 2) + resultados(:, 3);
resultados_completos = [resultados, ordem_total]; % Colunas: [na, nb, nk, fit_medio, ordem_total]

% 1. Qual foi o maior Fit alcançado em todo o Grid?
max_fit_absoluto = max(resultados_completos(:, 4));

% 2. Define a tolerância (Ex: Aceitamos perder até 0.5% de Fit em troca de um modelo menor)
tolerancia = 0.5; 
limiar_aceitacao = max_fit_absoluto - tolerancia;

% 3. Filtra apenas as combinações que entregaram um Fit dentro dessa margem de "excelência"
idx_aceitaveis = resultados_completos(:, 4) >= limiar_aceitacao;
modelos_aceitaveis = resultados_completos(idx_aceitaveis, :);

% 4. Ordenação inteligente: 
% Prioridade 1: Menor ordem total (Coluna 5 crescente)
% Prioridade 2: Maior Fit (Coluna 4 decrescente, indicado pelo sinal de menos)
modelos_otimizados = sortrows(modelos_aceitaveis, [5, -4]);

fprintf('\n=======================================================\n');
fprintf('   RESULTADOS DO GRID SEARCH (Critério de Parcimônia)    \n');
fprintf('=======================================================\n');
fprintf('Fit Máximo Absoluto Encontrado: %.2f%%\n', max_fit_absoluto);
fprintf('Limiar de Aceitação (Tolerância de %.1f%%): %.2f%%\n', tolerancia, limiar_aceitacao);
fprintf('-------------------------------------------------------\n');
fprintf('   TOP 5 ESCOLHAS INTELIGENTES (Menor Ordem, Fit Alto) \n');
fprintf('-------------------------------------------------------\n');
fprintf('   na  |  nb  |  nk  | Ordem Total |  Fit Médio (%%) \n');
fprintf('-------------------------------------------------------\n');

num_mostrar = min(5, size(modelos_otimizados, 1));
for i = 1:num_mostrar
    % Destaca a primeira linha como a vencedora
    if i == 1
        marcador = '->';
    else
        marcador = '  ';
    end
    
    fprintf('%s %2d  |  %2d  |  %2d  |      %2d     |    %5.2f %%\n', ...
        marcador, ...
        modelos_otimizados(i, 1), modelos_otimizados(i, 2), ...
        modelos_otimizados(i, 3), modelos_otimizados(i, 5), ...
        modelos_otimizados(i, 4));
end
fprintf('=======================================================\n');

% Extração dos parâmetros vencedores
melhor_na = modelos_otimizados(1, 1);
melhor_nb = modelos_otimizados(1, 2);
melhor_nk = modelos_otimizados(1, 3);

fprintf('\n>>> RECOMENDAÇÃO FINAL PARA OS SCRIPTS <<<\n');
fprintf('na = %d; nb = %d; nk = %d;\n', melhor_na, melhor_nb, melhor_nk);