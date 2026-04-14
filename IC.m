% =========================================================================
% SCRIPT DE IDENTIFICAÇÃO ARX (SEM SYSTEM IDENTIFICATION TOOLBOX)
% =========================================================================

arquivo = 'C:\node-red\dados3.csv'; 
dados = readmatrix(arquivo); 
tensao_adc = dados(:,1); 
corrente_adc = dados(:,2); 
Ts = 0.00025; 

% ---------- PARAMETROS ---------- 
ADCmax = 4095;
Vref_corrente = 5.0;
Vref_tensao = 3.3; 
offset_corrente = 2600; 
offset_tensao = 2000; 
 
% ---------- CONVERSAO PARA VOLTS DO ADC ---------- 
Vc_adc = corrente_adc * Vref_corrente / ADCmax; 
Vt_adc = tensao_adc * Vref_tensao / ADCmax; 
Vc_offset = offset_corrente * Vref_corrente / ADCmax; 
Vt_offset = offset_tensao * Vref_tensao / ADCmax; 
 
% ---------- REMOVER OFFSET ---------- 
Vc = Vc_adc - Vc_offset;
Vt = Vt_adc - Vt_offset; 

% Opcional, mas recomendado: Remover média exata (detrend manual)
Vc = Vc - mean(Vc);
Vt = Vt - mean(Vt);

amostras = 1:length(Vc); 
tempo = linspace(0, amostras(end)*Ts, amostras(end))'; % Garantir vetor coluna
 
% ---------- GANHO DO DIVISOR DE TENSAO ---------- 
ganho_divisor = 380; 
tensao_convertida = Vt * ganho_divisor; 
corrente_convertida = Vc; 
  
% ---------- PLOT DA AQUISIÇÃO (Figura 1) ---------- 
f1 = figure; 
set(f1, 'Units', 'centimeters');
pos = get(f1, 'Position');
pos(4) = 6; % altura 6 cm
set(f1, 'Position', pos);

subplot(1,2,1) 
plot(tempo, corrente_convertida, 'k') 
title('(a)') 
xlabel('Tempo [s]') 
ylabel('Corrente [A]') 
ylim([-2 2])
grid on 
  
subplot(1,2,2) 
plot(tempo, tensao_convertida, 'k') 
title('(b)') 
xlabel('Tempo [s]') 
ylabel('Tensão [V]') 
ylim([-200 200])
grid on 

% =========================================================================
% NOVO BLOCO: ESTIMAÇÃO ARX [8 1 1] MANUAL VETORIZADA (SEM TOOLBOX)
% =========================================================================

% Definindo a estrutura
na = 8; 
nb = 1; 
nk = 1;

N = length(corrente_convertida);
max_atraso = max(na, nb + nk - 1);

% Pré-alocando o vetor de Saídas (Y) e a Matriz de Regressores (Phi)
N_equacoes = N - max_atraso;
Y   = corrente_convertida(max_atraso + 1 : end);
Phi = zeros(N_equacoes, na + nb);

% Preenchendo a matriz Phi vetorizada (MUITO mais rápido que usar FOR linha a linha)
for i = 1:na
    % Regressores autoregressivos: -y(t-1) a -y(t-na)
    Phi(:, i) = -corrente_convertida(max_atraso + 1 - i : end - i);
end
for i = 1:nb
    % Regressores da entrada: u(t-nk) a u(t-nk-nb+1)
    Phi(:, na + i) = tensao_convertida(max_atraso + 1 - nk - (i-1) : end - nk - (i-1));
end

% Resolução via Mínimos Quadrados com Pseudoinversa (SVD embutido)
theta = pinv(Phi) * Y;

% Extraindo os parâmetros
a_estimados = theta(1:na);
b_estimados = theta(na+1 : end);

disp('Parâmetros Estimação Manual:');
disp(['a1...a8: ', num2str(a_estimados')]);
disp(['b1:      ', num2str(b_estimados')]);

% Simulação One-Step Ahead (Equivalente ao comando "compare")
y_estimado = zeros(N, 1);
y_estimado(1:max_atraso) = corrente_convertida(1:max_atraso); % Transiente inicial
y_estimado(max_atraso + 1 : end) = Phi * theta;

% Calculando o Fit (%) manualmente
erro = Y - y_estimado(max_atraso + 1 : end);
fit_percent = 100 * (1 - norm(erro) / norm(Y - mean(Y)));
disp(['Fit do Modelo: ', num2str(fit_percent), '%']);

% =========================================================================
% COMPARAÇÃO MODELO VS DADOS (Figura 2 - Substituindo o compare)
% =========================================================================

fig = figure; 
set(fig, 'Units', 'centimeters');
pos = get(fig, 'Position');
pos(4) = 4; % altura 4 cm
set(fig, 'Position', pos);

% Plot manual das duas curvas
plot(tempo, corrente_convertida, 'k', 'LineWidth', 1);
hold on;
plot(tempo, y_estimado, 'r', 'LineWidth', 1);

set(gca,'FontSize',8)
title('(c)')
xlabel('Tempo [s]');
ylabel('Corrente [A]');

ylim([-1 1]);
xlim([30 30.1]); % Mantenha o zoom que você configurou originalmente
legend('Sinal Experimental', 'Sinal estimado', 'Location', 'northeastoutside')
grid on;