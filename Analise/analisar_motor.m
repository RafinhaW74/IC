% =========================================================================
% SCRIPT: DETECÇÃO DE ANOMALIAS (SAUDÁVEL VS FALHA) - COM VETOR DE PARK
% =========================================================================
clear; clc;
% --- 1. CONFIGURAÇÕES ---
fs = 16000; 
ganho_tensao = 1 / 0.02454545;
ganho_corrente = 1 / 0.4888886;
pasta_assinaturas = 'C:\Users\rafin\Desktop\IC_Offline\Assinaturas\';

% --- 2. DEFINIR O MOTOR A SER TESTADO ---
% MOTORES COM FALHA DE 1 BARRA
% arquivo_teste = 'D:\Organizando dados\Motor Para Análise\BRB_011_003.mat';

% MOTORES SAUDÁVEIS SEM DEFASAGEM
% arquivo_teste = 'D:\Organizando dados\1 CV\Motores Saudáveis\Motores Saudáveis para Assinatura\STW_010_000.mat';

% --- 3. CARREGAR A ASSINATURA DO MOTOR SAUDÁVEL ---
caminho_saudavel = fullfile(pasta_assinaturas, 'Assinatura_Saudavel.mat');
if exist(caminho_saudavel, 'file')
    load(caminho_saudavel, 'na', 'nb', 'nk', 'num_fases', 'fases_ativas', 'mu_assinatura', 'sigma_assinatura');
    mu_saudavel = mu_assinatura;     
    sigma_saudavel = sigma_assinatura;
else
    error('Erro: Assinatura_Saudavel.mat não encontrada em %s. Gere-a primeiro!', pasta_assinaturas);
end

% --- 4. EXTRAÇÃO DA DINÂMICA DO MOTOR DE TESTE ---
dados = load(arquivo_teste); campos = fieldnames(dados); Data_mat = dados.(campos{1}); 

Y_raw = [Data_mat(:,2), Data_mat(:,3), Data_mat(:,4)] * ganho_corrente;
U_raw = [Data_mat(:,5), Data_mat(:,6), Data_mat(:,7)] * ganho_tensao;

U_filt = U_raw(:, fases_ativas);
Y_filt = Y_raw(:, fases_ativas);

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

% Redefine para 1 fase global analisada
num_fases = 1; 
% ----------------------------------

N_eq = length(Y_model) - max(na, nb+nk-1);
Y_vec = Y_model(max(na, nb+nk-1)+1:end, :);
Phi = zeros(N_eq, num_fases*(na+nb));

for i=1:na, Phi(:, num_fases*(i-1)+1 : num_fases*i) = -Y_model(max(na, nb+nk-1)+1-i : end-i, :); end
off = num_fases*na;
for i=1:nb, Phi(:, off+num_fases*(i-1)+1 : off+num_fases*i) = U_model(max(na, nb+nk-1)+1-nk-(i-1) : end-nk-(i-1), :); end

% Estimação do modelo para o motor de teste
theta_bruto = pinv(Phi) * Y_vec;
theta_medio_teste = theta_bruto(:)'; % Fica disponível na Workspace

% --- 5. CÁLCULO DO DESVIO (Z-SCORE) ---
% Proteção contra divisão por zero
sigma_seguro = max(sigma_saudavel, 1e-6); 

% Calcula o desvio para cada parâmetro individualmente
z_scores_individuais = abs(theta_medio_teste - mu_saudavel) ./ sigma_seguro;

% NOVAS MÉTRICAS DE SENSIBILIDADE ALTA
z_score_maximo = max(z_scores_individuais); % Pega o pior cenário
limiar_z = 2.8; % Limite estatístico
parametros_anormais = sum(z_scores_individuais > limiar_z); % Quantos parâmetros "gritaram"
total_parametros = length(z_scores_individuais);

% --- 6. DECISÃO FINAL INTELIGENTE ---
fprintf('\n================================================\n');
fprintf('          RESULTADO DO DIAGNÓSTICO              \n');
fprintf('================================================\n');

% Critério: Se pelo menos 2 parâmetros explodirem o limite, ou se 1 
% parâmetro for absurdamente fora da curva (Z > 4.0), é falha.
if parametros_anormais >= 2 || z_score_maximo > 4.0
    fprintf('STATUS: [ !! ] ANOMALIA DETECTADA (FALHA)\n');
    fprintf('A dinâmica do motor divergiu do comportamento saudável.\n');
else
    fprintf('STATUS: [ OK ] MOTOR SAUDÁVEL\n');
    fprintf('A dinâmica está dentro dos padrões nominais.\n');
end

fprintf('------------------------------------------------\n');
fprintf('Parâmetros Anormais: %d de %d\n', parametros_anormais, total_parametros);
fprintf('Pior desvio encontrado (Z-Score Max): %.2f\n', z_score_maximo);
fprintf('================================================\n');