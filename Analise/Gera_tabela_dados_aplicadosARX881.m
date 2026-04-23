% =========================================================================
% SCRIPT: EXTRATOR DE FEATURES ARX E GERADOR DE DATASET CSV PARA ML
% =========================================================================
clear; clc; close all;

% --- 1. CONFIGURAÇÕES DO MODELO ARX ---
na = 8; 
nb = 8; 
nk = 1;
fs = 16000; 
ganho_tensao = 1 / 0.02454545;
ganho_corrente = 1 / 0.4888886;

% --- 2. CONFIGURAÇÕES DAS PASTAS DE DADOS ---
pastas_classes = {
    'Saudavel',   'I:\LSI_v2\STW_010\';
    '1_Barra',    'I:\LSI_v2\BRB_011\';
    '2_Barras',   'I:\LSI_v2\BRB_012\';
    '2_2_Barras', 'I:\LSI_v2\BRB_013\';
    '4_Barras',   'I:\LSI_v2\BRB_014\'
};

% Onde o CSV final será salvo
arquivo_csv = 'C:\Users\rafin\OneDrive\Área de Trabalho\IC_offline\Dataset_Motores_ARX.csv';

% Inicializa variáveis para armazenar os dados consolidados
todos_arquivos = {};
todos_thetas = [];
todas_classes = {};

fprintf('Iniciando extração de parâmetros ARX (%d, %d, %d)...\n', na, nb, nk);

% --- 3. LOOP DE EXTRAÇÃO POR CLASSE ---
for c = 1:size(pastas_classes, 1)
    nome_classe = pastas_classes{c, 1};
    caminho_pasta = pastas_classes{c, 2};
    
    % Pula a classe se o caminho não foi definido ou não existe
    if isempty(caminho_pasta) || ~exist(caminho_pasta, 'dir')
        fprintf('Pulando classe "%s" (Pasta não encontrada ou vazia).\n', nome_classe);
        continue;
    end
    
    arquivos_mat = dir(fullfile(caminho_pasta, '*.mat'));
    fprintf('Processando %d arquivos da classe: %s...\n', length(arquivos_mat), nome_classe);
    
    for arq = 1:length(arquivos_mat)
        nome_arquivo = arquivos_mat(arq).name;
        dados = load(fullfile(caminho_pasta, nome_arquivo));
        campos = fieldnames(dados); 
        Data_mat = dados.(campos{1}); 
        
        % Preparação dos Sinais
        Y_raw = [Data_mat(:,2), Data_mat(:,3), Data_mat(:,4)] * ganho_corrente;
        U_raw = [Data_mat(:,5), Data_mat(:,6), Data_mat(:,7)] * ganho_tensao;
        
        fases_ativas = var(Y_raw) > 1e-4; 
        U_filt = U_raw(:, fases_ativas); 
        Y_filt = Y_raw(:, fases_ativas);
        
        % Vetor de Park
        I_alpha = (2/3) * (Y_filt(:,1) - 0.5*Y_filt(:,2) - 0.5*Y_filt(:,3));
        I_beta  = (2/3) * ((sqrt(3)/2)*Y_filt(:,2) - (sqrt(3)/2)*Y_filt(:,3));
        U_alpha = (2/3) * (U_filt(:,1) - 0.5*U_filt(:,2) - 0.5*U_filt(:,3));
        U_beta  = (2/3) * ((sqrt(3)/2)*U_filt(:,2) - (sqrt(3)/2)*U_filt(:,3));
        
        Y_park = I_alpha.^2 + I_beta.^2;
        U_park = U_alpha.^2 + U_beta.^2;
        
        Y_model = Y_park - mean(Y_park);
        U_model = U_park - mean(U_park);
        num_fases = 1; 
        
        % Montagem das matrizes ARX
        N_linhas = length(Y_model);
        N_eq = N_linhas - max(na, nb+nk-1);
        Y_vec = Y_model(max(na, nb+nk-1)+1:end, :);
        Phi = zeros(N_eq, num_fases*(na+nb));
        
        for i=1:na
            Phi(:, num_fases*(i-1)+1 : num_fases*i) = -Y_model(max(na, nb+nk-1)+1-i : end-i, :); 
        end
        off = num_fases*na;
        for i=1:nb
            Phi(:, off+num_fases*(i-1)+1 : off+num_fases*i) = U_model(max(na, nb+nk-1)+1-nk-(i-1) : end-nk-(i-1), :); 
        end
        
        % Estimação dos parâmetros
        Theta_arquivo = pinv(Phi) * Y_vec;
        
        % Armazena no banco de dados geral
        todos_arquivos{end+1, 1} = nome_arquivo;
        todos_thetas(end+1, :) = Theta_arquivo(:)';
        todas_classes{end+1, 1} = nome_classe;
    end
end

% --- 4. CRIAÇÃO E EXPORTAÇÃO DA TABELA (DATASET) ---
fprintf('\nConsolidando os dados em uma tabela...\n');

% Cria os nomes das colunas para os parâmetros Theta (Theta_1, Theta_2, ..., Theta_16)
nomes_thetas = cell(1, na+nb);
for i = 1:(na+nb)
    nomes_thetas{i} = sprintf('Theta_%d', i);
end

% Converte a matriz numérica em tabela
T_thetas = array2table(todos_thetas, 'VariableNames', nomes_thetas);

% Cria tabelas para as strings (Arquivo e Classe)
T_arq = cell2table(todos_arquivos, 'VariableNames', {'Arquivo'});
T_classe = cell2table(todas_classes, 'VariableNames', {'Classe'});

% Une tudo em um único Dataset
Dataset_Completo = [T_arq, T_thetas, T_classe];

% Salva em CSV
writetable(Dataset_Completo, arquivo_csv);

fprintf('Sucesso! Dataset CSV gerado com %d linhas e %d colunas.\n', size(Dataset_Completo, 1), size(Dataset_Completo, 2));
fprintf('Arquivo salvo em: %s\n', arquivo_csv);