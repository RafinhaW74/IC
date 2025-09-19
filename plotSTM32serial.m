%==========================================================================
% SCRIPT PARA PLOTAR DADOS DE UM STM32 EM TEMPO REAL
%==========================================================================
clear; clc; close all;

% --- 1. CONFIGURAÇÃO DA PORTA SERIAL ---
% Altere 'COM4' para a porta COM correta do seu STM32
com_port = "COM9"; 
baud_rate = 9600; % Para USB VCP, o baud rate é virtual, mas precisa ser definido

% Tenta fechar uma porta serial antiga, se existir
if ~isempty(serialportfind)
     fclose(serialportfind);
     delete(serialportfind);
end

% Cria o objeto da porta serial
try
    device = serialport(com_port, baud_rate);
    disp("Conectado ao STM32 na porta " + com_port);
catch e
    disp("Erro ao conectar. Verifique a porta COM e se não está em uso.");
    disp(e.message);
    return; % Para o script se não conseguir conectar
end

% Configura o terminador de linha para "Line Feed" (\n), que é o que o STM32 envia
configureTerminator(device, "LF");

% --- 2. CONFIGURAÇÃO DO GRÁFICO ---
num_samples = 1024; % Número de pontos que o STM32 envia por bloco

figure('Name', 'Leitura do ADC em Tempo Real', 'NumberTitle', 'off');
h_plot = animatedline('Color', 'b', 'LineWidth', 2);

title('Forma de Onda do Sensor ZMPT101B');
xlabel('Amostra');
ylabel('Valor Bruto do ADC (0-4095)');
grid on;
axis([1, num_samples, 0, 4095]); % Define os limites dos eixos [xmin, xmax, ymin, ymax]

disp("Iniciando a plotagem. Feche a janela do gráfico para parar.");

% --- 3. LOOP DE LEITURA E PLOTAGEM ---
sample_count = 1;

% O loop continua enquanto a janela do gráfico estiver aberta
while ishandle(h_plot)
    try
        % Lê uma linha da porta serial (até o terminador '\n')
        data_str = readline(device);
        
        % Converte a string lida para um número
        adc_value = str2double(data_str);
        
        % Adiciona o ponto ao gráfico animado
        addpoints(h_plot, sample_count, adc_value);
        
        % Força o MATLAB a atualizar o gráfico na tela
        drawnow; 
        
        % Incrementa o contador de amostras
        sample_count = sample_count + 1;
        
        % Se completou um ciclo de 256 amostras, limpa o gráfico e começa de novo
        if sample_count > num_samples
            sample_count = 1;
            clearpoints(h_plot); % Limpa os pontos para a próxima onda
        end
        
    catch e
        disp("Ocorreu um erro durante a leitura ou plotagem.");
        disp(e.message);
        break; % Sai do loop em caso de erro
    end
end

% --- 4. LIMPEZA ---
clear device;
disp("Plotagem parada. Porta serial fechada.");
