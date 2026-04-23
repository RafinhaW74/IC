% =========================================================================
% SCRIPT: DETECÇÃO E ANÁLISE VISUAL (SAUDÁVEL VS FALHA)
% =========================================================================
clear; clc; close all;
% --- 1. CONFIGURAÇÕES ---
fs = 16000; 
ganho_tensao = 1 / 0.02454545;
ganho_corrente = 1 / 0.4888886;
pasta_assinaturas = 'C:\Users\rafin\OneDrive\Área de Trabalho\Assinaturas\';

% --- 2. DEFINIR O MOTOR A SER TESTADO ---
% MOTORES SAUDÁVEIS
% arquivo_teste = 'I:\LSI_v2\STW_010\STW_010_010.mat';

% MOTORES COM FALHA DE 1 BARRA
arquivo_teste = 'I:\LSI_v2\BRB_014\BRB_014_050.mat';

% --- 3. CARREGAR A ASSINATURA DO MOTOR SAUDÁVEL ---
caminho_saudavel = fullfile(pasta_assinaturas, 'Assinatura_Saudavel.mat');
if exist(caminho_saudavel, 'file')
    load(caminho_saudavel, 'na', 'nb', 'nk', 'num_fases', 'fases_ativas', 'mu_assinatura', 'sigma_assinatura');
    mu_saudavel = mu_assinatura;     
    sigma_saudavel = sigma_assinatura;
else
    error('Erro: Assinatura_Saudavel.mat não encontrada!');
end

% --- 4. EXTRAÇÃO DA DINÂMICA DO MOTOR DE TESTE ---
dados = load(arquivo_teste); campos = fieldnames(dados); Data_mat = dados.(campos{1}); 

Y_raw = [Data_mat(:,2), Data_mat(:,3), Data_mat(:,4)] * ganho_corrente;
U_raw = [Data_mat(:,5), Data_mat(:,6), Data_mat(:,7)] * ganho_tensao;
U_filt = U_raw(:, fases_ativas); Y_filt = Y_raw(:, fases_ativas);

% --- VETOR DE PARK ---
I_alpha = (2/3) * (Y_filt(:,1) - 0.5*Y_filt(:,2) - 0.5*Y_filt(:,3));
I_beta  = (2/3) * ((sqrt(3)/2)*Y_filt(:,2) - (sqrt(3)/2)*Y_filt(:,3));
U_alpha = (2/3) * (U_filt(:,1) - 0.5*U_filt(:,2) - 0.5*U_filt(:,3));
U_beta  = (2/3) * ((sqrt(3)/2)*U_filt(:,2) - (sqrt(3)/2)*U_filt(:,3));

Y_park = I_alpha.^2 + I_beta.^2;
U_park = U_alpha.^2 + U_beta.^2;
Y_model = Y_park - mean(Y_park);
U_model = U_park - mean(U_park);
num_fases = 1; 

N_eq = length(Y_model) - max(na, nb+nk-1);
Y_vec = Y_model(max(na, nb+nk-1)+1:end, :);
Phi = zeros(N_eq, num_fases*(na+nb));

for i=1:na, Phi(:, num_fases*(i-1)+1 : num_fases*i) = -Y_model(max(na, nb+nk-1)+1-i : end-i, :); end
off = num_fases*na;
for i=1:nb, Phi(:, off+num_fases*(i-1)+1 : off+num_fases*i) = U_model(max(na, nb+nk-1)+1-nk-(i-1) : end-nk-(i-1), :); end

theta_bruto = pinv(Phi) * Y_vec;
theta_medio_teste = theta_bruto(:)'; 

% --- 5. CÁLCULO DO DESVIO (Z-SCORE) ---
sigma_seguro = max(sigma_saudavel, 1e-6); 
z_scores_individuais = abs(theta_medio_teste - mu_saudavel) ./ sigma_seguro;

z_score_maximo = max(z_scores_individuais); 
limiar_z = 2.8; 
parametros_anormais = sum(z_scores_individuais > limiar_z); 
total_parametros = length(z_scores_individuais);

% --- 6. RESULTADO NO CONSOLE ---
fprintf('\n================================================\n');
if parametros_anormais >= 2 || z_score_maximo > 4.0
    fprintf('STATUS: [ !! ] ANOMALIA DETECTADA (FALHA)\n');
else
    fprintf('STATUS: [ OK ] MOTOR SAUDÁVEL\n');
end
fprintf('Parâmetros Anormais: %d de %d\n', parametros_anormais, total_parametros);
fprintf('Pior desvio encontrado (Z-Score Max): %.2f\n', z_score_maximo);
fprintf('================================================\n');

% --- 7. ANÁLISE VISUAL (GRÁFICOS) ---
figure('Name', 'Diagnóstico Visual do Motor', 'Color', 'w', 'Position', [100, 100, 800, 600]);
x_ax = 1:total_parametros;

% Subplot 1: Comparação Direta dos Coeficientes
subplot(2,1,1);
% Desenha a banda azul representando o comportamento saudável aceitável (Média +/- 3 Sigmas)
fill([x_ax, fliplr(x_ax)], [mu_saudavel + 3*sigma_seguro, fliplr(mu_saudavel - 3*sigma_seguro)], [0.85 0.9 1], 'EdgeColor', 'none', 'DisplayName', 'Banda Saudável (\pm 3\sigma)');
hold on;
plot(x_ax, mu_saudavel, 'b-o', 'LineWidth', 2, 'DisplayName', 'Média Saudável');
plot(x_ax, theta_medio_teste, 'r-*', 'LineWidth', 2, 'DisplayName', 'Motor em Teste');
title('Comparação Direta dos Parâmetros ARX');
ylabel('Valor do Coeficiente (\theta)');
grid on; legend('Location', 'best');

% Subplot 2: Gráfico de Barras dos Z-Scores
subplot(2,1,2);
b = bar(x_ax, z_scores_individuais, 'FaceColor', [0.3 0.3 0.3]);
hold on;
% Pinta de vermelho as barras que ultrapassaram o limite
for i = 1:total_parametros
    if z_scores_individuais(i) > limiar_z
        b.FaceColor = 'flat';
        b.CData(i,:) = [0.85 0.32 0.09]; % Laranja/Vermelho
    end
end
yline(limiar_z, 'r--', 'LineWidth', 2, 'Label', 'Limiar de Alerta');
title('Nível de Anomalia por Parâmetro (Z-Score)');
xlabel('Índice do Parâmetro'); ylabel('Desvios (\sigma)');
grid on;