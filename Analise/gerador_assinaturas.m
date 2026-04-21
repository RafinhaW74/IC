% =========================================================================
% SCRIPT 1: GERADOR UNIVERSAL DE ASSINATURAS (SAUDÁVEL OU FALHA) - COM PARK
% =========================================================================
clear; clc;
fs = 16000; 
ganho_tensao = 1 / 0.02454545;
ganho_corrente = 1 / 0.4888886;
na = 4; nb = 4; nk = 1; 

% --- 1. CONFIGURAÇÕES DA CLASSE ATUAL ---
 % ALTERAR PARA PASTA DE ONDE ESTÁ EXTRAINDO OS DADOS PARA ASSINATURA
pasta_dados = 'D:\Organizando dados\1 CV\Motores Saudáveis\Motores Saudáveis para Assinatura\';
nome_classe = 'Saudavel'; % Nome da assinatura

% Pasta destino para assinaturas
pasta_destino = 'C:\Users\rafin\Desktop\IC_Offline\Assinaturas\';
if ~exist(pasta_destino, 'dir')
    mkdir(pasta_destino);
end

arquivos = dir(fullfile(pasta_dados, '*.mat'));
historico_Theta = [];

for arq = 1:length(arquivos)
    dados = load(fullfile(pasta_dados, arquivos(arq).name));
    campos = fieldnames(dados); Data_mat = dados.(campos{1}); 
    
    Y_raw = [Data_mat(:,2), Data_mat(:,3), Data_mat(:,4)] * ganho_corrente;
    U_raw = [Data_mat(:,5), Data_mat(:,6), Data_mat(:,7)] * ganho_tensao;
    
    fases_ativas = var(Y_raw) > 1e-4; % Salvo apenas para metadados
    U_filt = U_raw(:, fases_ativas); Y_filt = Y_raw(:, fases_ativas);
    
    % --- APLICAÇÃO DO VETOR DE PARK ---
    % Transformada de Clarke para a Corrente
    I_alpha = (2/3) * (Y_filt(:,1) - 0.5*Y_filt(:,2) - 0.5*Y_filt(:,3));
    I_beta  = (2/3) * ((sqrt(3)/2)*Y_filt(:,2) - (sqrt(3)/2)*Y_filt(:,3));

    % Transformada de Clarke para a Tensão
    U_alpha = (2/3) * (U_filt(:,1) - 0.5*U_filt(:,2) - 0.5*U_filt(:,3));
    U_beta  = (2/3) * ((sqrt(3)/2)*U_filt(:,2) - (sqrt(3)/2)*U_filt(:,3));

    % Calcula o Módulo (Vetor de Park) e remove o nível DC
    Y_park = I_alpha.^2 + I_beta.^2;
    U_park = U_alpha.^2 + U_beta.^2;

    Y_model = Y_park - mean(Y_park);
    U_model = U_park - mean(U_park);

    % Redefine num_fases para a estimação ARX
    num_fases = 1; 
    % ----------------------------------
    
    N_linhas = length(Y_model);
    N_eq = N_linhas - max(na, nb+nk-1);
    Y_vec = Y_model(max(na, nb+nk-1)+1:end, :);
    Phi = zeros(N_eq, num_fases*(na+nb));
    
    for i=1:na, Phi(:, num_fases*(i-1)+1 : num_fases*i) = -Y_model(max(na, nb+nk-1)+1-i : end-i, :); end
    off = num_fases*na;
    for i=1:nb, Phi(:, off+num_fases*(i-1)+1 : off+num_fases*i) = U_model(max(na, nb+nk-1)+1-nk-(i-1) : end-nk-(i-1), :); end
    
    Theta_arquivo = pinv(Phi) * Y_vec;
    historico_Theta = [historico_Theta; Theta_arquivo(:)']; 
end

% Cálculos estatísticos
mu_assinatura = mean(historico_Theta);
sigma_assinatura = std(historico_Theta);

% Salva o arquivo na pasta destino oficial (Note que num_fases aqui já será 1)
caminho_salvar = fullfile(pasta_destino, ['Assinatura_', nome_classe, '.mat']);
save(caminho_salvar, 'mu_assinatura', 'sigma_assinatura', 'nome_classe', 'num_fases', 'na', 'nb', 'nk', 'fases_ativas');

fprintf('Sucesso! Arquivo salvo em: %s\n\n', caminho_salvar);